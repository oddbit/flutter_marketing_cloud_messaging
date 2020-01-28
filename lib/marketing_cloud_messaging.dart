import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:meta/meta.dart';
import 'package:platform/platform.dart';

typedef Future<dynamic> MessageHandler(Map<String, dynamic> message);

/// Setup method channel to handle Marketing Cloud Messages received while
/// the Flutter app is not active. The handle for this method is generated
/// and passed to the Android side so that the background isolate knows where
/// to send background messages for processing.
///
/// Your app should never call this method directly, this is only for use
/// by the marketing_cloud_messaging plugin to setup background message
/// handling.
void _mcSetupBackgroundChannel({
  MethodChannel backgroundChannel = const MethodChannel('marketing_cloud_messaging_background')
}) async {
  // Setup Flutter state needed for MethodChannels.
  WidgetsFlutterBinding.ensureInitialized();

  // This is where the magic happens and we handle background events from the
  // native portion of the plugin.
  backgroundChannel.setMethodCallHandler((MethodCall call) async {
    if (call.method == 'handleBackgroundMessage') {
      final CallbackHandle handle = CallbackHandle.fromRawHandle(call.arguments['handle']);
      final Function handlerFunction = PluginUtilities.getCallbackFromHandle(handle);

      try {
        await handlerFunction(Map<String, dynamic>.from(call.arguments['message']));
      } catch (e) {
        print('Unable to handle incoming background message.');
        print(e);
      }
      return Future<void>.value();
    }
  });

  // Once we've finished initializing, let the native portion of the plugin
  // know that it can start scheduling handling messages.
  backgroundChannel.invokeMethod<void>('McDartService#initialized');
}

/// Implementation of the Marketing Cloud Messaging API for Flutter.
/// Taken from Firebase Messaging plugin for Flutter
///
/// Your app should call [requestNotificationPermissions] first and then
/// register handlers for incoming messages with [configure].
class MarketingCloudMessaging {
  final MethodChannel _channel;
  final Platform _platform;

  MessageHandler _onMessage;
  MessageHandler _onBackgroundMessage;
  MessageHandler _onLaunch;
  MessageHandler _onResume;

  final StreamController<IosNotificationSettings> _iosSettingsStreamController =
    StreamController<IosNotificationSettings>.broadcast();

  factory MarketingCloudMessaging() => _instance;

  @visibleForTesting
  MarketingCloudMessaging.private(MethodChannel channel, Platform platform)
      : _channel = channel,
        _platform = platform;

  static final MarketingCloudMessaging _instance = MarketingCloudMessaging.private(
      const MethodChannel('marketing_cloud_messaging'),
      const LocalPlatform());

  /// On iOS, prompts the user for notification permissions the first time
  /// it is called.
  ///
  /// Does nothing and returns null on Android.
  FutureOr<bool> requestNotificationPermissions([
    IosNotificationSettings iosSettings = const IosNotificationSettings(),
  ]) {
    if (!_platform.isIOS) {
      return null;
    }
    return _channel.invokeMethod<bool>(
      'requestNotificationPermissions',
      iosSettings.toMap(),
    );
  }

  /// Stream that fires when the user changes their notification settings.
  ///
  /// Only fires on iOS.
  Stream<IosNotificationSettings> get onIosSettingsRegistered {
    return _iosSettingsStreamController.stream;
  }

  /// Sets up [MessageHandler] for incoming messages.
  void configure({
    MessageHandler onMessage,
    MessageHandler onBackgroundMessage,
    MessageHandler onLaunch,
    MessageHandler onResume,
  }) {
    _onMessage = onMessage;
    _onLaunch = onLaunch;
    _onResume = onResume;
    _channel.setMethodCallHandler(_handleMethod);
    _channel.invokeMethod<void>('configure');

    if (onBackgroundMessage != null) {
      _onBackgroundMessage = onBackgroundMessage;
      final CallbackHandle backgroundSetupHandle = PluginUtilities.getCallbackHandle(_mcSetupBackgroundChannel);
      final CallbackHandle backgroundMessageHandle = PluginUtilities.getCallbackHandle(_onBackgroundMessage);

      if (backgroundMessageHandle == null) {
        throw ArgumentError(
          '''Failed to setup background message handler! `onBackgroundMessage`
          should be a TOP-LEVEL OR STATIC FUNCTION and should NOT be tied to a
          class or an anonymous function.''',
        );
      }

      _channel.invokeMethod<bool>(
        'McDartService#start',
        <String, dynamic>{
          'setupHandle': backgroundSetupHandle.toRawHandle(),
          'backgroundHandle': backgroundMessageHandle.toRawHandle()
        },
      );
    }
  }

  final StreamController<String> _tokenStreamController = StreamController<String>.broadcast();

  /// Fires when a new token is generated.
  Stream<String> get onTokenRefresh {
    return _tokenStreamController.stream;
  }

  /// Returns the token.
  Future<String> getToken() async {
    return await _channel.invokeMethod<String>('getToken');
  }

  Future<dynamic> _handleMethod(MethodCall call) async {
    switch (call.method) {
      case "onToken":
        final String token = call.arguments;
        _tokenStreamController.add(token);
        return null;
      case "onIosSettingsRegistered":
        _iosSettingsStreamController.add(
            IosNotificationSettings._fromMap(call.arguments.cast<String, bool>())
        );
        return null;
      case "onMessage":
        return _onMessage(call.arguments.cast<String, dynamic>());
      case "onLaunch":
        return _onLaunch(call.arguments.cast<String, dynamic>());
      case "onResume":
        return _onResume(call.arguments.cast<String, dynamic>());
      default:
        throw UnsupportedError("Unrecognized JSON message");
    }
  }
}

class IosNotificationSettings {
  const IosNotificationSettings({
    this.sound = true,
    this.alert = true,
    this.badge = true,
    this.provisional = false,
  });

  IosNotificationSettings._fromMap(Map<String, bool> settings)
      : sound = settings['sound'],
        alert = settings['alert'],
        badge = settings['badge'],
        provisional = settings['provisional'];

  final bool sound;
  final bool alert;
  final bool badge;
  final bool provisional;

  @visibleForTesting
  Map<String, dynamic> toMap() {
    return <String, bool>{
      'sound': sound,
      'alert': alert,
      'badge': badge,
      'provisional': provisional
    };
  }

  @override
  String toString() => 'PushNotificationSettings ${toMap()}';
}
