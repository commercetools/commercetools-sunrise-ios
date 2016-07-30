
#import <Foundation/Foundation.h>

@class PSHRequestHandler;
@class PSHResponseHandler;

typedef void(^PSH_SuccessBlock)(NSHTTPURLResponse *HTTPresponse, id obj);
typedef void(^PSH_ErrorBlock)(NSHTTPURLResponse *HTTPresponse, NSError *error, id obj);

@interface PSHRequestEngine : NSObject

@property (nonatomic) NSOperationQueue *queue;
@property (nonatomic) PSHRequestHandler *requestHandler;
@property (nonatomic) PSHResponseHandler *responseHandler;

+ (instancetype)instance;

- (void)setupWithBaseURL:(NSURL *)baseURL;
- (NSURL *)baseURL;

- (void)requestAtPath:(NSString *)path
               method:(NSString *)method
           parameters:(NSDictionary *)parameters
              success:(PSH_SuccessBlock)onSuccess
                error:(PSH_ErrorBlock)onError;

- (void)requestAtURLString:(NSString *)URLString
                    method:(NSString *)method
                parameters:(NSDictionary *)parameters
                   success:(PSH_SuccessBlock)onSuccess
                     error:(PSH_ErrorBlock)onError;

- (void)requestWithURLRequest:(NSMutableURLRequest *)request
                      success:(PSH_SuccessBlock)onSuccess
                        error:(PSH_ErrorBlock)onError;
@end
