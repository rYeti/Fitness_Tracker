using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

public interface IWorkoutPlanTemplateService
{
    Task<List<WorkoutPlanTemplateResponseDto>> GetAllAsync();
}
