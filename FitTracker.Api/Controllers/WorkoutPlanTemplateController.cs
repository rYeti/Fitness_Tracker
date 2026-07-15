using FitTracker.Api.Services.Interfaces;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;

namespace FitTracker.Api.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class WorkoutPlanTemplateController(IWorkoutPlanTemplateService service) : ControllerBase
{
    private readonly IWorkoutPlanTemplateService _service = service;

    [HttpGet]
    public async Task<IActionResult> GetAll() => Ok(await _service.GetAllAsync());
}
