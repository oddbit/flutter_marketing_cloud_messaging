import Flutter
import UIKit
import UserNotifications
import MarketingCloudSDK

public class SwiftMarketingCloudMessagingPlugin: NSObject, FlutterPlugin {
    #if DEBUG
    let appID = ""
    let accessToken = ""
    let appEndpoint = ""
    let mid = ""
    #else
    let appID = ""
    let accessToken = ""
    let appEndpoint = ""
    let mid = ""
    #endif
    
    let inbox = true
    let location = true
    let pushAnalytics = true
    let piAnalytics = true
    
    private var channel: FlutterMethodChannel?
    
    public static func register(with registrar: FlutterPluginRegistrar) {
        let channel = FlutterMethodChannel(name: "marketing_cloud_messaging", binaryMessenger: registrar.messenger())
        let instance = SwiftMarketingCloudMessagingPlugin(channel: channel)

        registrar.addApplicationDelegate(instance)
        registrar.addMethodCallDelegate(instance, channel: channel)
    }
    
    init(channel: FlutterMethodChannel) {
        self.channel = channel
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        let args = call.arguments
        
        if (call.method == "requestNotificationPermissions") {
            let registeredToMarketingCloud = self.configureMarketingCloudSDK()
            
            if (registeredToMarketingCloud.result) {
                result(FlutterError(code: String(format: "Error %ld", 897),
                                    message: "Failed to register with marketing cloud",
                                    details: registeredToMarketingCloud.msg))
                return
            }
            
            let arguments = args as? Dictionary<String, Any>
            
            if #available(iOS 10.0, *) {
                print("MARKETING_CLOUD: request ios > 10")
                
                var authOptions: UNAuthorizationOptions = []
                let provisional = (arguments?["provisional"] as? Bool) ?? false
                let soundSelected = (arguments?["sound"] as? Bool) ?? false
                let alertSelected = (arguments?["alert"] as? Bool) ?? false
                let badgeSelected = (arguments?["badge"] as? Bool) ?? false
                
                if (soundSelected) {
                    authOptions.insert(.sound)
                }
                if (alertSelected) {
                    authOptions.insert(.alert)
                }
                if (badgeSelected) {
                    authOptions.insert(.badge)
                }

                var isAtLeastVersion12: Bool = false
                if #available(iOS 12, *) {
                    isAtLeastVersion12 = true
                    
                    if (provisional) {
                        authOptions.insert(.provisional)
                    }
                } else {
                    isAtLeastVersion12 = false
                }
                
                let center = UNUserNotificationCenter.current()

                // Set the UNUserNotificationCenterDelegate to a class adhering to this protocol.
                // In this example, the AppDelegate class adheres to the protocol (see below)
                // and handles Notification Center delegate methods from iOS.
                center.delegate = self
                
                center.requestAuthorization(options: authOptions, completionHandler: { granted, error in
                    if error != nil {
                        print("Something went wrong, error found")
                        result(self.getFlutterError(error))
                        
                        return
                    }
                    
                    if !granted {
                        print("Something went wrong, permission not granted")
                        result(self.getFlutterError(error))
                        
                        return
                    } else {
                        let deviceToken = MarketingCloudSDK.sharedInstance().sfmc_deviceToken()

                        if deviceToken == nil {
                            print("error: no token - was UIApplication.shared.registerForRemoteNotifications() called?")
                        } else {
                            let token = deviceToken ?? ""
                            print("success: token - was \(token)")
                        }
                    }

                    // This works for iOS >= 10. See
                    // [UIApplication:didRegisterUserNotificationSettings:notificationSettings]
                    // for ios < 10.
                    UNUserNotificationCenter.current().getNotificationSettings(completionHandler: { settings in
                        let settingsDictionary = [
                            "sound": NSNumber(value: settings.soundSetting == .enabled),
                            "badge": NSNumber(value: settings.badgeSetting == .enabled),
                            "alert": NSNumber(value: settings.alertSetting == .enabled),
                            "provisional": NSNumber(value: granted && provisional && isAtLeastVersion12)
                        ]
                        self.channel?.invokeMethod("onIosSettingsRegistered", arguments: settingsDictionary)
                    })
                    
                    result(NSNumber(value: granted))
                })
                
                UIApplication.shared.registerForRemoteNotifications()
            } else {
                print("MARKETING_CLOUD: request ios < 10")
                var notificationTypes = UIUserNotificationType(rawValue: 0)
                let soundSelected = (arguments?["sound"] as? Bool) ?? false
                let alertSelected = (arguments?["alert"] as? Bool) ?? false
                let badgeSelected = (arguments?["badge"] as? Bool) ?? false
                
                if (soundSelected) {
                    notificationTypes.insert(.sound)
                }
                if (alertSelected) {
                    notificationTypes.insert(.alert)
                }
                if (badgeSelected) {
                    notificationTypes.insert(.badge)
                }
                
                let settings = UIUserNotificationSettings(types: notificationTypes, categories: nil)
                UIApplication.shared.registerUserNotificationSettings(settings)

                UIApplication.shared.registerForRemoteNotifications()
                result(NSNumber(value: true))
            }
        } else {
            result("iOS " + UIDevice.current.systemVersion)
        }
    }
    
    private func getFlutterError(_ error: Error?) -> FlutterError? {
        if error == nil {
            return nil
        }

        //code: String(format: "Error%ld", Int(error?.code ?? 0)),
        return FlutterError(code: String(format: "Error %ld", 899),
                            message: (error as NSError?)?.domain,
                            details: error?.localizedDescription)
    }
    
    private func configureMarketingCloudSDK() -> (result: Bool, msg: String) {
        let builder = MarketingCloudSDKConfigBuilder()

        builder.sfmc_setApplicationId(appID)
        builder.sfmc_setAccessToken(accessToken)
        builder.sfmc_setMarketingCloudServerUrl(appEndpoint)
        builder.sfmc_setMid(mid)
        builder.sfmc_setInboxEnabled(NSNumber(value: inbox))
        builder.sfmc_setLocationEnabled(NSNumber(value: location))
        builder.sfmc_setAnalyticsEnabled(NSNumber(value: pushAnalytics))

        var result = false
        var msg = ""
        
        // Once you've created the builder, pass it to the sfmc_configure method.
        do {
            try MarketingCloudSDK.sharedInstance().sfmc_configure(with: builder.sfmc_build()!)
            result = true
        } catch let error as NSError {
            // Errors returned from configuration will be in the NSError parameter and can be used to determine
            // if you've implemented the SDK correctly.
            msg = String(format: "MarketingCloudSDK sfmc_configure failed with error = %@", error)
            print(msg)
        }
        
        #if DEBUG
        MarketingCloudSDK.sharedInstance().sfmc_setDebugLoggingEnabled(true)
        #endif
        
        return (result, msg)
    }
    
    // MARK: - app delegate
    public func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        MarketingCloudSDK.sharedInstance().sfmc_setDeviceToken(deviceToken)
    }
    
    public func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("\(error.localizedDescription)")
    }
    
    // MobilePush SDK: REQUIRED IMPLEMENTATION
    /** This delegate method offers an opportunity for applications with the "remote-notification" background mode to fetch appropriate new data in response to an incoming remote notification. You should call the fetchCompletionHandler as soon as you're finished performing that operation, so the system can accurately estimate its power and data cost.
    This method will be invoked even if the application was launched or resumed because of the remote notification. The respective delegate methods will be invoked first. Note that this behavior is in contrast to application:didReceiveRemoteNotification:, which is not called in those cases, and which will not be invoked if this method is implemented. **/
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        MarketingCloudSDK.sharedInstance().sfmc_setNotificationUserInfo(userInfo)

        for key in userInfo.keys {
            guard let key = key as? String else {
                continue
            }
            if let object = userInfo[key] {
                print("property value: \(object)")
            }
        }
    }
    
    // MobilePush SDK: REQUIRED IMPLEMENTATION
    /** The method will be called on the delegate when the user responded to the notification by opening the application, dismissing the notification or choosing a UNNotificationAction. The delegate must be set before the application returns from applicationDidFinishLaunching:.**/
    @available(iOS 10, *)
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void) {
        MarketingCloudSDK.sharedInstance().sfmc_setNotificationRequest(response.notification.request)
        completionHandler()
    }

    // MobilePush SDK: REQUIRED IMPLEMENTATION
    /** The method will be called on the delegate only if the application is in the foreground. If the method is not implemented or the handler is not called in a timely manner then the notification will not be presented. The application can choose to have the notification presented as a sound, badge, alert and/or in the notification list. This decision should be based on whether the information in the notification is otherwise visible to the user.**/
    @available(iOS 10, *)
    public func userNotificationCenter(_ center: UNUserNotificationCenter,
        willPresent notification:UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler(UNNotificationPresentationOptions.alert)
    }
}