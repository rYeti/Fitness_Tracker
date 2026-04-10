using FitTracker.Api.Data;
using FitTracker.Api.Models;
using Microsoft.EntityFrameworkCore;
using FitTracker.Api.Repositories.Interfaces;
namespace FitTracker.Api.Repositories;

public class WeightTrackingRepository(AppDbContext context) : IWeightTrackingRepository
{

}
