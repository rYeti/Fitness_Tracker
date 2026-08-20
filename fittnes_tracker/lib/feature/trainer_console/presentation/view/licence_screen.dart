import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:ForgeForm/core/design_tokens.dart';
import 'package:ForgeForm/feature/trainer_console/domain/models/trainer_licence.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/providers/trainer_licence_provider.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/view/invite_client_sheet.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/console_widgets.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/licence_banner.dart';
import 'package:ForgeForm/feature/trainer_console/presentation/widgets/seat_meter.dart';

/// The trainer's plan: what it covers, how full it is, and how to change it.
class LicenceScreen extends StatefulWidget {
  final TrainerLicenceProvider? provider;

  const LicenceScreen({super.key, this.provider});

  @override
  State<LicenceScreen> createState() => _LicenceScreenState();
}

class _LicenceScreenState extends State<LicenceScreen> {
  late final TrainerLicenceProvider _provider;
  late final bool _ownsProvider;

  @override
  void initState() {
    super.initState();
    _ownsProvider = widget.provider == null;
    _provider = widget.provider ?? TrainerLicenceProvider();
    _provider.load();
  }

  @override
  void dispose() {
    if (_ownsProvider) _provider.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<TrainerLicenceProvider>.value(
      value: _provider,
      child: Scaffold(
        appBar: AppBar(title: const Text('Your plan')),
        body: Consumer<TrainerLicenceProvider>(
          builder: (context, provider, _) {
            if (provider.isLoading) {
              return const Padding(
                padding: EdgeInsets.all(16),
                child: ConsoleSkeleton(
                  rows: 3,
                  rowHeight: 96,
                  semanticsLabel: 'Loading your plan',
                ),
              );
            }

            if (provider.error != null) {
              return ConsoleErrorState(
                message: provider.error!,
                onRetry: provider.load,
              );
            }

            final licence = provider.licence;
            if (licence == null) {
              return ConsoleEmptyState(
                icon: Icons.workspace_premium_outlined,
                title: 'No plan yet',
                message: 'Set up a trainer plan to start taking on clients.',
                action: FilledButton(
                  onPressed: provider.load,
                  child: const Text('Set up'),
                ),
              );
            }

            return _LicenceBody(licence: licence, provider: provider);
          },
        ),
      ),
    );
  }
}

class _LicenceBody extends StatelessWidget {
  final TrainerLicence licence;
  final TrainerLicenceProvider provider;

  const _LicenceBody({required this.licence, required this.provider});

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.of(context).size.width > 1024;

    return SingleChildScrollView(
      padding: EdgeInsets.all(isDesktop ? 32 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (LicenceBanner.isWarranted(licence)) ...[
                LicenceBanner(
                  licence: licence,
                  onManage: () => _openBilling(context),
                ),
                const SizedBox(height: 24),
              ],
              _PlanCard(licence: licence, provider: provider),
              const SizedBox(height: 24),
              const ConsoleSectionTitle(title: 'Clients'),
              ConsoleCard(
                padding: const EdgeInsets.all(24),
                radius: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SeatMeter(licence: licence),
                    const SizedBox(height: 16),
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        onPressed: () => InviteClientSheet.show(context),
                        icon: const Icon(Icons.person_add_outlined, size: 18),
                        label: const Text('Invite a client'),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const ConsoleSectionTitle(title: 'Change plan'),
              for (final tier in const [
                LicenceTier.solo,
                LicenceTier.pro,
                LicenceTier.studio,
              ])
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TierRow(
                    tier: tier,
                    current: licence.tier,
                    onSelect: () => _startCheckout(context, tier),
                  ),
                ),
              const SizedBox(height: 16),
              Text(
                'Paid plans include ForgeForm Pro for you and every client on '
                'your roster. The free plan covers '
                '${licence.tier == LicenceTier.free ? licence.seatLimit : 3} '
                'clients without Pro.',
                style: TextStyle(
                  fontFamily: 'Exo 2',
                  fontSize: 12,
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _startCheckout(BuildContext context, LicenceTier tier) async {
    final url = await provider.startCheckout(tier);
    if (url != null && context.mounted) await _open(url);
  }

  Future<void> _openBilling(BuildContext context) async {
    final url = await provider.openBillingPortal();
    if (url != null && context.mounted) await _open(url);
  }
}

/// Checkout and the billing portal are hosted by Stripe, so both are a
/// redirect out of the app rather than an in-app flow.
Future<void> _open(String url) async {
  await launchUrl(
    Uri.parse(url),
    // On web this replaces the tab, which is what Checkout expects; elsewhere
    // it hands off to the system browser so the payment sheet is trusted
    // chrome rather than an embedded webview.
    mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
    webOnlyWindowName: kIsWeb ? '_self' : null,
  );
}

class _PlanCard extends StatelessWidget {
  final TrainerLicence licence;
  final TrainerLicenceProvider provider;

  const _PlanCard({required this.licence, required this.provider});

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ConsoleCard(
      padding: const EdgeInsets.all(24),
      radius: 16,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${licence.tier.label} plan',
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: colors.onSurface,
                  ),
                ),
              ),
              _StatusPill(licence: licence),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(
                licence.grantsPro ? Icons.check_circle_outline : Icons.remove_circle_outline,
                size: 18,
                color: licence.grantsPro
                    ? ForgeColors.statusOk
                    : colors.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  licence.grantsPro
                      ? 'Pro included for you and every client'
                      : 'Pro not included — upgrade to cover your clients',
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 13,
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (licence.hasBillingAccount) ...[
            const SizedBox(height: 16),
            SizedBox(
              height: 44,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final url = await provider.openBillingPortal();
                  if (url != null) await _open(url);
                },
                icon: const Icon(Icons.receipt_long_outlined, size: 18),
                label: const Text('Manage billing'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  final TrainerLicence licence;

  const _StatusPill({required this.licence});

  @override
  Widget build(BuildContext context) {
    final (tone, label) = switch (licence.status) {
      LicenceStatus.active => (ForgeColors.statusOk, 'Active'),
      LicenceStatus.trialing => (ForgeColors.forgeOrange, 'Trial'),
      LicenceStatus.pastDue => (ForgeColors.statusWarn, 'Payment failed'),
      LicenceStatus.canceled => (ForgeColors.statusBad, 'Cancelled'),
    };

    return Semantics(
      label: 'Status: $label',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: tone.withValues(alpha: 0.5)),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontFamily: 'Exo 2',
            fontWeight: FontWeight.w600,
            fontSize: 12,
          ),
        ),
      ),
    );
  }
}

class _TierRow extends StatelessWidget {
  final LicenceTier tier;
  final LicenceTier current;
  final VoidCallback onSelect;

  const _TierRow({
    required this.tier,
    required this.current,
    required this.onSelect,
  });

  /// Seat counts mirror LicencePlanCatalog on the server. Prices deliberately
  /// aren't here — they live in Stripe, so the ladder can be retuned without a
  /// release.
  static const _seats = {
    LicenceTier.solo: 10,
    LicenceTier.pro: 30,
    LicenceTier.studio: 100,
  };

  @override
  Widget build(BuildContext context) {
    final isCurrent = tier == current;
    final colors = Theme.of(context).colorScheme;

    return ConsoleCard(
      onTap: isCurrent ? null : onSelect,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tier.label,
                  style: TextStyle(
                    fontFamily: 'Montserrat',
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                    color: colors.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Up to ${_seats[tier]} clients, Pro included',
                  style: TextStyle(
                    fontFamily: 'Exo 2',
                    fontSize: 12,
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
          ),
          if (isCurrent)
            const Text(
              'Current',
              style: TextStyle(
                fontFamily: 'Exo 2',
                fontWeight: FontWeight.w600,
                fontSize: 12,
                color: ForgeColors.statusOk,
              ),
            )
          else
            const Icon(Icons.chevron_right),
        ],
      ),
    );
  }
}
