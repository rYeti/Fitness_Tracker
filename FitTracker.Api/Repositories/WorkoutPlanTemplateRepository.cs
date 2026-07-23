using FitTracker.Api.Data;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using Microsoft.EntityFrameworkCore;

namespace FitTracker.Api.Repositories;

public class WorkoutPlanTemplateRepository(AppDbContext context) : IWorkoutPlanTemplateRepository
{
    private readonly AppDbContext _dbContext = context;

    public async Task<List<WorkoutPlanTemplate>> GetAllAsync() =>
        await _dbContext.WorkoutPlanTemplates.ToListAsync();
}