import 'package:flutter_local_notifications/flutter_local_notifications.dart';

class LocalNotificationService {
  LocalNotificationService._();

  static final instance = LocalNotificationService._();

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  static const _androidChannel = AndroidNotificationChannel(
    'civiq_alerts_default_v1',
    'CIVIQ Alerts',
    description: 'Important CIVIQ Africa account and civic updates.',
    importance: Importance.high,
    playSound: true,
  );

  static const _silentAndroidChannel = AndroidNotificationChannel(
    'civiq_alerts_silent_v1',
    'CIVIQ Alerts Silent',
    description: 'CIVIQ Africa alerts without sound.',
    importance: Importance.high,
    playSound: false,
  );

  Future<void> initialize() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );
    const darwinSettings = DarwinInitializationSettings();
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open',
    );
    const windowsSettings = WindowsInitializationSettings(
      appName: 'CIVIQ Africa',
      appUserModelId: 'CIVIQAfrica.App',
      guid: '77fbc89c-e997-4d89-9e7d-8bd224dc4964',
    );

    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
        macOS: darwinSettings,
        linux: linuxSettings,
        windows: windowsSettings,
      ),
    );

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_androidChannel);
    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_silentAndroidChannel);
  }

  Future<bool> requestPermission() async {
    final androidAllowed = await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    final iosAllowed = await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    final macAllowed = await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);

    return androidAllowed ?? iosAllowed ?? macAllowed ?? true;
  }

  Future<void> show({
    required int id,
    required String title,
    required String body,
    String sound = 'default',
  }) async {
    final silent = sound == 'silent';
    final channelId = silent
        ? 'civiq_alerts_silent_v1'
        : 'civiq_alerts_default_v1';
    final channelName = silent ? 'CIVIQ Alerts Silent' : 'CIVIQ Alerts';
    await _plugin.show(
      id: id,
      title: title,
      body: body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          channelName,
          channelDescription:
              'Important CIVIQ Africa account and civic updates.',
          importance: Importance.high,
          priority: Priority.high,
          playSound: !silent,
          enableVibration: true,
        ),
        iOS: DarwinNotificationDetails(presentSound: !silent),
        macOS: DarwinNotificationDetails(presentSound: !silent),
      ),
    );
  }
}
