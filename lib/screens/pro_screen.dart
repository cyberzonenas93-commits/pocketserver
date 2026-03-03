import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../app/theme.dart';
import '../services/monetization/monetization_service.dart';

class ProScreen extends StatelessWidget {
  const ProScreen({super.key});

  static const List<({IconData icon, String text})> benefits = [
    (icon: Icons.block_rounded, text: 'No ads'),
    (icon: Icons.all_inclusive_rounded, text: 'Unlimited upload size'),
    (icon: Icons.delete_outline_rounded, text: 'Delete files'),
    (icon: Icons.drive_file_rename_outline_rounded, text: 'Rename files'),
    (icon: Icons.clear_all_rounded, text: 'Clear all files'),
    (icon: Icons.image_rounded, text: 'Thumbnails'),
    (icon: Icons.lock_outline_rounded, text: 'PIN protection on web'),
    (icon: Icons.settings_ethernet_rounded, text: 'Custom port'),
    (icon: Icons.wb_sunny_outlined, text: 'Keep screen awake'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildAppBar(context),
              Expanded(
                child: Consumer<MonetizationService>(
                  builder: (context, monetization, _) {
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                      children: [
                        const SizedBox(height: 16),
                        _buildHeader(),
                        const SizedBox(height: 28),
                        _buildBenefitsGrid(),
                        const SizedBox(height: 32),
                        if (monetization.isLoading)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: CircularProgressIndicator(color: AppTheme.accent),
                            ),
                          )
                        else ...[
                          if (monetization.monthlyProduct != null)
                            _buildPurchaseButton(
                              context,
                              icon: Icons.calendar_month_rounded,
                              label: 'Monthly – ${monetization.monthlyProduct!.price}',
                              onPressed: monetization.buyMonthly,
                            ),
                          if (monetization.monthlyProduct != null) const SizedBox(height: 12),
                          if (monetization.yearlyProduct != null)
                            _buildPurchaseButton(
                              context,
                              icon: Icons.workspace_premium_rounded,
                              label: 'Yearly – ${monetization.yearlyProduct!.price}',
                              onPressed: monetization.buyYearly,
                              highlighted: true,
                            ),
                          if (!monetization.productsLoaded && !monetization.isLoading)
                            Padding(
                              padding: const EdgeInsets.all(8),
                              child: Center(
                                child: Text(
                                  'Loading products…',
                                  style: GoogleFonts.dmSans(color: AppTheme.textMuted),
                                ),
                              ),
                            ),
                          const SizedBox(height: 16),
                          TextButton.icon(
                            onPressed: monetization.restorePurchases,
                            icon: const Icon(Icons.restore_rounded, size: 20),
                            label: const Text('Restore purchases'),
                            style: TextButton.styleFrom(foregroundColor: AppTheme.textMuted),
                          ),
                        ],
                        if (monetization.isPro) ...[
                          const SizedBox(height: 24),
                          _buildProBadge(),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
            onPressed: () => Navigator.of(context).pop(),
            color: AppTheme.text,
          ),
          const SizedBox(width: 8),
          Text(
            'Go Pro',
            style: GoogleFonts.dmSans(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
              letterSpacing: -0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 36, horizontal: 24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.accentSecondary.withValues(alpha: 0.2),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.accent.withValues(alpha: 0.25),
                  AppTheme.accentSecondary.withValues(alpha: 0.2),
                ],
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.workspace_premium_rounded,
              size: 56,
              color: AppTheme.accent,
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'PocketServer Pro',
            style: GoogleFonts.dmSans(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: AppTheme.text,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Unlock all features and remove ads.',
            style: GoogleFonts.dmSans(
              fontSize: 15,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildBenefitsGrid() {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: benefits.map((b) => _benefitChip(b.icon, b.text)).toList(),
    );
  }

  Widget _benefitChip(IconData icon, String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceElevated.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 22, color: AppTheme.accent),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.dmSans(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: AppTheme.text,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPurchaseButton(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool highlighted = false,
  }) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 22),
        label: Text(label),
        style: FilledButton.styleFrom(
          backgroundColor: highlighted
              ? AppTheme.accent
              : AppTheme.surfaceElevated,
          foregroundColor: highlighted ? AppTheme.primary : AppTheme.text,
          padding: const EdgeInsets.symmetric(vertical: 18),
          minimumSize: const Size(double.infinity, 56),
          side: highlighted ? null : BorderSide(color: AppTheme.accent.withValues(alpha: 0.4)),
        ),
      ),
    );
  }

  Widget _buildProBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.accent.withValues(alpha: 0.2),
            AppTheme.accent.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 26),
          const SizedBox(width: 12),
          Text(
            'You have Pro',
            style: GoogleFonts.dmSans(
              fontWeight: FontWeight.w700,
              fontSize: 16,
              color: AppTheme.accent,
            ),
          ),
        ],
      ),
    );
  }
}
