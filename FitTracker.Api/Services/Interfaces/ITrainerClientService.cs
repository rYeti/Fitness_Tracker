using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

public interface ITrainerClientService
{
    Task<TrainerClientResponseDto> CreateInviteAsync(Guid trainerId);
    Task<TrainerClientResponseDto?> AcceptInviteAsync(string inviteCode, Guid clientId);
    Task<List<TrainerClientResponseDto>> GetClientsAsync(Guid trainerId);
    Task<TrainerClientStatusDto> GetStatusAsync(Guid userId);
    Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId);
}
