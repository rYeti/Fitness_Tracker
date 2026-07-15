using FitTracker.Api.DTOs;
using FitTracker.Api.Services.Interfaces;

namespace FitTracker.Api.Services;

public class WorkoutPlanTemplateService : IWorkoutPlanTemplateService
{
    public Task<List<WorkoutPlanTemplateResponseDto>> GetAllAsync()
    {
        // TODO: query AppDbContext.WorkoutPlanTemplates and map to DTOs.
        throw new NotImplementedException();
    }
}
