
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, PSH_HTTPStatusCodeType) {
    PSH_HTTPStatusCodeTypeInformational = 100,
    PSH_HTTPStatusCodeTypeSuccessful    = 200,
    PSH_HTTPStatusCodeTypeRedirection   = 300,
    PSH_HTTPStatusCodeTypeClientError   = 400,
    PSH_HTTPStatusCodeTypeServerError   = 500
};

@interface PSHResponseHandler : NSObject

- (PSH_HTTPStatusCodeType)statusTypeForHTTPStatusCode:(NSInteger)HTTPStatusCode;
- (id)parseResponseData:(NSData *)responseData;

@end
