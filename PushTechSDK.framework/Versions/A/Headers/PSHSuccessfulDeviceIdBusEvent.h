#import <Foundation/Foundation.h>

/**
 Bus event emitted after a successful app registration, that is when local model has been updated with the necessary info from PUSHTech platform in order to perform any operation. Event bus listeners (see `PSHBusProvider`) must implement the following method for event awareness:
 
    -(void)onSuccessfulDeviceIdBusEvent:(NSNotification*)notification
    {
        // Now we can obtain the DeviceID
        NSString *deviceId = [PSHEngine sharedInstance].deviceId;
        ...
    }
 */

@interface PSHSuccessfulDeviceIdBusEvent : NSObject

@end
