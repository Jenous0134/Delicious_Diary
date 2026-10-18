import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hankki_diary/app/app.dart';

void main() {
  test('theme uses Material 3 and a photo-first neutral background', () {
    final theme = buildAppTheme();
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, Colors.white);
    expect(theme.colorScheme.primary, const Color(0xFFFF6B2C));
  });
}
