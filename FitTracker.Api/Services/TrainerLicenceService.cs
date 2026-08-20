using FitTracker.Api.DTOs;
using FitTracker.Api.Models;
using FitTracker.Api.Repositories.Interfaces;
using FitTracker.Api.Services.Interfaces;
using Stripe;
using Stripe.Checkout;

namespace FitTracker.Api.Services;

public class TrainerLicenceService(
    ITrainerLicenceRepository licences,
    ITrainerClientRepository clients,
    LicencePlanCatalog catalog,
    LicenceStateMachine stateMachine,
    IConfiguration configuration,
    ILogger<TrainerLicenceService> logger) : ITrainerLicenceService
{
    private readonly ITrainerLicenceRepository _licences = licences;
    private readonly ITrainerClientRepository _clients = clients;
    private readonly LicencePlanCatalog _catalog = catalog;
    private readonly LicenceStateMachine _stateMachine = stateMachine;
    private readonly IConfiguration _configuration = configuration;
    private readonly ILogger<TrainerLicenceService> _logger = logger;

    public async Task<TrainerLicenceDto> GetOrCreateAsync(Guid trainerId)
    {
        var licence = await _licences.GetOrCreateAsync(trainerId);
        var seatsUsed = await _clients.CountSeatsUsedAsync(trainerId);
        return TrainerLicenceDto.From(licence, seatsUsed);
    }

    public async Task<string?> CreateCheckoutSessionAsync(Guid trainerId, LicenceTier tier)
    {
        if (!LicencePlanCatalog.PurchasableTiers.Contains(tier)) return null;

        var priceId = _catalog.PriceFor(tier);
        if (string.IsNullOrWhiteSpace(priceId)) return null;

        var licence = await _licences.GetOrCreateAsync(trainerId);
        var customerId = licence.StripeCustomerId ?? await CreateCustomerAsync(licence, trainerId);

        var options = new SessionCreateOptions
        {
            Mode = "subscription",
            Customer = customerId,
            // Correlates the completed session back to our trainer even if the
            // customer record is somehow out of step.
            ClientReferenceId = trainerId.ToString(),
            LineItems = [new SessionLineItemOptions { Price = priceId, Quantity = 1 }],
            SuccessUrl = $"{WebOrigin()}/#/trainer/licence?checkout=success",
            CancelUrl = $"{WebOrigin()}/#/trainer/licence?checkout=cancelled",
        };

        if (!licence.HasUsedTrial)
        {
            options.SubscriptionData = new SessionSubscriptionDataOptions
            {
                TrialPeriodDays = TrialDays,
            };
            // A card is required for the trial. A cardless trial would just be
            // the free-Pro loophole again on a 14-day reset: make an account,
            // start a trial, take the Pro, walk away, repeat.
            options.PaymentMethodCollection = "always";
        }

        var session = await new SessionService().CreateAsync(options);
        return session.Url;
    }

    public async Task<string?> CreatePortalSessionAsync(Guid trainerId)
    {
        var licence = await _licences.GetByTrainerAsync(trainerId);
        if (licence?.StripeCustomerId == null) return null;

        var session = await new Stripe.BillingPortal.SessionService().CreateAsync(
            new Stripe.BillingPortal.SessionCreateOptions
            {
                Customer = licence.StripeCustomerId,
                ReturnUrl = $"{WebOrigin()}/#/trainer/licence",
            });
        return session.Url;
    }

    public async Task HandleWebhookAsync(string payload, string signatureHeader)
    {
        var secret = _configuration["Stripe:WebhookSecret"];
        if (string.IsNullOrWhiteSpace(secret))
        {
            throw new InvalidOperationException("Stripe:WebhookSecret is not configured.");
        }

        // Throws StripeException on a bad signature. Anyone can POST to this
        // endpoint, so the signature is the only thing establishing that a
        // payload actually came from Stripe.
        var stripeEvent = EventUtility.ConstructEvent(payload, signatureHeader, secret);

        var snapshot = await ToSnapshotAsync(stripeEvent);
        if (snapshot == null)
        {
            _logger.LogDebug("Ignoring unhandled Stripe event {Type}", stripeEvent.Type);
            return;
        }

        var licence = await _licences.GetBySubscriptionAsync(snapshot.SubscriptionId)
                   ?? await _licences.GetByCustomerAsync(snapshot.CustomerId);

        if (licence == null)
        {
            // A subscription we can't attribute. Worth shouting about: it means
            // a trainer has paid and isn't getting what they bought.
            _logger.LogWarning(
                "Stripe subscription {Subscription} (customer {Customer}) matched no licence",
                snapshot.SubscriptionId, snapshot.CustomerId);
            return;
        }

        if (_stateMachine.Apply(licence, snapshot))
        {
            await _licences.SaveAsync(licence);
        }
    }

    /// <summary>Extracts the fields we act on from the events we handle, or null
    /// for an event type we don't care about.</summary>
    private async Task<SubscriptionSnapshot?> ToSnapshotAsync(Event stripeEvent)
    {
        var subscription = stripeEvent.Data.Object as Subscription;

        if (subscription == null && stripeEvent.Data.Object is Session session)
        {
            // checkout.session.completed carries the subscription by id only.
            if (string.IsNullOrWhiteSpace(session.SubscriptionId)) return null;
            subscription = await new SubscriptionService().GetAsync(session.SubscriptionId);
        }

        if (subscription == null && stripeEvent.Data.Object is Invoice invoice)
        {
            var subscriptionId = invoice.Parent?.SubscriptionDetails?.SubscriptionId;
            if (string.IsNullOrWhiteSpace(subscriptionId)) return null;
            subscription = await new SubscriptionService().GetAsync(subscriptionId);
        }

        if (subscription == null) return null;

        var item = subscription.Items?.Data?.FirstOrDefault();

        return new SubscriptionSnapshot(
            SubscriptionId: subscription.Id,
            CustomerId: subscription.CustomerId,
            PriceId: item?.Price?.Id,
            StripeStatus: subscription.Status,
            // current_period_end moved onto the subscription *item* in recent
            // Stripe API versions; read it from there.
            CurrentPeriodEnd: item?.CurrentPeriodEnd,
            EventTime: stripeEvent.Created);
    }

    private async Task<string> CreateCustomerAsync(TrainerLicence licence, Guid trainerId)
    {
        var customer = await new CustomerService().CreateAsync(new CustomerCreateOptions
        {
            Metadata = new Dictionary<string, string> { ["trainerId"] = trainerId.ToString() },
        });
        licence.StripeCustomerId = customer.Id;
        await _licences.SaveAsync(licence);
        return customer.Id;
    }

    /// <summary>Where to send the trainer back to after Checkout. Reuses the
    /// configured web origin so there's one place that knows the console's URL.</summary>
    private string WebOrigin() =>
        _configuration.GetSection("Cors:AllowedOrigins").Get<string[]>()?.FirstOrDefault()?.TrimEnd('/')
        ?? "http://localhost:5000";

    private const int TrialDays = 14;
}
