import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart' show TestWidgetsFlutterBinding;
import 'package:platform/platform.dart';
import 'package:mockito/mockito.dart';
import 'package:test/test.dart';

import 'package:marketing_cloud_messaging/marketing_cloud_messaging.dart';

void main() {
  MockMethodChannel mockChannel;
  MarketingCloudMessaging marketingCloudMessaging;
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    mockChannel = MockMethodChannel();
    marketingCloudMessaging = MarketingCloudMessaging.private(mockChannel, FakePlatform(operatingSystem: 'ios'));
  });

  tearDown(() {
    mockChannel.setMockMethodCallHandler(null);
  });

  test('requestNotificationPermissions on ios with default permissions', () {
    marketingCloudMessaging.requestNotificationPermissions();
    verify(mockChannel.invokeMethod<void>(
        'requestNotificationPermissions', <String, bool>{
      'sound': true,
      'badge': true,
      'alert': true,
      'provisional': false
    }));
  });

  test('requestNotificationPermissions on ios with custom permissions', () {
    marketingCloudMessaging.requestNotificationPermissions(
        const IosNotificationSettings(sound: false, provisional: true));
    verify(mockChannel.invokeMethod<void>(
        'requestNotificationPermissions', <String, bool>{
      'sound': false,
      'badge': true,
      'alert': true,
      'provisional': true
    }));
  });

  test('requestNotificationPermissions on android', () {
    marketingCloudMessaging = MarketingCloudMessaging.private(
        mockChannel, FakePlatform(operatingSystem: 'android'));

    marketingCloudMessaging .requestNotificationPermissions();
    verifyZeroInteractions(mockChannel);
  });

  test('requestNotificationPermissions on android', () {
    marketingCloudMessaging = MarketingCloudMessaging.private(
        mockChannel, FakePlatform(operatingSystem: 'android'));

    marketingCloudMessaging .requestNotificationPermissions();
    verifyZeroInteractions(mockChannel);
  });

  test('configure', () {
    marketingCloudMessaging .configure();
    verify(mockChannel.setMethodCallHandler(any));
    verify(mockChannel.invokeMethod<void>('configure'));
  });

  test('incoming token', () async {
    marketingCloudMessaging.configure();

    final dynamic handler = verify(mockChannel.setMethodCallHandler(captureAny)).captured.single;
    final String token1 = 'I am a super secret token';
    final String token2 = 'I am the new token in town';

    Future<String> tokenFromStream = marketingCloudMessaging.onTokenRefresh.first;
    await handler(MethodCall('onToken', token1));

    expect(await tokenFromStream, token1);

    tokenFromStream = marketingCloudMessaging.onTokenRefresh.first;
    await handler(MethodCall('onToken', token2));

    expect(await tokenFromStream, token2);
  });

  test('incoming iOS settings', () async {
    marketingCloudMessaging.configure();

    final dynamic handler = verify(mockChannel.setMethodCallHandler(captureAny)).captured.single;

    IosNotificationSettings iosSettings = const IosNotificationSettings();

    Future<IosNotificationSettings> iosSettingsFromStream = marketingCloudMessaging.onIosSettingsRegistered.first;
    await handler(MethodCall('onIosSettingsRegistered', iosSettings.toMap()));
    expect((await iosSettingsFromStream).toMap(), iosSettings.toMap());

    iosSettings = const IosNotificationSettings(sound: false);
    iosSettingsFromStream = marketingCloudMessaging.onIosSettingsRegistered.first;
    await handler(MethodCall('onIosSettingsRegistered', iosSettings.toMap()));
    expect((await iosSettingsFromStream).toMap(), iosSettings.toMap());
  });

  test('incoming messages', () async {
    final Completer<dynamic> onMessage = Completer<dynamic>();
    final Completer<dynamic> onLaunch = Completer<dynamic>();
    final Completer<dynamic> onResume = Completer<dynamic>();

    marketingCloudMessaging.configure(
      onMessage: (dynamic m) async {
        onMessage.complete(m);
      },
      onLaunch: (dynamic m) async {
        onLaunch.complete(m);
      },
      onResume: (dynamic m) async {
        onResume.complete(m);
      },
      onBackgroundMessage: validOnBackgroundMessage,
    );
    final dynamic handler = verify(mockChannel.setMethodCallHandler(captureAny)).captured.single;

    final Map<String, dynamic> onMessageMessage = <String, dynamic>{};
    final Map<String, dynamic> onLaunchMessage = <String, dynamic>{};
    final Map<String, dynamic> onResumeMessage = <String, dynamic>{};

    await handler(MethodCall('onMessage', onMessageMessage));
    expect(await onMessage.future, onMessageMessage);
    expect(onLaunch.isCompleted, isFalse);
    expect(onResume.isCompleted, isFalse);

    await handler(MethodCall('onLaunch', onLaunchMessage));
    expect(await onLaunch.future, onLaunchMessage);
    expect(onResume.isCompleted, isFalse);

    await handler(MethodCall('onResume', onResumeMessage));
    expect(await onResume.future, onResumeMessage);
  });

  test('getToken', () {
    marketingCloudMessaging.getToken();
    verify(mockChannel.invokeMethod<String>('getToken'));
  });
}

Future<dynamic> validOnBackgroundMessage(Map<String, dynamic> message) async {}

class MockMethodChannel extends Mock implements MethodChannel {}