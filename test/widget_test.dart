import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hankki_diary/app/app.dart';

void main() {
  test('theme uses Material 3 and warm background', () {
    final theme = buildAppTheme();
    expect(theme.useMaterial3, isTrue);
    expect(theme.scaffoldBackgroundColor, const Color(0xFFFFFCF7));
  });
}
