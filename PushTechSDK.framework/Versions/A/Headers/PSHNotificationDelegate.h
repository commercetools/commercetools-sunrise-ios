
#import <UIKit/UIKit.h>

#import "PSHNotification.h"

@protocol PSHNotificationDelegate <NSObject>

@required
/**
 *  This method is called when a notification is received in foreground of background. It is also
 *  called to give authorization to the SDK to perform default actions when a notification that
 *  triggers an action is received but the action is not performed,i.e.: A notification that should
 *  open a landing page is received but the app is in the background, this method will be called in
 *  background and again in foreground when the landing page should be actually shown.
 *
 *  @param notification         Received notification.
 *  @param completionHandler    Execute this callback when you are finished performing the background
 *  operations. It's important to execute this callback once you have finished all your operations,
 *  since this tells the system to terminate your application. If you don't execute the callback,
 *  the system will assume your application is not working and the system could decide that no more 
 *  notifications will be delivered to your app.
 *
 *  @return Wether the SDK can execute the default actions for this notification of not.
 */
- (BOOL)shouldPerformDefaultActionForRemoteNotification:(PSHNotification *)notification
        completionHandler:(void (^)(UIBackgroundFetchResult))completionHandler;

@optional
/**
 *  This method is called when a notification interaction is received.
 *
 *  @param actionID     Action identifier.
 *  @param notification Notification the action belongs to.
 */
- (void)performInteraction:(NSString *)actionID onNotification:(PSHNotification *)notification;

@end