using FitTracker.Api.DTOs;
using FitTracker.Api.Models;

namespace FitTracker.Api.Services.Interfaces;

public interface ITrainerClientService
{
    /// <summary>Generates a new invite code a trainer can share with a prospective client.</summary>
    Task<TrainerClientResponseDto> CreateInviteAsync(Guid trainerId);

    /// <summary>Redeems an invite code, linking the client to the trainer who created it. Returns null if the code is invalid.</summary>
    Task<TrainerClientResponseDto?> AcceptInviteAsync(string inviteCode, Guid clientId);

    /// <summary>Returns all clients (any relationship status) linked to the given trainer.</summary>
    Task<List<TrainerClientResponseDto>> GetClientsAsync(Guid trainerId);

    /// <summary>Returns the trainer/client relationship status for a given user.</summary>
    Task<TrainerClientStatusDto> GetStatusAsync(Guid userId);

    /// <summary>Ends a trainer/client relationship. Requires the requesting user to be a party to it.</summary>
    Task<bool> RemoveRelationshipAsync(Guid relationshipId, Guid requestingUserId);

    /// <summary>Gates every Trainer Console read/write — a trainer may only
    /// access a client's data while that relationship is Active.</summary>
    Task<bool> IsActiveTrainerOfAsync(Guid trainerId, Guid clientId);

    Task<TrainerClient?> GetActiveRelationshipAsync(Guid trainerId, Guid clientId);
}
