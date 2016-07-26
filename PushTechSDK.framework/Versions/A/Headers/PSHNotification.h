
#import <Foundation/Foundation.h>
#import "PSHCampaignDAO.h"
#import "PSHCustomDAO.h"

typedef NS_ENUM(NSUInteger, PSHNotificationDefaultAction) {
    PSHNotificationDefaultActionLandingPage,
    PSHNotificationDefaultActionNone
};

@interface PSHNotification : NSObject

@property (nonatomic, strong) NSDictionary *userInfo;
@property (nonatomic, strong) PSHCampaignDAO *campaign;
@property (nonatomic, strong) PSHCustomDAO *custom;
@property (nonatomic, assign) PSHNotificationDefaultAction defaultAction;

extern const struct PSHNotificationInteraction
{
    __unsafe_unretained NSString *ACTION_OK;
    __unsafe_unretained NSString *ACTION_CANCEL;
    __unsafe_unretained NSString *ACTION_EDIT;
    __unsafe_unretained NSString *ACTION_SEND;
    __unsafe_unretained NSString *ACTION_BUY;
    __unsafe_unretained NSString *ACTION_SAVE;
    __unsafe_unretained NSString *ACTION_FIND;
    __unsafe_unretained NSString *ACTION_LIKE;
    __unsafe_unretained NSString *ACTION_DISLIKE;
    __unsafe_unretained NSString *ACTION_LAUNCH;
    __unsafe_unretained NSString *ACTION_REMIND;
    __unsafe_unretained NSString *ACTION_DELETE;
    __unsafe_unretained NSString *ACTION_FORBID;
    __unsafe_unretained NSString *ACTION_FOLLOW;
    __unsafe_unretained NSString *ACTION_SHARE;
    __unsafe_unretained NSString *ACTION_SHOP;
    __unsafe_unretained NSString *ACTION_LATER;
    __unsafe_unretained NSString *ACTION_YES;
    __unsafe_unretained NSString *ACTION_NO;
    __unsafe_unretained NSString *ACTION_ACCEPT;
    __unsafe_unretained NSString *ACTION_DECLINE;
    
} PSHNotificationInteraction;

@end
