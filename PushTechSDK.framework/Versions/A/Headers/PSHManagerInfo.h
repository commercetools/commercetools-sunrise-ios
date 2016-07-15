#import <Foundation/Foundation.h>

static const double PushTechSDKVersion = 2.0;

typedef NS_ENUM(NSInteger, PSHManagerInfoState) {
    PSHManagerInfoStateAppUnregistered = 0,
    PSHManagerInfoStatePushTokenUnsentToManager = 10,
    PSHManagerInfoStateChatEnabledButNoUniverse = 20,
    PSHManagerInfoStatePushTokenUnsentToUniverse = 30,
    PSHManagerInfoStateComplete = 40
};

@interface PSHManagerInfo : NSObject <NSCoding>

@property (nonatomic, strong) NSString* deviceId;
@property (nonatomic, strong) NSString* universeUrl;

@property (nonatomic, assign) BOOL chatEnabled;

@property (nonatomic, strong) NSString* pushToken;
@property (nonatomic, assign) double currentSDKVersion;

@property (nonatomic, assign) PSHManagerInfoState state;

-(void)reset;

@end
