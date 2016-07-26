
#import <Foundation/Foundation.h>

@interface PSHLandingPageTheme : NSObject

@property (nonatomic) CGFloat borderWidth;
@property (nonatomic) CGFloat cornerRadius;
@property (nonatomic, copy) UIColor *borderColor;
@property (nonatomic, copy) UIColor *overlayBackgroundColor;
@property (nonatomic, copy) UIColor *webViewBackgroundColor;
@property (nonatomic, copy) UIColor *closeButtonTintColor;
@property (nonatomic, copy) UIImage *closeButtonImage;
@property (nonatomic) BOOL closeButtonHasShadow;
@property (nonatomic, copy) UIColor *activityIndicatorColor;

+ (PSHLandingPageTheme *)defaultTheme;

@end
