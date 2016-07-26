/**
 *  Data Access Object for a PUSHTech Manager custom notification. Property names are self explanatory.
 */

#import <Foundation/Foundation.h>

@interface PSHCustomDAO : NSObject

@property (nonatomic, strong) NSString* customId;
@property (nonatomic, strong) NSNumber* type;
@property (nonatomic, strong) NSString* title;
@property (nonatomic, strong) NSString* text;
@property (nonatomic, strong) NSURL* URL;
@property (nonatomic, strong) NSURL* thumbnailURL;
@property (nonatomic, strong) NSDate* date;

/**
 *  `YES` if the campaign was marked as viewed.
 */
//@property (nonatomic, assign) BOOL viewed;

@end
