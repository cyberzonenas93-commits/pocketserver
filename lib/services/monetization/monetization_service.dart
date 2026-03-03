import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String _entitlementKey = 'pro_access';
const String _monthlyProductId = 'pocketserver_pro_monthly';
const String _yearlyProductId = 'pocketserver_pro_yearly';
const String _preferredPortKey = 'pro_preferred_port';

/// Handles in-app subscription state and persistence.
/// Persists entitlement locally for offline access; refreshes from store when available.
class MonetizationService extends ChangeNotifier {
  MonetizationService() {
    _loadCachedEntitlement();
    _initStore();
  }

  final InAppPurchase _iap = InAppPurchase.instance;
  StreamSubscription<List<PurchaseDetails>>? _subscription;
  SharedPreferences? _prefs;
  bool _isPro = false;
  bool _isLoading = false;
  ProductDetails? _monthlyProduct;
  ProductDetails? _yearlyProduct;
  bool _productsLoaded = false;

  static const int defaultPort = 8080;
  int _preferredPort = defaultPort;

  bool get isPro => _isPro;
  bool get isLoading => _isLoading;
  ProductDetails? get monthlyProduct => _monthlyProduct;
  ProductDetails? get yearlyProduct => _yearlyProduct;
  bool get productsLoaded => _productsLoaded;
  int get preferredPort => _preferredPort;

  Future<void> _loadCachedEntitlement() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      _isPro = _prefs!.getBool(_entitlementKey) ?? false;
      _preferredPort = _prefs!.getInt(_preferredPortKey) ?? defaultPort;
      notifyListeners();
    } catch (e) {
      debugPrint('[Monetization] Load cache: $e');
    }
  }

  Future<void> _persistPro(bool value) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setBool(_entitlementKey, value);
      _isPro = value;
      notifyListeners();
    } catch (e) {
      debugPrint('[Monetization] Persist: $e');
    }
  }

  Future<void> setPreferredPort(int port) async {
    if (port < 1024 || port > 65535) return;
    try {
      _prefs ??= await SharedPreferences.getInstance();
      await _prefs!.setInt(_preferredPortKey, port);
      _preferredPort = port;
      notifyListeners();
    } catch (e) {
      debugPrint('[Monetization] setPreferredPort: $e');
    }
  }

  Future<void> _initStore() async {
    final available = await _iap.isAvailable();
    if (!available) {
      debugPrint('[Monetization] IAP not available');
      _productsLoaded = true;
      notifyListeners();
      return;
    }
    _subscription = _iap.purchaseStream.listen(
      _onPurchaseUpdates,
      onDone: () => _subscription?.cancel(),
      onError: (e) => debugPrint('[Monetization] purchaseStream: $e'),
    );
    await loadProducts();
  }

  Future<void> loadProducts() async {
    _isLoading = true;
    notifyListeners();
    try {
      final response = await _iap.queryProductDetails({_monthlyProductId, _yearlyProductId});
      if (response.notFoundIDs.isNotEmpty) {
        debugPrint('[Monetization] Not found: ${response.notFoundIDs}');
      }
      for (final p in response.productDetails) {
        if (p.id == _monthlyProductId) _monthlyProduct = p;
        if (p.id == _yearlyProductId) _yearlyProduct = p;
      }
      _productsLoaded = true;
    } catch (e) {
      debugPrint('[Monetization] loadProducts: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onPurchaseUpdates(List<PurchaseDetails> purchases) {
    for (final purchase in purchases) {
      if (purchase.status == PurchaseStatus.purchased ||
          purchase.status == PurchaseStatus.restored) {
        _verifyAndUnlock();
      }
    }
  }

  Future<void> _verifyAndUnlock() async {
    await _persistPro(true);
  }

  Future<void> buyMonthly() async {
    if (_monthlyProduct == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _monthlyProduct!),
      );
    } catch (e) {
      debugPrint('[Monetization] buyMonthly: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> buyYearly() async {
    if (_yearlyProduct == null) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _iap.buyNonConsumable(
        purchaseParam: PurchaseParam(productDetails: _yearlyProduct!),
      );
    } catch (e) {
      debugPrint('[Monetization] buyYearly: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> restorePurchases() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _iap.restorePurchases();
      await _loadCachedEntitlement();
    } catch (e) {
      debugPrint('[Monetization] restore: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
