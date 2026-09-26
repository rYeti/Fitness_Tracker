using FitTracker.Api.DTOs;
using FitTracker.Api.Services;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>Handles CRUD operations for meals and their food entries.</summary>
[ApiController]
[Route("api/Meal")]
[Authorize]
public class MealController(IMealService mealService) : ControllerBase
{
    /// <summary>Returns all meals for the authenticated user across all dates.</summary>
    [HttpGet("all")]
    public async Task<IActionResult> GetAll()
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await mealService.GetAllMealsAsync(userId);
        return Ok(result);
    }

    /// <summary>Returns all meals for the authenticated user on the given date.</summary>
    /// <param name="date">The calendar day to query. Only the date part is used —
    /// see <see cref="Repositories.MealDayWindow"/> for how it maps onto stored instants.</param>
    [HttpGet]
    public async Task<IActionResult> GetForDate([FromQuery] DateTime date)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await mealService.GetMealsForDateAsync(userId, date);
        return Ok(result);
    }

    /// <summary>Returns a single meal by ID.</summary>
    /// <param name="id">The meal ID.</param>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById([FromRoute] Guid id)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await mealService.GetMealByIdAsync(id, userId);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Creates a new meal for the authenticated user.</summary>
    /// <param name="dto">The meal data.</param>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] MealRequestDto dto)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await mealService.CreateMealAsync(dto, userId);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    /// <summary>Updates an existing meal.</summary>
    /// <param name="id">The meal ID.</param>
    /// <param name="dto">The updated meal data.</param>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update([FromRoute] Guid id, [FromBody] MealRequestDto dto)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await mealService.UpdateMealAsync(id, userId, dto);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Deletes a meal and all its food entries.</summary>
    /// <param name="id">The meal ID.</param>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete([FromRoute] Guid id)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var deleted = await mealService.DeleteMealAsync(id, userId);
        if (!deleted) return NotFound();
        return NoContent();
    }

    /// <summary>Adds a food item to a meal.</summary>
    /// <param name="mealId">The meal ID.</param>
    /// <param name="foodItemId">The food item ID to add.</param>
    [HttpPost("{mealId:guid}/foods/{foodItemId:guid}")]
    public async Task<IActionResult> AddFood([FromRoute] Guid mealId, [FromRoute] Guid foodItemId)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await mealService.AddFoodToMealAsync(mealId, userId, foodItemId);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Puts foods in a meal: each entry is added, or — if the app already sent its
    /// id — made the meal's again.</summary>
    /// <remarks>
    /// How the app sends a meal's foods. A dirty meal sends every entry it holds, each under
    /// the id the app minted for it, and the batch stores each one once whatever happened to
    /// earlier attempts: it adds nothing an earlier attempt already added, and it removes
    /// nothing — so an entry another device added to the same meal, which this device has
    /// never seen, is left alone. Removing a food is its own DELETE (below).
    ///
    /// For a while the app sent the meal's whole list here as a replace (<c>PUT</c>), which
    /// deleted every entry the list didn't name — including the other device's. See
    /// docs/sync-architecture.md §18.
    ///
    /// Shipped apps send bare food item ids; see <see cref="MealFoodEntryRequestDto"/>.
    /// </remarks>
    /// <param name="mealId">The meal ID.</param>
    /// <param name="entries">The entries to add or make the meal's.</param>
    [HttpPost("{mealId:guid}/foods/batch")]
    public async Task<IActionResult> AddFoodsBatch([FromRoute] Guid mealId, [FromBody] List<MealFoodEntryRequestDto> entries)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var result = await mealService.AddFoodsToMealBatchAsync(mealId, userId, entries);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Removes a food from a meal.</summary>
    /// <remarks>
    /// Current apps name the entry, by the id they minted for it, which is the only way to say
    /// which of two portions of the same food to remove. Shipped apps name the food item, and
    /// get the first entry of it in the meal. Entry ids are looked up first; a food item id
    /// never names an entry.
    /// </remarks>
    /// <param name="mealId">The meal ID.</param>
    /// <param name="id">The entry's id, or (shipped apps) the food item's.</param>
    [HttpDelete("{mealId:guid}/foods/{id:guid}")]
    public async Task<IActionResult> RemoveFood([FromRoute] Guid mealId, [FromRoute] Guid id)
    {
        if (!User.TryGetUserId(out var userId)) return Unauthorized();
        var removed = await mealService.RemoveFoodFromMealAsync(mealId, userId, id);
        if (!removed) return NotFound();
        return NoContent();
    }
}
