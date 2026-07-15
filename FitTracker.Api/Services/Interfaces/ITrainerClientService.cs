using FitTracker.Api.DTOs;

namespace FitTracker.Api.Services.Interfaces;

public interface ITrainerClientService
{
    Task<TrainerClientResponseDto> CreateInviteAsync(Guid trainerId);
    Task<TrainerClientResponseDto?> AcceptInviteAsync(string inviteCode, Guid clientId);
    Task<List<TrainerClientResponseDto>> GetClientsAsync(Guid trainerId);
    Task<TrainerClientStatusDto> GetStatusAsync(Guid userId);
    Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId);

    /// <summary>Gates every Trainer Console read/write — a trainer may only
    /// access a client's data while that relationship is Active.</summary>
    Task<bool> IsActiveTrainerOfAsync(Guid trainerId, Guid clientId);
}
