
@protocol PSHEventBusDelegate <NSObject>

@optional

/**
 *  This method is called when the app is successfully authenticated with the PushTech platform.
 *
 */
- (void)onSuccessfulAppRegistrationBusEvent:(NSNotification *)notification;

/**
 *  This method is called when the PushTech platform gives an identifier to the device.
 *  This identifier can be used to send notifications to the app via the public API of the 
 *  PushTech platform.
 *  Use this property to know which identifier has been given to the app:
 *  [PSHEngine sharedInstance].deviceId
 *
 */
- (void)onSuccessfulDeviceIdBusEvent:(NSNotification *)notification;

/**
 *  The version of the SDK can be accessed through this property:
 *  [PSHModel sharedInstance].managerInfo.currentSDKVersion
 *
 */
- (void)onSDKVersionDowngradedBusEvent:(NSNotification *)notification;

/**
 *  The version of the SDK can be accessed through this property:
 *  [PSHModel sharedInstance].managerInfo.currentSDKVersion
 *
 */
- (void)onSDKVersionUpgradedBusEvent:(NSNotification *)notification;

/**
 *  This method is called when the app is successfully regisytered with the APNS server.
 *  The apple device token can be accessed by this property:
 *  [PSHModel sharedInstance].managerInfo.pushToken
 *
 */
- (void)onDidRegisterForRemoteNotificationsBusEvent:(NSNotification *)notification;

/**
 *  This method is called when the app fails to register with the APNS server
 *
 */
- (void)onDidFailToRegisterForRemoteNotificationsBusEvent:(NSNotification *)notification;

@end