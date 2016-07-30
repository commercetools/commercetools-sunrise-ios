
#import <Foundation/Foundation.h>

@interface PSHRequestHandler : NSObject

@property (nonatomic) NSURL *baseURL;

- (NSMutableURLRequest *)createRequestWithPath:(NSString *)path
                                        method:(NSString *)method
                                    parameters:(NSDictionary *)parameters;

- (NSMutableURLRequest *)createRequestAtURLString:(NSString *)URLString
                                           method:(NSString *)method
                                       parameters:(NSDictionary *)parameters;

- (void)setValue:(NSString *)value forHTTPHeaderField:(NSString *)field;
- (NSDictionary *)allHeaderFields;

@end
