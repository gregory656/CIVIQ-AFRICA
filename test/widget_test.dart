import 'package:civiqafrica/core/constants/app_colors.dart';
import 'package:civiqafrica/core/theme/app_theme.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('CIVIQ theme uses the deep green primary color', () {
    expect(AppTheme.light.colorScheme.primary, AppColors.primaryGreen);
  });
}
