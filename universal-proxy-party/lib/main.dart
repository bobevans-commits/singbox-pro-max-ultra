import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/managers/kernel_manager.dart';
import 'ui/screens/home_screen.dart';
import 'utils/logger.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize logging
  AppLogger.init();
  
  runApp(const UniversalProxyPartyApp());
}

class UniversalProxyPartyApp extends StatelessWidget {
  const UniversalProxyPartyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // Kernel Manager - handles all kernel operations
        ChangeNotifierProvider(create: (_) => KernelManager()),
        
        // TODO: Add more providers as needed
        // ChangeNotifierProvider(create: (_) => ConfigManager()),
        // ChangeNotifierProvider(create: (_) => ConnectionManager()),
      ],
      child: MaterialApp(
        title: 'Universal Proxy Party',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.light,
          ),
          useMaterial3: true,
        ),
        darkTheme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: Colors.blue,
            brightness: Brightness.dark,
          ),
          useMaterial3: true,
        ),
        themeMode: ThemeMode.system,
        home: const HomeScreen(),
      ),
    );
  }
}
