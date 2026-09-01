using System.ComponentModel.DataAnnotations;

namespace FitTracker.Api.DTOs;

/// <summary>One of a client's workouts as the Trainer Console's Workout Builder edits it:
/// the day itself, its exercises in order, and the sets prescribed for each.</summary>
/// <remarks>
/// Deliberately not <see cref="WorkoutResponseDto"/>. That one is the client's own view of
/// their workouts — it carries every exercise entry the row still holds, retired ones
/// included, because the trainee's sync needs them to resolve logged history against. A
/// trainer building a plan is being shown what the workout <em>is</em>, so retired entries
/// are filtered out here (see <see cref="WorkoutExerciseResponseDto.RemovedAt"/>), and the
/// exercise's name is resolved server-side because the console holds no exercise catalogue
/// of its own.
/// </remarks>
public class ClientWorkoutDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = "";

    public string? Description { get; set; }

    /// <summary>0 = beginner, 1 = intermediate, 2 = advanced.</summary>
    public int Difficulty { get; set; }

    public int EstimatedDurationMinutes { get; set; }

    /// <summary>Ids of the client's plans this workout is a day of. Usually one; a workout
    /// reused across plans belongs to several.</summary>
    public List<Guid> PlanIds { get; set; } = [];

    public List<ClientWorkoutExerciseDto> Exercises { get; set; } = [];
}

/// <summary>One exercise within a client's workout, with the sets prescribed for it.</summary>
public class ClientWorkoutExerciseDto
{
    /// <summary>The id of the <c>WorkoutExercise</c> entry — the thing sessions log against.
    /// Send it back on update to keep the entry (and its logged history) rather than
    /// replacing it.</summary>
    public Guid Id { get; set; }

    /// <summary>The exercise definition being prescribed.</summary>
    public Guid ExerciseId { get; set; }

    /// <summary>Resolved server-side so the console doesn't have to hold the catalogue.</summary>
    public string ExerciseName { get; set; } = "";

    public int OrderPosition { get; set; }

    public string? Notes { get; set; }

    public int? SupersetGroupId { get; set; }

    public List<WorkoutSetTemplateResponseDto> Sets { get; set; } = [];
}

/// <summary>One entry in the Workout Builder's exercise picker: everything the client can
/// currently see (system exercises, the client's own) plus the trainer's own library.</summary>
/// <remarks>
/// <see cref="IsTrainerOwned"/> is what lets the picker warn "prescribing this shares a copy
/// with this client" — see <c>TrainerConsoleService</c>'s prescription diff, which is what
/// actually does the copying at save time. Listing it here without copying anything yet
/// means browsing the picker never touches the client's library.
/// </remarks>
public class ClientExerciseOptionDto
{
    public Guid Id { get; set; }

    public string Name { get; set; } = "";

    public string? NameDe { get; set; }

    public string Description { get; set; } = "";

    public string? DescriptionDe { get; set; }

    public int Type { get; set; }

    public string TargetMuscleGroups { get; set; } = "";

    public string ImageUrl { get; set; } = "";

    /// <summary>True for an exercise that belongs to the trainer rather than to the client
    /// or the system catalogue. Prescribing it copies it into the client's library.</summary>
    public bool IsTrainerOwned { get; set; }
}

/// <summary>A whole workout as the trainer wants it to be, exercises and sets included.</summary>
/// <remarks>
/// The prescription is sent as one document rather than as a stream of add/update/delete
/// calls: a builder screen has a Save button, and half-applied prescriptions are exactly
/// what a client would then train against. Anything absent from <see cref="Exercises"/> is
/// taken out of the workout.
/// </remarks>
public class ClientWorkoutRequestDto
{
    [Required, MaxLength(200)]
    public string Name { get; set; } = "";

    [MaxLength(2000)]
    public string? Description { get; set; }

    [Range(0, 2)]
    public int Difficulty { get; set; } = 1;

    [Range(1, 1440)]
    public int EstimatedDurationMinutes { get; set; } = 60;

    /// <summary>The plan this workout is a day of. Only read on create — moving a workout
    /// between plans isn't something the builder offers, so update leaves membership alone.
    /// Must be a plan belonging to the same client.</summary>
    public Guid? PlanId { get; set; }

    /// <summary>The exercises, in the order they are to be performed.</summary>
    [MaxLength(60)]
    public List<ClientWorkoutExerciseRequestDto> Exercises { get; set; } = [];
}

/// <summary>One exercise's prescription within <see cref="ClientWorkoutRequestDto"/>.</summary>
/// <remarks>
/// Carries no ordering fields. Order is the order of the list, and a set's number is its
/// position in <see cref="TargetReps"/> — the server stamps both. Letting the caller send
/// its own positions only creates a second source of truth for something the payload
/// already says, and duplicate or gapped positions are then a bug nothing rejects.
/// </remarks>
public class ClientWorkoutExerciseRequestDto
{
    /// <summary>The existing <c>WorkoutExercise</c> entry this replaces, or null for one the
    /// trainer has just added. Sending the id back matters: a new entry is a new row, and
    /// sets the client already logged stay attached to the entry they were performed
    /// against, not to whatever now sits in that slot.</summary>
    public Guid? Id { get; set; }

    /// <summary>The exercise definition to prescribe. Must be one the client can already
    /// see, or one the trainer owns — a trainer-owned exercise is copied into the client's
    /// library at save time (see <c>TrainerConsoleService</c>'s prescription diff). Changing
    /// it on an entry that already has an id is treated as a substitution: the old entry
    /// leaves the workout (keeping its history) and a new one takes its place.</summary>
    public Guid ExerciseId { get; set; }

    [MaxLength(2000)]
    public string? Notes { get; set; }

    [Range(0, int.MaxValue)]
    public int? SupersetGroupId { get; set; }

    /// <summary>One entry per prescribed set, in order — <c>["8-12", "8-12", "6"]</c> is three
    /// sets. Empty means the exercise is prescribed without a set/rep target.</summary>
    [MaxLength(30)]
    public List<string> TargetReps { get; set; } = [];
}

/// <summary>Why a trainer's write to a client's workout did or didn't go through.</summary>
/// <remarks>
/// Null-for-everything is what the rest of <c>ITrainerConsoleService</c> returns, and it is
/// enough where the only failure is "not your client". It isn't enough here: a workout the
/// trainer may not touch, a workout that doesn't exist, and a prescription naming an
/// exercise the client cannot see are three different answers, and only the last one is the
/// trainer's to fix.
/// </remarks>
public enum TrainerWorkoutStatus
{
    Ok,

    /// <summary>The caller isn't an active trainer of this client.</summary>
    NotPermitted,

    /// <summary>No such workout (or plan) belongs to the client.</summary>
    NotFound,

    /// <summary>The prescription names an exercise that is neither the client's, nor the
    /// system's, nor the trainer's own — so there is nothing to copy and nothing to
    /// prescribe. See <see cref="TrainerWorkoutResult.UnknownExerciseIds"/>.</summary>
    UnknownExercise,

    /// <summary>The workout has sessions with logged sets, so it is kept rather than
    /// deleted — the same rule <see cref="Models.WorkoutDeleteResult.HasLoggedHistory"/>
    /// applies to the client's own deletes.</summary>
    HasLoggedHistory,
}

/// <summary>Outcome of a trainer write, carrying the saved workout on success.</summary>
public readonly record struct TrainerWorkoutResult(
    TrainerWorkoutStatus Status,
    ClientWorkoutDto? Workout = null,
    IReadOnlyList<Guid>? UnknownExerciseIds = null);

/// <summary>Request payload for generating a plan's dated sessions from a weekly cycle.</summary>
/// <remarks>Mirrors what the trainee's own create flow builds client-side from
/// <c>WorkoutPlan.CyclePatternJson</c> — a name per day of the week, repeating. A name that
/// doesn't match one of the client's workouts is treated as a rest day and simply produces no
/// session for that date; see <c>TrainerConsoleService.ScheduleClientPlanAsync</c>.</remarks>
public class SchedulePlanRequestDto
{
    [Required, MinLength(1), MaxLength(14)]
    public List<string> CyclePattern { get; set; } = [];

    [Range(1, 52)]
    public int DurationWeeks { get; set; }
}
