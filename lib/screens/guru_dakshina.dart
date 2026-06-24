import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../theme/colors.dart';

/// Membership / Guru Dakshina page.
///
/// Supports 3 user states. For now the state + data are DUMMY so all three
/// views can be tested. Later, wire `_status`, `_trialDaysRemaining`,
/// `_renewalDate`, and `_localizedPrice` to your billing / Firestore layer.
enum MembershipStatus { guest, trial, active }

class GuruDakshinaPage extends StatefulWidget {
  const GuruDakshinaPage({super.key});

  @override
  State<GuruDakshinaPage> createState() => _GuruDakshinaPageState();
}

class _GuruDakshinaPageState extends State<GuruDakshinaPage> {
  static const int _trialLengthDays = 30;

  MembershipStatus _status = MembershipStatus.trial;
  int _trialDaysRemaining = _trialLengthDays;
  String _renewalDate = '';
  bool _isLoading = true;

  // Price string — later fetched from Apple StoreKit / Google Play Billing.
  final String _localizedPrice = '₹199';

  @override
  void initState() {
    super.initState();
    _resolveStatus();
  }

  Future<void> _resolveStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null || user.isAnonymous) {
        if (mounted) {
          setState(() {
            _status = MembershipStatus.guest;
            _isLoading = false;
          });
        }
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();

      if (data == null) {
        if (mounted) {
          setState(() {
            _status = MembershipStatus.trial;
            _trialDaysRemaining = _trialLengthDays;
            _isLoading = false;
          });
        }
        return;
      }

      final subscriptionStatus = data['subscription_status'] as String?;

      if (subscriptionStatus == 'active') {
        final renewalTs = data['renewal_date'] as Timestamp?;
        final renewal = renewalTs != null
            ? DateFormat('d MMMM yyyy').format(renewalTs.toDate())
            : '—';
        if (mounted) {
          setState(() {
            _status = MembershipStatus.active;
            _renewalDate = renewal;
            _isLoading = false;
          });
        }
        return;
      }

      final trialTs = data['trialStartDate'] as Timestamp?;
      if (trialTs != null) {
        final daysElapsed =
            DateTime.now().difference(trialTs.toDate()).inDays;
        final remaining =
            (_trialLengthDays - daysElapsed).clamp(0, _trialLengthDays);
        if (mounted) {
          setState(() {
            _status = MembershipStatus.trial;
            _trialDaysRemaining = remaining;
            _isLoading = false;
          });
        }
      } else {
        // Signed-in user with no trialStartDate yet — safe fallback.
        if (mounted) {
          setState(() {
            _status = MembershipStatus.trial;
            _trialDaysRemaining = _trialLengthDays;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint('GuruDakshina: _resolveStatus error: $e');
      if (mounted) {
        setState(() {
          _status = MembershipStatus.trial;
          _trialDaysRemaining = _trialLengthDays;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: cs.surface,
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        title:  Text('Guru Dakshina', style: theme.textTheme.titleLarge),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 24),
              // ── Subtitle ──
              Text(
                'Your membership contribution helps sustain MyShankara and '
                    'preserve timeless wisdom.',
                style: tt.bodyMedium?.copyWith(
                  color: cs.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),

              // ── Status chip ──
              _statusChip(context),
              const SizedBox(height: 20),

              // ── State-specific content ──
              if (_status == MembershipStatus.guest) _guestView(context),
              if (_status == MembershipStatus.trial) _trialView(context),
              if (_status == MembershipStatus.active) _activeView(context),
            ],
          ),
        ),
      ),
    );
  }

  // ── Status chip ───────────────────────────────────────────────────────────
  Widget _statusChip(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    late String label;
    late Color color;
    switch (_status) {
      case MembershipStatus.guest:
        label = 'Guest';
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        break;
      case MembershipStatus.trial:
        if (_trialDaysRemaining <= 0) {
          label = 'Trial Expired';
          color = Theme.of(context).colorScheme.error; // red
        } else {
          label = 'Free Trial Active';
          color = AppColors.accent;
        }
        break;
      case MembershipStatus.active:
        label = 'Membership Active';
        color = AppColors.primary;
        break;
    }
    return Row(
      children: [
        Text(
          'Current status: ',
          style: tt.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.4)),
          ),
          child: Text(
            label,
            style: tt.bodySmall?.copyWith(
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  // ── 1. GUEST VIEW ───────────────────────────────────────────────────────
  Widget _guestView(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Begin your sacred journey with a free trial.',
          style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        _benefitsCard(
          context,
          title: 'Trial & Membership Benefits',
          benefits: const [
            'Full Daily Darshan access',
            'Diya Tracker',
            'Unlimited Guru Chat',
          ],
        ),
        const SizedBox(height: 24),
        _primaryButton(
          context,
          label: 'Start 30-Day Free Trial',
          onTap: () => context.go('/login'),
        ),
      ],
    );
  }

  // ── 2. TRIAL VIEW ─────────────────────────────────────────────────────────
  Widget _trialView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Trial days remaining banner
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              const Icon(Icons.timer_outlined, color: AppColors.accent),
              const SizedBox(width: 12),
              Text(
                _trialDaysRemaining > 0
                    ? '$_trialDaysRemaining trial days remaining'
                    : 'Your free trial has ended',
                style: tt.titleSmall?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Your sacred journey has begun. Continue uninterrupted after your '
              'free trial.',
          style: tt.bodyMedium?.copyWith(
            color: cs.onSurface.withValues(alpha: 0.75),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 20),
        _planCard(context),
        const SizedBox(height: 10),
        Text(
          'Automatically renews monthly. Cancel anytime through Apple or '
              'Google Play.',
          style: tt.bodySmall?.copyWith(
            color: cs.onSurfaceVariant,
            height: 1.4,
          ),
        ),
        const SizedBox(height: 34),
        _primaryButton(
          context,
          label: 'Begin Membership',
          onTap: _onBeginMembership,
        ),
      ],
    );
  }

  // ── 3. ACTIVE MEMBER VIEW ───────────────────────────────────────────────
  Widget _activeView(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _planCard(context),
        const SizedBox(height: 16),
        Row(
          children: [
            Icon(Icons.event_available_outlined,
                color: AppColors.primary, size: 20),
            const SizedBox(width: 8),
            Text(
              'Renews on $_renewalDate',
              style: tt.bodyMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              const Text('🙏', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Thank you for being part of MyShankara.',
                  style: tt.bodyMedium?.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        _primaryButton(
          context,
          label: 'Manage Membership',
          onTap: _onManageMembership,
        ),
      ],
    );
  }

  // ── Reusable: benefits card ─────────────────────────────────────────────
  Widget _benefitsCard(
      BuildContext context, {
        required String title,
        required List<String> benefits,
      }) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: cs.outline.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.06),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: tt.titleSmall?.copyWith(
              color: AppColors.primary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          ...benefits.map(
                (b) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Icon(Icons.check_circle,
                      color: AppColors.accent, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      b,
                      style: tt.bodyMedium?.copyWith(
                        color: cs.onSurface.withValues(alpha: 0.85),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable: membership plan card ──────────────────────────────────────
  Widget _planCard(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.85),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'MyShankara Membership',
            style: tt.titleMedium?.copyWith(
              color: Colors.white,
              fontSize: 22,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                _localizedPrice,
                style: tt.headlineMedium?.copyWith(
                  color: AppColors.accent,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 4),
              Text(
                '/month',
                style: tt.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Localized pricing shown automatically by Apple / Google.',
            style: tt.bodySmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  // ── Reusable: primary button ────────────────────────────────────────────
  Widget _primaryButton(
      BuildContext context, {
        required String label,
        required VoidCallback onTap,
      }) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: FilledButton(
        style: FilledButton.styleFrom(
          // Per-step color: saffron → indigo → green → terracotta
          backgroundColor: AppColors.accent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        onPressed: onTap,
        child: Text(
          label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.primary),
        ),
      ),
    );
  }

  // ── Actions (stub for now) ──────────────────────────────────────────────
  void _onBeginMembership() {
    // TODO: open in_app_purchase subscription flow
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Subscription flow coming soon.')),
    );
  }

  void _onManageMembership() {
    // TODO: open store subscription management
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Opening store subscription management…')),
    );
  }
}