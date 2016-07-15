#import <Foundation/Foundation.h>

/**
 Bus event emitted after a successful app registration, that is when local model has been updated with the necessary info from PUSHTech platform in order to perform any operation. Event bus listeners (see `PSHBusProvider`) must implement the following method for event awareness:
 
    -(void)onSuccessfulAppRegistrationBusEvent:(NSNotification*)notification
    {
        PSHSuccessfulAppRegistrationBusEvent* event = (PSHSuccessfulAppRegistrationBusEvent*) notification.object;
    }
 */
@interface PSHSuccessfulAppRegistrationBusEvent : NSObject

@end
