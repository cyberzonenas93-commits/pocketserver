import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app/theme.dart';
import 'screens/transfer_page.dart';
import 'services/transfer_storage.dart';
import 'services/wifi_transfer_service.dart';

void main() {
  runApp(const WiFiTransferApp());
}

class WiFiTransferApp extends StatelessWidget {
  const WiFiTransferApp({super.key});

  @override
  Widget build(BuildContext context) {
    final storage = TransferStorage();
    final transferService = WiFiTransferService(storage);

    return MaterialApp(
      title: 'PocketServer',
      theme: AppTheme.darkTheme,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider<TransferStorage>.value(value: storage),
          ChangeNotifierProvider<WiFiTransferService>.value(value: transferService),
        ],
        child: const TransferPage(),
      ),
    );
  }
}
