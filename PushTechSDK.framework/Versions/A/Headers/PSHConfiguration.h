
#import <Foundation/Foundation.h>

#import "PSHEngine.h"

@interface PSHConfiguration : NSObject

@property (nonatomic, readonly) NSString *applicationID;
@property (nonatomic, readonly) NSString *applicationSecret;
@property (nonatomic, readonly) PSHNotificationType notificationTypes;

+ (instancetype)defaultConfiguration;
+ (instancetype)configurationWithFileAtPath:(NSString *)filePath;

@end
