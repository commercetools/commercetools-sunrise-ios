
#import <UIKit/UIKit.h>

@protocol PSHNotificationDelegate, PSHEventBusDelegate;

@class PSHConfiguration, PSHCampaignDAO, PSHCustomDAO;

/**
 *  Asynchronously executed block triggered after an API call.
 *
 *  @param `NSError` An error if the operation fails; otherwise (success), `nil`
 */
typedef void(^PSHAsyncSimpleBlock)(NSError*);

/**
 *  Asynchronous callback block to be used on `handleRemotePushWithUserInfo:completion:`.
 *
 *  @param BOOL            `YES` if the notification is a valid push; `NO` otherwise.
 *  @param id               Push info object, or `nil` if any error happens or the notification didn't contain any push related info.
 *  @param NSError        An error if the operation fails; otherwise (success), `nil`.
 */
typedef void(^PSHHandleRemotePushAsyncBlock)(BOOL, id, NSError*);

/**
 *  Asynchronous callback block to be used on `handleRemotePushWithUserInfo:completionCustom:completionCampaign:completionOther:`.
 *
 *  @param BOOL            `YES` if the notification did contain any NEW campaign related info; `NO` otherwise.
 *  @param PSHCampaignDAO Campaign info object, or `nil` if any error happens or the notification didn't contain any campaign related info.
 *  @param NSError        An error if the operation fails; otherwise (success), `nil`.
 */
typedef void(^PSHHandleRemotePushCampaignAsyncBlock)(BOOL, PSHCampaignDAO*);

/**
 *  Asynchronous callback block to be used on `handleRemotePushWithUserInfo:completionCustom:completionCampaign:completionOther:`.
 *
 *  @param BOOL            `YES` if the notification is a valid custom push; `NO` otherwise.
 *  @param PSHCustomDAO    Custom info object, or `nil` if any error happens or the notification didn't contain any custom related info.
 *  @param NSError         An error if the operation fails; otherwise (success), `nil`.
 */
typedef void(^PSHHandleRemotePushCustomAsyncBlock)(BOOL, PSHCustomDAO*);

/**
 *  Asynchronous callback block to be used on `handleRemotePushWithUserInfo:completionCustom:completionCampaign:completionOther:`.
 *
 *  @param NSDictionary    Push dictionary (userInfo)
 */
typedef void(^PSHHandleRemotePushOtherAsyncBlock)(NSDictionary *);

/**
 *  Asynchronous callback block to be used on `handleRemotePushWithUserInfo:completionCustom:completionCampaign:completionOther:`.
 *
 *  @param NSError         Error.
 */
typedef void(^PSHHandleRemotePushFailAsyncBlock)(NSError *);

/**
 *  TL;DR if the value of error is nil, you're good to go. Otherwise check the "localizedDescription" parameter.
 *
 *  Asynchronous callback to handle the completion of network request operations.
 *
 *  @param NSError  In an error happens this will contain a description of the error occured in the "localizedDescription", otherwise the value will be nil.
 *  @param id       If there's an asociated object with the response, this property will contain the specific object, otherwise it will be nil.
 */
typedef void(^PSHCompletionBlock)(NSError *error, id obj);


/**
 *  Defined type to configure the SDK logging level.
 */
typedef NS_ENUM(NSInteger, PSHLogLevel) {
    /**
     *  Logging is OFF
     */
    PSHLogLevelNone = 0,
    /**
     *  Standard log level ALERT
     */
    PSHLogLevelAlert,
    /**
     *  Standard log level CRITICAL
     */
    PSHLogLevelCritical,
    /**
     *  Standard log level ERROR
     */
    PSHLogLevelError,
    /**
     *  Standard log level WARNING
     */
    PSHLogLevelWarning,
    /**
     *  Standard log level NOTICE
     */
    PSHLogLevelNotice,
    /**
     *  Standard log level INFO
     */
    PSHLogLevelInfo,
    /**
     *  Standard log level DEBUG (DEFAULT)
     */
    PSHLogLevelDebug
};

/**
 *  Notification types to use instead of apple's, for an easier setup supporting different iOS SDK versions.
 */
typedef NS_OPTIONS(NSInteger, PSHNotificationType){
    /**
     *
     */
    PSHNotificationTypeNone  = 0,
    /**
     *
     */
    PSHNotificationTypeBadge = 1 << 0,
    /**
     *
     */
    PSHNotificationTypeAlert = 1 << 1,
    /**
     *
     */
    PSHNotificationTypeSound = 1 << 2
};

/**
 *  States of the location adquisition on metrics.
 */
typedef NS_OPTIONS(NSInteger, PSHLocationStateType){
    /**
     * Never use location metrics.
     */
    PSHLocationStateTypeNever  = 0,
    /**
     * Always use location on metrics.
     */
    PSHLocationStateTypeAlways,
    /**
     * Send locations metrics manually.
     */
    PSHLocationStateTypeManual
};

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 *  `PSHEngine` brings developers a tool to interact with PUSHTech API and query the model.<br />
 *  All the API calls are performed in the background. Methods involved in API queries accept block parameter of type `PSHAsyncSimpleBlock` which signature is:
 *
 *  <pre>typedef void(^PSHAsyncSimpleBlock)(NSError*)</pre>
 */

@interface PSHEngine : NSObject


////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @name Initialization

+ (instancetype)startWithEventBusDelegate:(id<PSHEventBusDelegate>)eventBusDelegate
                     notificationDelegate:(id<PSHNotificationDelegate>)notificationDelegate;

+ (instancetype)startWithConfiguration:(PSHConfiguration *)config
                      eventBusDelegate:(id<PSHEventBusDelegate>)eventBusDelegate
                  notificationDelegate:(id<PSHNotificationDelegate>)notificationDelegate;

- (void)setEventBusDelegate:(id<PSHEventBusDelegate>)eventBusDelegate;

- (void)setPushNotificationDelegate:(id<PSHNotificationDelegate>)notificationDelegate;

/**
 *  Initializes the engine with PUSHTech app credentials and logging level. Should be called ideally inside `application:didFinishLaunchingWithOptions:`
 *  and before any other method or property of the SDK.<br/>
 *  The first time this method is being called will trigger a `PSHSuccessfulAppRegistrationBusEvent` bus event (see `PSHBusProvider`).
 *
 *  @param appId     PUSHTech application ID.
 *  @param appSecret PUSHTech application secret.
 *  @param logLevel  Level of logging detail (see `PSHLogLevel`).
 */
+ (void)initializeWithAppId:(NSString*)appId
                  appSecret:(NSString*)appSecret
       notificationDelegate:(id<PSHNotificationDelegate>)notificationDelegate
           eventBusDelegate:(id<PSHEventBusDelegate>)eventBusDelegate
                   logLevel:(PSHLogLevel)logLevel;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @name Singleton

/**
 *  Gets the singleton engine instance. Should be called once the engine has been initialized (see `initializeWithAppId:appSecret:logLevel`).
 *
 *  @return Shared `PSHEngine` instance. Returns nil if the engine was not previously initialized.
 */
+(PSHEngine*)sharedInstance;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @name SDK State

/**
 *  Returns `YES` when the app has been previously registered, that is when local model has been updated with the necessary info from PUSHTech platform in order to perform any operation.
 */
@property (nonatomic, readonly) BOOL isAppRegistered;

@property (nonatomic, readonly) NSString *deviceId;

@property (nonatomic, readonly) NSString *appId;

@property (nonatomic, readonly) NSString *appSecret;

/**
 *  Registers user's device push token, in order to be able to send him notifications from PUSHTech platform.
 *
 *  @param pushToken Data from application delegates's method `application:didRegisterForRemoteNotificationsWithDeviceToken:`
 */
-(void)registerPushToken:(NSData*)pushToken;

/**
 *  Use this method to register for push notifications for both iOS7 and iOS8.
 *
 *  @param application   The application for which to register the push notifications.
 *  @param notifications The type of notifications you want to allow.
 */
+ (void)registerApplication:(UIApplication *)application
       forNotificationTypes:(PSHNotificationType)notifications;

/**
 *  Use this method to register custom actions for interactive notifications.
 *
 *  @param categoryID           Identifier for the new category of actions.
 *  @param notificationActions  Array of actions, UIMutableUserNotificationAction objects.
 */
- (BOOL)registerNotificationInteraction:(NSString *)categoryID
                                actions:(NSArray<UIMutableUserNotificationAction *>*)notificationActions;

/**
 *  Use this method to register custom actions for interactive notifications. Actions are by default non destructive and authentication required.
 *
 *  @param categoryID           Identifier for the new category of actions.
 *  @param buttonLabels         Array of button labels.
 *  @param buttonIdentifiers    Array of action identifiers.
 */
- (BOOL)registerNotificationInteraction:(NSString *)categoryID
                                 labels:(NSArray<NSString *>*)buttonLabels
                            identifiers:(NSArray<NSString *>*)buttonIdentifiers;

/**
 *  Removes any data from the model.
 */
-(void)clean;

////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
/// @name Campaigns

/**
 *  Returns an array of `PSHCampaignDAO` instances sorted by date from newer to older.
 */
@property (nonatomic, readonly) NSArray* campaignList;

/**
 
 Delete a campaign from the local database.
 
 @param campaignDAO     Campaign to be deleted.
 */
-(void)deleteCampaign:(PSHCampaignDAO *)campaignDAO;

/**
 
 This should be called whenever a remote notification is received in order to know if it contains any **new campaign** information and update the model: in `application:didFinishLaunchingWithOptions:` (asking `launchOptions` for `UIApplicationLaunchOptionsRemoteNotificationKey` key) and `application:didReceiveRemoteNotification:` (both `UIApplicationDelegate` methods).
 
 
 `PSHHandleRemotePushAsyncBlock` signature has three parameters (`BOOL`, `PSHCampaignDAO`&#42;, `NSError`&#42;):
 
 +  `YES` if the notification did contain any NEW campaign related info; `NO` otherwise.
 +  Campaign info object, or `nil` if any error happens or the notification didn't contain any campaign related info.
 +  An error if the operation fails; otherwise (success), `nil`.
 
 @param userInfo        Dictionary from the `UIApplicationDelegate` method.
 @param completionBlock Asynchronously executed block, fired once the operation has finished.
 */
-(void)handleRemotePushWithUserInfo:(NSDictionary*)userInfo completion:(PSHHandleRemotePushAsyncBlock)completionBlock;

/**
 
 This should be called whenever a remote notification is received in order to know what kind of push we have received. Depending on it we define up to three different completion blocks: for campaigns, custom notifications and other notifications (non PushTech).
 
 @param userInfo                Dictionary from the `UIApplicationDelegate` method.
 @param completionCampaignBlock Asynchronously executed block, fired once we got a Campaign.
 @param completionCustomBlock   Asynchronously executed block, fired once we got a Custom notification.
 @param completionOtherBlock    Asynchronously executed block, fired once we got other notification.
 @param failBlock               Asynchronously executed block, fired on error getting campaign or custom notification.
 */
-(void)handleRemotePushWithUserInfo:(NSDictionary*)userInfo
                   completionCustom:(PSHHandleRemotePushCustomAsyncBlock)completionCustomBlock
                 completionCampaign:(PSHHandleRemotePushCampaignAsyncBlock)completionCampaignBlock
                    completionOther:(PSHHandleRemotePushOtherAsyncBlock)completionOtherBlock
                               fail:(PSHHandleRemotePushFailAsyncBlock)failBlock;

/**
 *  Mark the campaign as viewed (updating the model and informing PUSHTech SDK platform).
 *
 *  @param campaign The viewed campaign.
 */
-(void)markCampaignAsViewed:(PSHCampaignDAO *)campaign;


/**
 *  Use this method to change the current log level.
 *
 */
- (void)setLogLevel:(PSHLogLevel)logLevel;

/**
 *  Use this method to change the current location configuration.
 *
 */
- (void)setLocationAdquisition:(PSHLocationStateType)state;

/**
 *  Use this method to perfom a Two Factor Authentication using SMS or a phone call if SMS delivery
 *  is not avaliable.
 *
 *  @param senderId        Will be used as the SenderID for SMS otherwise an alphanumeric address can be specified 
 *                         (maximum length 11 characters). Restrictions may apply, depending on the destination.
 *  @param brandName       Brand or name of your app, service the verification is for. This alphanumeric (maximum length 18 characters)
 *                         will be used inside the body of all SMS and TTS messages sent (e.g. "Your PIN code is ..")
 *  @param delay           Time in seconds to send a phone call with the pin code if it wasn't possible to deliver the code via SMS.
 *                         If the value is 0, it defaults to 120 seconds.
 *                         Range: 60-900 both included.
 *  @param expirationDelay Time in seconds for which the PIN should remain valid from the time that it is generated. For reference,
 *                         this is the same as the request being received and the first attempt to deliver the code being triggered.
 *                         If the value is 0, it defaults to 300 seconds.
 *                         Range: 60 - 3600 both included.
 */
- (void)sendAuthenticationSMSToPhoneNumber:(NSString *)phoneNumber
                               countryCode:(NSInteger)countryCode
                                  senderId:(NSString *)senderId
                                 brandName:(NSString *)brandName
                            phoneCallAfter:(NSInteger)delay
                             codeExpiresIn:(NSInteger)expirationDelay
                                completion:(PSHCompletionBlock)onCompletion;

/**
 *  Use this method to perfom a Two Factor Authentication using SMS or a phone call if SMS delivery
 *  is not avaliable.
 *
 *  @param senderId        Will be used as the SenderID for SMS otherwise an alphanumeric address can be specified
 *                         (maximum length 11 characters). Restrictions may apply, depending on the destination.
 *  @param brandName       Brand or name of your app, service the verification is for. This alphanumeric (maximum length 18 characters)
 *                         will be used inside the body of all SMS and TTS messages sent (e.g. "Your PIN code is ..")
 *  @param onCompletion    Asynchronously executed block, fired once the operation has finished.
 */
- (void)sendAuthenticationSMSToPhoneNumber:(NSString *)phoneNumber
                               countryCode:(NSInteger)countryCode
                                  senderId:(NSString *)senderId
                                 brandName:(NSString *)brandName
                                completion:(PSHCompletionBlock)onCompletion;


/**
 *  After receiving the authentication code, use this method to verify it.
 *  @param onCompletion    Asynchronously executed block, fired once the operation has finished.
 */
- (void)validateCode:(NSString *)code completion:(PSHCompletionBlock)onCompletion;


/**
 *  Use this method to test if your push notifications setup is working. If you call this method too often, push notifications may not arrive due to apple's restrictions.
 *
 *  @param accountID    The account ID you can find in the PushTech manager site under account settings
 *  @param masterSecret The master secret of your application(not the same as the application secret), you can find this in the PushTech manager site at the applications section.
 *  @param onCompletion    Asynchronously executed block, fired once the operation has finished.
 */
- (void)sendTestPushNotificationWithAccountID:(NSString *)accountID
                                 masterSecret:(NSString *)masterSecret
                                   completion:(PSHCompletionBlock)onCompletion;

@end