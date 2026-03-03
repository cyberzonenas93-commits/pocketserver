import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:provider/provider.dart';
import 'app/theme.dart';
import 'screens/transfer_page.dart';
import 'services/monetization/ad_service.dart';
import 'services/monetization/monetization_service.dart';
import 'services/transfer_storage.dart';
import 'services/wifi_transfer_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await MobileAds.instance.initialize();
  runApp(const WiFiTransferApp());
}

class WiFiTransferApp extends StatelessWidget {
  const WiFiTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    final monetization = MonetizationService();
    final storage = TransferStorage(monetization);
    final transferService = WiFiTransferService(storage, monetization);
    final adService = AdService();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<MonetizationService>.value(value: monetization),
        ChangeNotifierProvider<TransferStorage>.value(value: storage),
        ChangeNotifierProvider<WiFiTransferService>.value(value: transferService),
        Provider<AdService>.value(value: adService),
      ],
      child: MaterialApp(
        title: 'PocketServer',
        theme: AppTheme.darkTheme,
        home: const TransferPage(),
      ),
    );
  }
}
