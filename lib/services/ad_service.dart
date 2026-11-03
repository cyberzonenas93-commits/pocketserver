// //// AdMob Integration
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// POLICY SAFE: Banner only. Never in web UI. Never during receiving or upload complete.
/// Manages a single banner ad; fails gracefully if load fails.
class AdService extends ChangeNotifier {
  // //// AdMob Integration

  static const String _androidTestBannerId = 'ca-app-pub-3940256099942544/6300978111';
  static const String _iosTestBannerId = 'ca-app-pub-3940256099942544/2934735716';

  BannerAd? bannerAd;
  bool isLoaded = false;

  AdService() {
    _loadBanner();
  }

  void _loadBanner() {
    final adUnitId = Platform.isAndroid ? _androidTestBannerId : _iosTestBannerId;
    bannerAd = BannerAd(
      adUnitId: adUnitId,
      size: AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (Ad ad) {
          isLoaded = true;
          notifyListeners();
        },
        onAdFailedToLoad: (Ad ad, LoadAdError error) {
          ad.dispose();
          bannerAd = null;
          isLoaded = false;
          notifyListeners();
        },
      ),
    )..load();
  }

  /// Returns banner widget with correct height when loaded; otherwise empty.
  /// Caller must hide during receiving and upload-complete (policy).
  Widget buildBanner() {
    if (!isLoaded || bannerAd == null) {
      return const SizedBox.shrink();
    }
    final height = bannerAd!.size.height.toDouble();
    return SizedBox(
      height: height,
      width: double.infinity,
      child: AdWidget(ad: bannerAd!),
    );
  }

  @override
  void dispose() {
    bannerAd?.dispose();
    bannerAd = null;
    isLoaded = false;
    super.dispose();
  }
}
