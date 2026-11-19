import 'dart:io';
import 'dart:ui';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
// //// AdMob Integration
import '../app/theme.dart';
import '../services/ad_service.dart';
import '../services/monetization/monetization_service.dart';
import '../services/wifi_transfer_service.dart';
import 'pro_screen.dart';

class TransferPage extends StatefulWidget {
  const TransferPage({super.key});

  @override
  State<TransferPage> createState() => _TransferPageState();
}

class _TransferPageState extends State<TransferPage> {
  bool? _isPhysicalDevice;
  bool _bannerAllowed = false;

  @override
  void initState() {
    super.initState();
    _loadIsPhysicalDevice();
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) setState(() => _bannerAllowed = true);
    });
  }

  Future<void> _loadIsPhysicalDevice() async {
    final deviceInfo = DeviceInfoPlugin();
    bool? physical;
    if (Platform.isAndroid) {
      final android = await deviceInfo.androidInfo;
      physical = android.isPhysicalDevice;
    } else if (Platform.isIOS) {
      final ios = await deviceInfo.iosInfo;
      physical = ios.isPhysicalDevice;
    }
    if (mounted) setState(() => _isPhysicalDevice = physical);
  }

  void _showPortDialog(BuildContext context, MonetizationService monetization) {
    final controller = TextEditingController(text: '${monetization.preferredPort}');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Custom port'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Port (1024–65535)'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              final p = int.tryParse(controller.text);
              if (p != null && p >= 1024 && p <= 65535) {
                monetization.setPreferredPort(p);
                Navigator.pop(ctx);
              }
            },
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

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
                child: Consumer<WiFiTransferService>(
                  builder: (context, service, _) {
                    return CustomScrollView(
                      slivers: [
                        if (service.isReceiving) _buildStatusBanner('Receiving files…', true),
                        if (service.showUploadComplete && !service.isReceiving)
                          _buildStatusBanner('Upload complete', false),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          sliver: SliverToBoxAdapter(
                            child: Column(
                            children: [
                              const SizedBox(height: 24),
                              _buildHeroStatus(service),
                              const SizedBox(height: 32),
                              if (service.isRunning && service.serverUrl != null) ...[
                                _buildUrlCard(context, service),
                                const SizedBox(height: 16),
                                _buildCopyButton(context, service),
                                if (service.isLikelyEmulator && _isPhysicalDevice != true) ...[
                                  const SizedBox(height: 20),
                                  _buildEmulatorNotice(service),
                                ],
                                if (service.isDiscoverableOnNetwork) ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Discoverable as "PocketServer" on the network.',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: AppTheme.accent.withValues(alpha: 0.95),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                if (service.isReachableFromNetwork) ...[
                                  const SizedBox(height: 28),
                                  Text(
                                    'Or scan to open on computer',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 14,
                                      color: AppTheme.text,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 16),
                                  _buildQrCard(service),
                                ] else ...[
                                  const SizedBox(height: 12),
                                  Text(
                                    'Connect to WiFi and restart the server to get a reachable address.',
                                    style: GoogleFonts.dmSans(
                                      fontSize: 13,
                                      color: AppTheme.warning.withValues(alpha: 0.95),
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                                const SizedBox(height: 32),
                              ],
                              _buildStartStopButton(service),
                              const SizedBox(height: 20),
                              _buildProSection(context),
                            ],
                          ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
              // //// AdMob Integration
              Consumer2<AdService, WiFiTransferService>(
                builder: (_, ads, wifi, __) {
                  if (wifi.isReceiving) return const SizedBox.shrink();
                  if (wifi.showUploadComplete) return const SizedBox.shrink();
                  if (!_bannerAllowed) return const SizedBox.shrink();
                  final monetization = context.read<MonetizationService>();
                  if (monetization.isPro) return const SizedBox.shrink();
                  return ads.buildBanner();
                },
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
          Text(
            'PocketServer',
            style: GoogleFonts.dmSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: AppTheme.text,
              letterSpacing: -0.5,
            ),
          ),
          const Spacer(),
          Consumer<MonetizationService>(
            builder: (_, monetization, __) {
              if (monetization.isPro) return const SizedBox.shrink();
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProScreen()),
                  ),
                  borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AppTheme.accentSecondary.withValues(alpha: 0.3),
                          AppTheme.accent.withValues(alpha: 0.2),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AppTheme.radiusSmall),
                      border: Border.all(
                        color: AppTheme.accent.withValues(alpha: 0.4),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.workspace_premium, size: 20, color: AppTheme.accent),
                        const SizedBox(width: 6),
                        Text(
                          'Pro',
                          style: GoogleFonts.dmSans(
                            fontWeight: FontWeight.w600,
                            color: AppTheme.accent,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBanner(String message, bool loading) {
    return SliverToBoxAdapter(
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.accent.withValues(alpha: 0.25),
              AppTheme.accent.withValues(alpha: 0.12),
            ],
          ),
          borderRadius: BorderRadius.circular(AppTheme.radius),
          border: Border.all(color: AppTheme.accent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            if (loading)
              const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.accent),
              )
            else
              Icon(Icons.check_circle_rounded, color: AppTheme.accent, size: 26),
            const SizedBox(width: 14),
            Text(
              message,
              style: GoogleFonts.dmSans(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: AppTheme.accent,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeroStatus(WiFiTransferService service) {
    final isRunning = service.isRunning;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(
          color: isRunning
              ? AppTheme.accent.withValues(alpha: 0.35)
              : AppTheme.textMuted.withValues(alpha: 0.2),
          width: 1,
        ),
        boxShadow: [
          if (isRunning)
            BoxShadow(
              color: AppTheme.accent.withValues(alpha: 0.15),
              blurRadius: 24,
              spreadRadius: 0,
            ),
        ],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isRunning
                  ? AppTheme.accent.withValues(alpha: 0.12)
                  : AppTheme.textMuted.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isRunning ? Icons.wifi_rounded : Icons.wifi_off_rounded,
              size: 56,
              color: isRunning ? AppTheme.accent : AppTheme.textMuted,
            ),
          ),
          const SizedBox(height: 20),
          Text(
            isRunning ? 'Server running' : 'Server stopped',
            style: GoogleFonts.dmSans(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: AppTheme.text,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            'Use the same WiFi on this device and your computer. Open the URL in your browser to upload or download files.',
            style: GoogleFonts.dmSans(
              fontSize: 14,
              color: AppTheme.textMuted,
              height: 1.4,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildUrlCard(BuildContext context, WiFiTransferService service) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppTheme.radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surfaceElevated.withValues(alpha: 0.85),
            borderRadius: BorderRadius.circular(AppTheme.radius),
            border: Border.all(color: AppTheme.accent.withValues(alpha: 0.3)),
          ),
          child: SelectableText(
            service.serverUrl!,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 15,
              color: AppTheme.accent,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCopyButton(BuildContext context, WiFiTransferService service) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () {
          Clipboard.setData(ClipboardData(text: service.serverUrl ?? ''));
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('URL copied', style: GoogleFonts.dmSans(fontWeight: FontWeight.w500)),
              behavior: SnackBarBehavior.floating,
            ),
          );
        },
        icon: const Icon(Icons.copy_rounded, size: 20),
        label: const Text('Copy URL'),
        style: FilledButton.styleFrom(
          backgroundColor: AppTheme.accent,
          foregroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 16),
        ),
      ),
    );
  }

  Widget _buildEmulatorNotice(WiFiTransferService service) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline_rounded, color: AppTheme.warning, size: 22),
              const SizedBox(width: 10),
              Text(
                'Android emulator',
                style: GoogleFonts.dmSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.warning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'On your computer, run:',
            style: GoogleFonts.dmSans(fontSize: 13, color: AppTheme.textMuted),
          ),
          const SizedBox(height: 6),
          SelectableText(
            'adb reverse tcp:${service.port} tcp:${service.port}',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppTheme.accent),
          ),
          const SizedBox(height: 4),
          SelectableText(
            'http://127.0.0.1:${service.port}',
            style: GoogleFonts.jetBrainsMono(fontSize: 13, color: AppTheme.accent),
          ),
        ],
      ),
    );
  }

  Widget _buildQrCard(WiFiTransferService service) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: AppTheme.accent.withValues(alpha: 0.25)),
      ),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: QrImageView(
          data: service.serverUrl ?? '',
          version: QrVersions.auto,
          size: 180,
          backgroundColor: Colors.white,
        ),
      ),
    );
  }

  Widget _buildStartStopButton(WiFiTransferService service) {
    final isRunning = service.isRunning;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () async {
          if (isRunning) {
            await service.stopServer();
          } else {
            final ok = await service.startServer();
            if (context.mounted && !ok) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(
                    'Could not start server. Check WiFi and try again.',
                    style: GoogleFonts.dmSans(fontWeight: FontWeight.w500),
                  ),
                  behavior: SnackBarBehavior.floating,
                ),
              );
            }
          }
        },
        icon: Icon(isRunning ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 24),
        label: Text(isRunning ? 'Stop server' : 'Start server'),
        style: FilledButton.styleFrom(
          backgroundColor: isRunning ? AppTheme.warning : AppTheme.accent,
          foregroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(vertical: 18),
          minimumSize: const Size(double.infinity, 56),
        ),
      ),
    );
  }

  Widget _buildProSection(BuildContext context) {
    return Consumer<MonetizationService>(
      builder: (_, monetization, __) {
        if (monetization.isPro) {
          return Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Port: ${monetization.preferredPort}',
                style: GoogleFonts.dmSans(color: AppTheme.textMuted, fontSize: 14),
              ),
              const SizedBox(width: 12),
              TextButton(
                onPressed: () => _showPortDialog(context, monetization),
                child: const Text('Change'),
              ),
            ],
          );
        }
        return TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const ProScreen()),
          ),
          icon: Icon(Icons.workspace_premium_rounded, size: 20, color: AppTheme.accent),
          label: Text(
            'Go Pro – remove ads & unlock more',
            style: GoogleFonts.dmSans(fontWeight: FontWeight.w600, color: AppTheme.accent),
          ),
        );
      },
    );
  }
}
