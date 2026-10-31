import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:insurance_helper/services/schedule_reminder_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ScheduleReminderService Unit Tests', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    test('1. Default values are disabled and 07:00', () async {
      final service = ScheduleReminderService.instance;
      await service.loadSettings();

      expect(service.isEnabled, isFalse);
      expect(service.reminderTime, equals('07:00'));
      expect(service.reminderTimeLabel, contains('07:00'));
    });

    test('2. Label mapping for all valid time options', () {
      for (final option in ScheduleReminderService.timeOptions) {
        expect(option['value'], isNotNull);
        expect(option['label'], isNotNull);
      }
    });

    test('3. Save and load persistence via SharedPreferences', () async {
      final service = ScheduleReminderService.instance;
      await service.saveSettings(isEnabled: true, reminderTime: '20:00');

      expect(service.isEnabled, isTrue);
      expect(service.reminderTime, equals('20:00'));
      expect(service.reminderTimeLabel, contains('20:00'));

      // Re-load to ensure SharedPreferences retains state
      await service.loadSettings();
      expect(service.isEnabled, isTrue);
      expect(service.reminderTime, equals('20:00'));
    });
  });
}
