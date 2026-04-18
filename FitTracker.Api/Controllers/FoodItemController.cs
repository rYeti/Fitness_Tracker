using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>Handles CRUD operations for the user's food item library.</summary>
[ApiController]
[Route("api/FoodItem")]
[Authorize]
public class FoodItemController(IFoodItemService foodItemService) : ControllerBase
{
    private Guid UserId =>
        Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

    /// <summary>Returns all food items belonging to the authenticated user.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var result = await foodItemService.GetUserFoodItemsAsync(UserId);
        return Ok(result);
    }

    /// <summary>Returns a single food item by ID.</summary>
    /// <param name="id">The food item ID.</param>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById([FromRoute] Guid id)
    {
        var result = await foodItemService.GetFoodItemByIdAsync(id, UserId);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Creates a new food item for the authenticated user.</summary>
    /// <param name="dto">The food item data.</param>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] FoodItemRequestDto dto)
    {
        var result = await foodItemService.CreateFoodItemAsync(dto, UserId);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    /// <summary>Updates an existing food item.</summary>
    /// <param name="id">The food item ID.</param>
    /// <param name="dto">The updated food item data.</param>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update([FromRoute] Guid id, [FromBody] FoodItemRequestDto dto)
    {
        var result = await foodItemService.UpdateFoodItemAsync(id, UserId, dto);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Deletes a food item.</summary>
    /// <param name="id">The food item ID.</param>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete([FromRoute] Guid id)
    {
        var deleted = await foodItemService.DeleteFoodItemAsync(id, UserId);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
