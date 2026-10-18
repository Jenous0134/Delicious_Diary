import 'package:flutter/material.dart';
import '../core/database/app_database.dart';
import '../features/shell/app_shell.dart';
import 'ui_preview.dart';

ThemeData buildAppTheme() {
  const brown = Color(0xFF7A5638);
  final scheme =
      ColorScheme.fromSeed(
        seedColor: brown,
        surface: const Color(0xFFFFFCF7),
      ).copyWith(
        primary: brown,
        onPrimary: Colors.white,
        onSurface: const Color(0xFF29231F),
        onSurfaceVariant: const Color(0xFF80766D),
        outlineVariant: const Color(0xFFECE5DC),
      );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: const Color(0xFFFFFCF7),
    fontFamilyFallback: const ['Noto Sans KR', 'Malgun Gothic'],
    dividerTheme: const DividerThemeData(
      color: Color(0xFFECE5DC),
      thickness: 1,
      space: 1,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 46),
        side: const BorderSide(color: Color(0xFFE2D8CC)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    ),
    listTileTheme: const ListTileThemeData(
      contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      iconColor: Color(0xFF7A5638),
      titleTextStyle: TextStyle(
        color: Color(0xFF29231F),
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
      subtitleTextStyle: TextStyle(
        color: Color(0xFF80766D),
        fontSize: 12,
        height: 1.6,
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFFFFFCF7),
      surfaceTintColor: Colors.transparent,
      centerTitle: true,
      elevation: 0,
      titleTextStyle: TextStyle(
        color: Color(0xFF211A16),
        fontSize: 17,
        fontWeight: FontWeight.w700,
      ),
    ),
    cardTheme: const CardThemeData(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      color: Colors.white,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        side: BorderSide(color: Color(0xFFECE5DC)),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: Color(0xFFF7F3EE),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE7DED4)),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: Color(0xFFE7DED4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: brown, width: 1.5),
      ),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: Color(0xFFF1E5D8),
      height: 68,
      labelTextStyle: WidgetStatePropertyAll(
        TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
      ),
    ),
    chipTheme: const ChipThemeData(
      backgroundColor: Color(0xFFF5F0EA),
      selectedColor: brown,
      checkmarkColor: Colors.white,
      side: BorderSide.none,
      shape: StadiumBorder(),
      labelStyle: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: brown,
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
        return const AppShell();
      },
    );
  }
}
