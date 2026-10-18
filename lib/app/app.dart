import 'package:flutter/material.dart';
import '../core/database/app_database.dart';
import '../features/shell/modern_app_shell.dart';
import 'ui_preview.dart';

ThemeData buildAppTheme() {
  const orange = Color(0xFFFF6B2C);
  final scheme = ColorScheme.fromSeed(seedColor: orange, surface: Colors.white)
      .copyWith(
        primary: orange,
        onPrimary: Colors.white,
        onSurface: const Color(0xFF171717),
        onSurfaceVariant: const Color(0xFF737373),
        outlineVariant: const Color(0xFFECECEC),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: Colors.white,
    fontFamilyFallback: const ['Noto Sans KR', 'Malgun Gothic'],
    dividerTheme: const DividerThemeData(
      color: Color(0xFFECECEC),
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        side: const BorderSide(color: Color(0xFFDDDDDD)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      iconColor: Color(0xFFFF6B2C),
      titleTextStyle: TextStyle(
        color: Color(0xFF171717),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: TextStyle(
        color: Color(0xFF737373),
        fontSize: 12,
        height: 1.6,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF171717),
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    ),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(14)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF5F5F5),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE5E5E5)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE5E5E5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: orange, width: 1.5),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFFFE8DE),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFFF4F4F4),
      selectedColor: orange,
      checkmarkColor: Colors.white,
      side: BorderSide.none,
      shape: StadiumBorder(),
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: orange,
      foregroundColor: Colors.white,
      shape: CircleBorder(),
      elevation: 3,
    ),
  );
}

class AppBootstrap extends StatefulWidget {
  const AppBootstrap({super.key});
  @override
  State<AppBootstrap> createState() => _AppBootstrapState();
}

class _AppBootstrapState extends State<AppBootstrap> {
  static const _uiPreview = bool.fromEnvironment('UI_PREVIEW');
  late final Future<void> _initialization = AppDatabase.instance.database.then(
    (_) {},
  );
  @override
  Widget build(BuildContext context) {
    if (_uiPreview) {
      return const UiPreview();
    }
    return FutureBuilder<void>(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Scaffold(body: Center(child: Text('앱을 시작하지 못했습니다.')));
        }
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Image(
                    image: AssetImage('assets/branding/logo.png'),
                    width: 132,
                    height: 132,
                    fit: BoxFit.contain,
                  ),
                  SizedBox(height: 12),
                ],
              ),
            ),
          );
        }
        return const ModernAppShell();
      },
    );
  }
}
