
#import <Foundation/Foundation.h>

#import "PSHLandingPageTheme.h"

@protocol PSHLandingPageDelegate;

@interface PSHLandingPage : NSObject

+ (void)useTheme:(PSHLandingPageTheme *)theme;

+ (void)showLandingPageWithURLString:(NSString *)URLString;

+ (void)showLandingPageWithURLString:(NSString *)URLString
                            delegate:(id<PSHLandingPageDelegate>)delegate;

+ (void)setDelegate:(id<PSHLandingPageDelegate>)delegate;

@end

@protocol PSHLandingPageDelegate <NSObject>

@optional
- (void)willShowLandingPageWithURLString:(NSString *)URLString;
- (void)willDismissLandingPageWithURLString:(NSString *)URLString;
- (BOOL)shouldNavigateToPageWithURLRequest:(NSURLRequest *)request;

@end