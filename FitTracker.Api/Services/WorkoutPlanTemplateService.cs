using FitTracker.Api.DTOs;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class WorkoutPlanTemplateService(IWorkoutPlanTemplateRepository repo) : IWorkoutPlanTemplateService
{
    private readonly IWorkoutPlanTemplateRepository _repo = repo;

    /// <inheritdoc/>
    public async Task<List<WorkoutPlanTemplateResponseDto>> GetAllAsync()
    {
        var templates = await _repo.GetAllAsync();
        return [.. templates.Select(t => new WorkoutPlanTemplateResponseDto
        {
            Id = t.Id,
            Name = t.Name,
            Description = t.Description,
            Icon = t.Icon,
            DaysPerWeek = t.DaysPerWeek,
        })];
    }
}
