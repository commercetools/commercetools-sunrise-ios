#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

/**
 This class is only a helper which uses `NSNotificationCenter` and the Objective-C runtime under the hoods offering a simpler approach than the `NSNotificationCenter` standard flow verbosity. It adds the following abstraction layer: there is an event bus for the PUSHTech SDK and any class can register itself as an event bus listener just implementing *special* methods. Let's see this with an example:
 
    -(void)onSuccessfulAppRegistrationBusEvent:(NSNotification*)notification
 
 Any instance of any class which registers itself as an event bus listener (`addListener:`) and implements the previous method, will be notified as soon as an event happens. The `object` property of the `NSNotification` instance will be an instance of `PSHSuccessfulAppRegistrationBusEvent`. Notice that method signature is almost equal to the event class name but replacing our prefix `PSH` with 'on'.
 
 Since we're using `NSNotificationCenter` the same rules are applied in order to avoid leaking objects around, so don't forget to remove event bus listeners (`removeListener:`) whenever they are no longer needed.
 */
@protocol PSHEventBusDelegate;

@interface PSHBusProvider : NSObject

/**
 *  Shared bus provider.
 *
 *  @return `PSHBusProvider` singleton instance.
 */
+(id)sharedInstance;

/**
 *  Adds an object as an event bus listener.
 *
 *  @param target Listener object.
 */
-(void)addListener:(NSObject <PSHEventBusDelegate>*)target;

/**
 *  Removes an object as an event bus listener.
 *
 *  @param target Listener object.
 */
-(void)removeListener:(NSObject <PSHEventBusDelegate>*)target;

/**
 *  Emits an event (aka `NSNotification`) with the specified object as its payload.
 *
 *  @param event Any instance of any class named using the nomenclature `PSH___BusEvent` where '___' is the name of the event.
 */
-(void)emit:(NSObject*)event;

@end
