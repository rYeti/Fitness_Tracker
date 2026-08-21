using FitTracker.Api.DTOs;
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
    private Guid UserId =>
        Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

    /// <summary>Returns all meals for the authenticated user across all dates.</summary>
    [HttpGet("all")]
    public async Task<IActionResult> GetAll()
    {
        var result = await mealService.GetAllMealsAsync(UserId);
        return Ok(result);
    }

    /// <summary>Returns all meals for the authenticated user on the given date.</summary>
    /// <param name="date">The calendar day to query. Only the date part is used —
    /// see <see cref="Repositories.MealDayWindow"/> for how it maps onto stored instants.</param>
    [HttpGet]
    public async Task<IActionResult> GetForDate([FromQuery] DateTime date)
    {
        var result = await mealService.GetMealsForDateAsync(UserId, date);
        return Ok(result);
    }

    /// <summary>Returns a single meal by ID.</summary>
    /// <param name="id">The meal ID.</param>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById([FromRoute] Guid id)
    {
        var result = await mealService.GetMealByIdAsync(id, UserId);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Creates a new meal for the authenticated user.</summary>
    /// <param name="dto">The meal data.</param>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] MealRequestDto dto)
    {
        var result = await mealService.CreateMealAsync(dto, UserId);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    /// <summary>Updates an existing meal.</summary>
    /// <param name="id">The meal ID.</param>
    /// <param name="dto">The updated meal data.</param>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update([FromRoute] Guid id, [FromBody] MealRequestDto dto)
    {
        var result = await mealService.UpdateMealAsync(id, UserId, dto);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Deletes a meal and all its food entries.</summary>
    /// <param name="id">The meal ID.</param>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete([FromRoute] Guid id)
    {
        var deleted = await mealService.DeleteMealAsync(id, UserId);
        if (!deleted) return NotFound();
        return NoContent();
    }

    /// <summary>Adds a food item to a meal.</summary>
    /// <param name="mealId">The meal ID.</param>
    /// <param name="foodItemId">The food item ID to add.</param>
    [HttpPost("{mealId:guid}/foods/{foodItemId:guid}")]
    public async Task<IActionResult> AddFood([FromRoute] Guid mealId, [FromRoute] Guid foodItemId)
    {
        var result = await mealService.AddFoodToMealAsync(mealId, UserId, foodItemId);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Adds multiple food items to a meal in a single request.</summary>
    [HttpPost("{mealId:guid}/foods/batch")]
    public async Task<IActionResult> AddFoodsBatch([FromRoute] Guid mealId, [FromBody] List<Guid> foodItemIds)
    {
        var result = await mealService.AddFoodsToMealBatchAsync(mealId, UserId, foodItemIds);
        return Ok(result);
    }

    /// <summary>Removes a food item from a meal.</summary>
    /// <param name="mealId">The meal ID.</param>
    /// <param name="foodItemId">The food item ID to remove.</param>
    [HttpDelete("{mealId:guid}/foods/{foodItemId:guid}")]
    public async Task<IActionResult> RemoveFood([FromRoute] Guid mealId, [FromRoute] Guid foodItemId)
    {
        var removed = await mealService.RemoveFoodFromMealAsync(mealId, UserId, foodItemId);
        if (!removed) return NotFound();
        return NoContent();
    }
}
