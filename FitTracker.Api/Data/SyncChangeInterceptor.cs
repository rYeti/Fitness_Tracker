using FitTracker.Api.Models;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Diagnostics;

namespace FitTracker.Api.Data;

/// <summary>
/// Keeps the two facts the changes feed reads true on every save: when each aggregate last
/// changed, and which synced rows were deleted. See docs/sync-architecture.md, part three.
/// </summary>
/// <remarks>
/// Before each save it reads the change tracker and:
///
/// 1. stamps <see cref="ISyncRoot.UpdatedAt"/> on every root the save adds or changes;
/// 2. stamps the root of every child the save adds, changes or removes — both roots, when
///    a change moves a child from one to another:
///
///    | Child                          | Root                                   |
///    |--------------------------------|----------------------------------------|
///    | <see cref="WorkoutExercise"/>, <see cref="WorkoutSetTemplate"/> | its <see cref="Workout"/> |
///    | <see cref="ScheduledWorkoutExercise"/>, <see cref="WorkoutSet"/> | its <see cref="ScheduledWorkout"/> |
///    | <see cref="MealFoodEntry"/>    | its <see cref="Meal"/>                 |
///    | <see cref="WorkoutPlanWorkout"/> | its <see cref="WorkoutPlan"/>        |
///    | <see cref="MealTemplateItem"/> | its <see cref="MealTemplate"/>         |
///
///    A new child table under a synced root goes in <see cref="CollectRoots"/>. Leaving it
///    out compiles, saves, and never sends the change to anyone. A root the save isn't
///    holding is stamped with one <c>UPDATE</c> of its <c>UpdatedAt</c>, not loaded, and a
///    root is stamped at most once per transaction (<see cref="SyncChanges.StampAsync{TRoot}"/>).
/// 3. writes a <see cref="SyncTombstone"/> for every root the save deletes, and for every
///    meal food entry it deletes. A deleted meal's foods are loaded and deleted by the save
///    itself, rather than left to the database's cascade, so the tombstones are for exactly
///    the rows the save removes.
///
/// Tombstones are added to the same save, so they commit or fail with the change they
/// describe. What the change tracker never sees — <c>ExecuteDelete</c>,
/// <c>ExecuteUpdate</c>, and the database's own cascades — is handled at those call sites
/// (<see cref="SyncChanges"/>).
///
/// The owner of a row is its owner, not whoever saved: a trainer editing a client's workout
/// stamps the client's workout, and deleting it writes the client's tombstone.
/// </remarks>
public sealed class SyncChangeInterceptor : SaveChangesInterceptor
{
    /// <summary>The one instance every context registers (see <c>AppDbContext.OnConfiguring</c>).
    /// It holds no state.</summary>
    public static readonly SyncChangeInterceptor Instance = new();

    private SyncChangeInterceptor() { }

    /// <inheritdoc/>
    public override InterceptionResult<int> SavingChanges(DbContextEventData eventData, InterceptionResult<int> result)
    {
        // With async: false every query below runs synchronously, so this task has already
        // completed when it is returned; nothing is blocked on.
        if (eventData.Context is AppDbContext db) RecordAsync(db, async: false, default).GetAwaiter().GetResult();
        return result;
    }

    /// <inheritdoc/>
    public override async ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        if (eventData.Context is AppDbContext db) await RecordAsync(db, async: true, cancellationToken);
        return result;
    }

    private static async Task RecordAsync(AppDbContext db, bool async, CancellationToken ct)
    {
        // One snapshot of the tracker for the whole save. Entries() runs DetectChanges, so
        // edits made to tracked entities without telling the context are seen here too —
        // and it scans everything tracked, so it runs once, not once per type asked about.
        var tracked = db.ChangeTracker.Entries().ToList();
        var changed = tracked
            .Where(e => e.State is EntityState.Added or EntityState.Modified or EntityState.Deleted)
            .ToList();
        if (changed.Count == 0) return;

        var now = DateTime.UtcNow;
        var roots = CollectRoots(changed);

        roots.Workouts.UnionWith(await ParentsAsync(tracked, roots.WorkoutExercises,
            (WorkoutExercise e) => e.WorkoutId, ids => db.WorkoutExercises.Where(e => ids.Contains(e.Id)).Select(e => e.WorkoutId), async, ct));
        roots.Sessions.UnionWith(await ParentsAsync(tracked, roots.SessionExercises,
            (ScheduledWorkoutExercise e) => e.ScheduledWorkoutId, ids => db.ScheduledWorkoutExercises.Where(e => ids.Contains(e.Id)).Select(e => e.ScheduledWorkoutId), async, ct));

        foreach (var entry in changed)
        {
            if (entry.Entity is ISyncRoot && entry.State is EntityState.Added or EntityState.Modified)
            {
                entry.Property(nameof(ISyncRoot.UpdatedAt)).CurrentValue = now;
            }
        }

        await SyncChanges.StampAsync<Workout>(db, roots.Workouts, now, async, ct, OfType<Workout>(tracked));
        await SyncChanges.StampAsync<ScheduledWorkout>(db, roots.Sessions, now, async, ct, OfType<ScheduledWorkout>(tracked));
        await SyncChanges.StampAsync<Meal>(db, roots.Meals, now, async, ct, OfType<Meal>(tracked));
        await SyncChanges.StampAsync<WorkoutPlan>(db, roots.Plans, now, async, ct, OfType<WorkoutPlan>(tracked));
        await SyncChanges.StampAsync<MealTemplate>(db, roots.Templates, now, async, ct, OfType<MealTemplate>(tracked));

        await BuryAsync(db, tracked, changed, now, async, ct);
    }

    private static IEnumerable<EntityEntry> OfType<T>(List<EntityEntry> tracked) =>
        tracked.Where(e => e.Entity is T);

    /// <summary>The ids of the roots — or of the children one level down that lead to
    /// them — whose children this save touches.</summary>
    private static TouchedRoots CollectRoots(List<EntityEntry> changed)
    {
        var roots = new TouchedRoots();
        foreach (var entry in changed)
        {
            var (ids, parentKey) = entry.Entity switch
            {
                WorkoutExercise => (roots.Workouts, nameof(WorkoutExercise.WorkoutId)),
                WorkoutSetTemplate => (roots.WorkoutExercises, nameof(WorkoutSetTemplate.WorkoutExerciseId)),
                ScheduledWorkoutExercise => (roots.Sessions, nameof(ScheduledWorkoutExercise.ScheduledWorkoutId)),
                WorkoutSet => (roots.SessionExercises, nameof(WorkoutSet.ScheduledWorkoutExerciseId)),
                MealFoodEntry => (roots.Meals, nameof(MealFoodEntry.MealId)),
                WorkoutPlanWorkout => (roots.Plans, nameof(WorkoutPlanWorkout.PlanId)),
                MealTemplateItem => (roots.Templates, nameof(MealTemplateItem.TemplateId)),
                _ => (null, ""),
            };
            if (ids == null) continue;

            // Both ends of a move: the parent it left changed as much as the one it joined.
            var key = entry.Property(parentKey);
            if (key.CurrentValue is Guid current) ids.Add(current);
            if (entry.State != EntityState.Added && key.OriginalValue is Guid original) ids.Add(original);
        }
        return roots;
    }

    /// <summary>The parents of <paramref name="childIds"/>, from the tracker snapshot where
    /// it holds them and from the database otherwise.</summary>
    private static async Task<IEnumerable<Guid>> ParentsAsync<TChild>(
        List<EntityEntry> tracked,
        HashSet<Guid> childIds,
        Func<TChild, Guid> parentOf,
        Func<List<Guid>, IQueryable<Guid>> storedParents,
        bool async,
        CancellationToken ct)
        where TChild : class
    {
        if (childIds.Count == 0) return [];

        var parents = new HashSet<Guid>();
        var unresolved = new HashSet<Guid>(childIds);
        foreach (var entry in tracked)
        {
            if (entry.Entity is not TChild child) continue;
            var id = (Guid)entry.Property("Id").CurrentValue!;
            if (unresolved.Remove(id)) parents.Add(parentOf(child));
        }
        if (unresolved.Count == 0) return parents;

        var query = storedParents([.. unresolved]).Distinct();
        parents.UnionWith(async ? await query.ToListAsync(ct) : query.ToList());
        return parents;
    }

    /// <summary>Adds a tombstone for every root and meal food entry this save deletes.</summary>
    private static async Task BuryAsync(
        AppDbContext db, List<EntityEntry> tracked, List<EntityEntry> changed, DateTime now, bool async, CancellationToken ct)
    {
        var deleted = changed.Where(e => e.State == EntityState.Deleted).ToList();
        if (deleted.Count == 0) return;

        // An account being deleted takes its tombstones with it; there is nobody to tell.
        var leaving = deleted.Where(e => e.Entity is User).Select(e => ((User)e.Entity).Id).ToHashSet();

        var buried = new List<(Guid? Owner, string Type, Guid Id)>();
        var sessionsByWorkout = new List<(Guid WorkoutId, Guid Id)>();
        var foodsByMeal = new List<(Guid MealId, Guid Id)>();
        var mealOwners = new Dictionary<Guid, Guid>();

        foreach (var entry in deleted)
        {
            switch (entry.Entity)
            {
                case Exercise e: buried.Add((Original<Guid?>(entry, nameof(e.UserId)), SyncEntityTypes.Exercise, e.Id)); break;
                case Workout w: buried.Add((Original<Guid>(entry, nameof(w.UserId)), SyncEntityTypes.Workout, w.Id)); break;
                case WorkoutPlan p: buried.Add((Original<Guid>(entry, nameof(p.UserId)), SyncEntityTypes.WorkoutPlan, p.Id)); break;
                case FoodItem f: buried.Add((Original<Guid>(entry, nameof(f.UserId)), SyncEntityTypes.FoodItem, f.Id)); break;
                case MealTemplate t: buried.Add((Original<Guid>(entry, nameof(t.UserId)), SyncEntityTypes.MealTemplate, t.Id)); break;
                case WeightTracking w: buried.Add((Original<Guid>(entry, nameof(w.UserId)), SyncEntityTypes.Weight, w.Id)); break;
                case Meal m:
                    var owner = Original<Guid>(entry, nameof(m.UserId));
                    buried.Add((owner, SyncEntityTypes.Meal, m.Id));
                    mealOwners[m.Id] = owner;
                    break;
                // A session's owner is its workout's.
                case ScheduledWorkout s: sessionsByWorkout.Add((Original<Guid>(entry, nameof(s.WorkoutId)), s.Id)); break;
                // An entry's owner is its meal's.
                case MealFoodEntry f: foodsByMeal.Add((Original<Guid>(entry, nameof(f.MealId)), f.Id)); break;
            }
        }

        if (mealOwners.Count > 0) foodsByMeal.AddRange(await DeleteFoodsOfAsync(db, tracked, mealOwners.Keys.ToList(), async, ct));

        var workoutOwners = await OwnersAsync<Workout>(db, tracked, sessionsByWorkout.Select(s => s.WorkoutId), async, ct);
        buried.AddRange(sessionsByWorkout.Select(s =>
            (workoutOwners.TryGetValue(s.WorkoutId, out var o) ? o : (Guid?)null, SyncEntityTypes.ScheduledWorkout, s.Id)));

        var foodMealOwners = await OwnersAsync<Meal>(db, tracked, foodsByMeal.Select(f => f.MealId).Where(id => !mealOwners.ContainsKey(id)), async, ct);
        foreach (var (id, owner) in mealOwners) foodMealOwners[id] = owner;
        buried.AddRange(foodsByMeal.Select(f =>
            (foodMealOwners.TryGetValue(f.MealId, out var o) ? o : (Guid?)null, SyncEntityTypes.MealFood, f.Id)));

        foreach (var (owner, type, id) in buried.DistinctBy(b => b.Id))
        {
            // A built-in exercise has no owner, and no device holds it as its own.
            if (owner is not { } userId || userId == Guid.Empty || leaving.Contains(userId)) continue;
            db.SyncTombstones.Add(new SyncTombstone
            {
                Id = Guid.NewGuid(),
                UserId = userId,
                EntityType = type,
                EntityId = id,
                DeletedAt = now,
            });
        }
    }

    /// <summary>Makes the save delete the foods of the meals <paramref name="mealIds"/> by
    /// itself, and returns the ones it will delete.</summary>
    /// <remarks>
    /// The database would cascade them, out of the change tracker's sight, and a list of
    /// their ids read here to tombstone them would be a guess at what that cascade removes.
    /// Deleted by the save, the tombstones are for exactly the rows it deletes. A food this
    /// save moves *out* of the meal (tracked, its current <c>MealId</c> another meal's) is
    /// not deleted and gets no tombstone: the feed must never tell a device to delete a
    /// live row. A food moved *in* by another request after this read would still go to
    /// the cascade untombstoned; <c>MealRepository.DeleteMealAsync</c> stamps the meal
    /// first, in its transaction, which is the row every such move stamps too, so a move
    /// either commits before that stamp (and is read here) or waits for the delete to
    /// commit (and fails on the missing meal).
    /// </remarks>
    private static async Task<List<(Guid MealId, Guid Id)>> DeleteFoodsOfAsync(
        AppDbContext db, List<EntityEntry> tracked, List<Guid> mealIds, bool async, CancellationToken ct)
    {
        var query = db.MealFoodEntries.Where(e => mealIds.Contains(e.MealId));
        var foods = async ? await query.ToListAsync(ct) : query.ToList();
        // And any this save moves *into* one of the meals, which the query reads under
        // the meal they're stored in.
        foods.AddRange(tracked.Select(e => e.Entity).OfType<MealFoodEntry>());

        var removed = new List<(Guid MealId, Guid Id)>();
        foreach (var food in foods.Distinct())
        {
            var entry = db.Entry(food);
            // A tracked entry answers the query with its current values, so a food already
            // moved to another meal by this save is recognised here as not being in this one.
            if (!mealIds.Contains(food.MealId)) continue;
            if (entry.State is EntityState.Unchanged or EntityState.Modified) entry.State = EntityState.Deleted;
            if (entry.State == EntityState.Deleted) removed.Add((food.MealId, food.Id));
        }
        return removed;
    }

    /// <summary>The owner of each of the given rows, from the tracker snapshot where it
    /// holds them and from the database otherwise.</summary>
    private static async Task<Dictionary<Guid, Guid>> OwnersAsync<TRoot>(
        AppDbContext db, List<EntityEntry> tracked, IEnumerable<Guid> ids, bool async, CancellationToken ct)
        where TRoot : class, ISyncRoot
    {
        var owners = new Dictionary<Guid, Guid>();
        var unresolved = ids.ToHashSet();
        if (unresolved.Count == 0) return owners;

        foreach (var entry in tracked)
        {
            if (entry.Entity is TRoot root && unresolved.Remove(root.Id)) owners[root.Id] = Original<Guid>(entry, "UserId");
        }
        if (unresolved.Count == 0) return owners;

        var wanted = unresolved.ToList();
        var query = db.Set<TRoot>().AsNoTracking()
            .Where(r => wanted.Contains(EF.Property<Guid>(r, nameof(ISyncRoot.Id))))
            .Select(r => new { Id = EF.Property<Guid>(r, nameof(ISyncRoot.Id)), UserId = EF.Property<Guid>(r, "UserId") });
        foreach (var row in async ? await query.ToListAsync(ct) : query.ToList())
        {
            owners[row.Id] = row.UserId;
        }
        return owners;
    }

    /// <summary>A property's value as it was loaded — what a delete removes, whatever the
    /// entity was changed to before it.</summary>
    private static T Original<T>(EntityEntry entry, string property) => (T)entry.Property(property).OriginalValue!;

    /// <summary>What a save's children point at, one set per root type (and one per middle
    /// level, resolved to its root before anything is stamped).</summary>
    private sealed class TouchedRoots
    {
        public HashSet<Guid> Workouts { get; } = [];
        public HashSet<Guid> WorkoutExercises { get; } = [];
        public HashSet<Guid> Sessions { get; } = [];
        public HashSet<Guid> SessionExercises { get; } = [];
        public HashSet<Guid> Meals { get; } = [];
        public HashSet<Guid> Plans { get; } = [];
        public HashSet<Guid> Templates { get; } = [];
    }
}
