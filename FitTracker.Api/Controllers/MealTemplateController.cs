using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

/// <summary>Handles CRUD operations for the user's meal templates.</summary>
[ApiController]
[Route("api/MealTemplate")]
[Authorize]
public class MealTemplateController(IMealTemplateService mealTemplateService) : ControllerBase
{
    private Guid UserId =>
        Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);

    /// <summary>Returns all meal templates for the authenticated user.</summary>
    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var result = await mealTemplateService.GetAllAsync(UserId);
        return Ok(result);
    }

    /// <summary>Returns a single meal template by ID.</summary>
    /// <param name="id">The template ID.</param>
    [HttpGet("{id:guid}")]
    public async Task<IActionResult> GetById([FromRoute] Guid id)
    {
        var result = await mealTemplateService.GetByIdAsync(id, UserId);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Creates a new meal template for the authenticated user.</summary>
    /// <param name="dto">The template data including items.</param>
    [HttpPost]
    public async Task<IActionResult> Create([FromBody] MealTemplateRequestDto dto)
    {
        var result = await mealTemplateService.CreateAsync(dto, UserId);
        return CreatedAtAction(nameof(GetById), new { id = result.Id }, result);
    }

    /// <summary>Replaces an existing meal template and all its items.</summary>
    /// <param name="id">The template ID.</param>
    /// <param name="dto">The updated template data.</param>
    [HttpPut("{id:guid}")]
    public async Task<IActionResult> Update([FromRoute] Guid id, [FromBody] MealTemplateRequestDto dto)
    {
        var result = await mealTemplateService.UpdateAsync(id, UserId, dto);
        if (result is null) return NotFound();
        return Ok(result);
    }

    /// <summary>Deletes a meal template and all its items.</summary>
    /// <param name="id">The template ID.</param>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete([FromRoute] Guid id)
    {
        var deleted = await mealTemplateService.DeleteAsync(id, UserId);
        if (!deleted) return NotFound();
        return NoContent();
    }
}
