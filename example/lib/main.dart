import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:marketing_cloud_messaging/marketing_cloud_messaging.dart';

void main() => runApp(MyApp());

Future<dynamic> _myBackgroundMessageHandler(Map<String, dynamic> message) {
  if (message.containsKey('data')) {
    // Handle data message
    final dynamic data = message['data'];

    return Future.value(data);
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];

    return Future.value(notification);
  }

  // Or do other work.
  return Future.value(null);
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  MarketingCloudMessaging marketingCloudMessaging = MarketingCloudMessaging();

  @override
  void initState() {
    super.initState();
    initPlatformState();
  }

  // Platform messages are asynchronous, so we initialize in an async method.
  Future<void> initPlatformState() async {
    // Platform messages may fail, so we use a try/catch PlatformException.
    try {
      bool permitted = await marketingCloudMessaging.requestNotificationPermissions();

      if (permitted) {
        marketingCloudMessaging.configure(
          onMessage: (Map<String, dynamic> message) async {
            print("onMessage: $message");
          },
          onLaunch: (Map<String, dynamic> message) async {
            print("onLaunch: $message");
          },
          onResume: (Map<String, dynamic> message) async {
            print("onResume: $message");
          },
        );
      }
    } on PlatformException {
      print('Platform exception occurred');
    }

    // If the widget was removed from the tree while the asynchronous platform
    // message was in flight, we want to discard the reply rather than calling
    // setState to update our non-existent appearance.
    if (!mounted) return;

    setState(() {

    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Marketing cloud plugin example app'),
        ),
        body: Center(
          child: Text('Marketing cloud plugin example'),
        ),
      ),
    );
  }
}
