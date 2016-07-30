
#import <UIKit/UIKit.h>

#import "PSHMetrics.h"

@interface PSHMetrics (PSHSDKMetrics)

- (void)sendReceivedCampaignMetricWithId:(NSString *)campaignId;
- (void)sendOpenCampaignMetricWithId:(NSString *)campaignId;
- (void)sendInternalMetrics;
- (void)setupMetricNotifications;

@end

@interface PSHMetrics ()

@property (nonatomic) BOOL notificationsConfigured;
@property (nonatomic, strong) NSDate *startSessionDate;
@property (nonatomic, strong) NSDate *stopSessionDate;

+ (instancetype)sharedInstance;
- (NSString *)valueTypeForValue:(id)value;

@end
