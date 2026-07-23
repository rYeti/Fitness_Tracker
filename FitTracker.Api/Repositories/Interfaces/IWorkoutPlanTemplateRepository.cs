using FitTracker.Api.Models;

namespace FitTracker.Api.Repositories.Interfaces;

public interface IWorkoutPlanTemplateRepository
{
    Task<List<WorkoutPlanTemplate>> GetAllAsync();
}