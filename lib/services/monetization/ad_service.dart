import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// POLICY SAFE: No disruptive ads. Banner only, no interstitials.
/// Banner is shown only when not Pro, not receiving, not upload complete.
class AdService {
  static const String androidBannerUnitId = 'ca-app-pub-3940256099942544/6300978111';
  static const String iosBannerUnitId = 'ca-app-pub-3940256099942544/2934735716';

  /// Returns an adaptive banner widget. Caller must hide when isPro or isReceiving or showUploadComplete.
  /// Never blocks UI if ad fails to load.
  Widget getBanner() {
    return const _BannerAdWidget();
  }
}

class _BannerAdWidget extends StatefulWidget {
  const _BannerAdWidget();

  @override
  State<_BannerAdWidget> createState() => _BannerAdWidgetState();
}

class _BannerAdWidgetState extends State<_BannerAdWidget> {
  BannerAd? _bannerAd;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadAd();
  }

  void _loadAd() {
    final unitId = Platform.isIOS ? AdService.iosBannerUnitId : AdService.androidBannerUnitId;
    _bannerAd = BannerAd(
      adUnitId: unitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          if (mounted) setState(() => _loaded = true);
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {},
      ),
    )..load();
  }

  @override
  Widget build(BuildContext context) {
    if (_loaded && _bannerAd != null) {
      return SizedBox(
        height: _bannerAd!.size.height.toDouble(),
        width: double.infinity,
        child: AdWidget(ad: _bannerAd!),
      );
    }
    return const SizedBox(height: 50);
  }
}
