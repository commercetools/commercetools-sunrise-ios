
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>
#import "PSHProduct.h"

@class PSHCampaignDAO;

/**
 *  The type of gender metric.
 */
typedef NS_ENUM(NSUInteger, PSHGenderType){
    
    PSHGenderTypeMale = 0,
    PSHGenderTypeFemale
};

@interface PSHMetrics : NSObject

/**
 *  Use this method to send a user first name metric.
 *
 *  @param name User's first name.
 */
+ (void)sendMetricFirstName:(NSString *)name;

/**
 *  Use this method to send a user last name metric.
 *
 *  @param name User's last name.
 */
+ (void)sendMetricLastName:(NSString *)name;

/**
 *  Use this method to send a user gender metric.
 *
 *  @param gender   Gender of user.
 */
+ (void)sendMetricGender:(PSHGenderType)gender;

/**
 *  Use this method to send a user birthday metric.
 *
 *  @param birthday Date of birthday in the current system timezone.
 */
+ (void)sendMetricBirthday:(NSDate *)birthday;

/**
 *  Use this method to send a carrier name metric.
 *
 *  @param carrier  Carrier name.
 */
+ (void)sendMetricCarrierName:(NSString *)carrier;

/**
 *  Use this method to send a city name metric.
 *
 *  @param city City name.
 */
+ (void)sendMetricCity:(NSString *)city;

/**
 *  Use this method to send a country metric.
 *
 *  @param country  Country in ISO 3166-1 alpha-2 (two characters).
 */
+ (void)sendMetricCountry:(NSString *)country;

/**
 *  Use this method to Unsubscribe to Push Notification.
 */
+ (void)sendMetricUnsubscribe;

/**
 *  Use this method to Subscribe to Push Notification.
 */
+ (void)sendMetricSubscribe;

/**
 *  Use this method to send a facebook friends metric.
 *
 *  @param number   Number of facebook friends.
 */
+ (void)sendMetricFacebookFriends:(NSUInteger)number;

/**
 *  Use this method to send a facebook login metric.
 */
+ (void)sendMetricFacebookLogin;

/**
 *  Use this method to send a google login metric.
 */
+ (void)sendMetricGoogleLogin;

/**
 *  Use this method to send a twitter login metric.
 */
+ (void)sendMetricTwitterLogin;

/**
 *  Use this method to send an email metric.
 *
 *  @param email    Email address.
 */
+ (void)sendMetricEmail:(NSString *)email;

/**
 *  Use this method to send a phone number metric.
 *
 *  @param phone    Phone number.
 */
+ (void)sendMetricPhone:(NSString *)phone;

/**
 *  Use this method to send a product purchase metric.
 *
 *  @param productArray Array of PSHProduct objects
 */
+ (void)sendMetricPurchaseProducts:(NSArray<PSHProduct *> *)productArray;

/**
 *  Use this method to send a twitter followers metric.
 *
 *  @param number   Number of twitter followers.
 */
+ (void)sendMetricTwitterFollowers:(NSUInteger)number;

/**
 *  Use this method to send a campaing viewed metric.
 *
 *  @param campaign Viewed campaign.
 */
+ (void)sendMetricViewedCampaign:(PSHCampaignDAO *)campaign;

/**
 *  Use this method to send a location metric.
 *
 *  @param location Location to send.
 */
+ (void)sendMetricLocation:(CLLocation *)location;

/**
 *  Use this method to send a generic login metric.
 */
+ (void)sendMetricLogin;

/**
 *  Use this method to send a user register metric.
 */
+ (void)sendMetricRegister;

/**
 *  Use this method to send a generic logout metric.
 */
+ (void)sendMetricLogout;

/**
 *  Use this method to send a facebook logout metric.
 */
+ (void)sendMetricFacebookLogout;

/**
 *  Use this method to send a google logout metric.
 */
+ (void)sendMetricGoogleLogout;

/**
 *  Use this method to send a twitter logout metric.
 */
+ (void)sendMetricTwitterLogout;

/**
 *  Use this method to send a facebook ID metric.
 *
 *  @param facebookId   Facebook ID.
 */
+ (void)sendMetricFacbookID:(NSString *)facebookId;

/**
 *  Use this method to send a twitter ID metric.
 *
 *  @param twitterId    Twitter ID.
 */
+ (void)sendMetricTwitterID:(NSString *)twitterId;

/**
 *  Use this method to send a google ID metric.
 *
 *  @param googleId     Google ID.
 */
+ (void)sendMetricGoogleID:(NSString *)googleId;

/**
 *  Use this method to send a user ID metric.
 *
 *  @param userId       User ID.
 */
+ (void)sendMetricUserID:(NSString *)userId;

/**
 *  Use this method to send a number of products in the cart metric.
 *
 *  @param number       Number of products in the cart.
 */
+ (void)sendMetricCartProducts:(NSUInteger)number;

/**
 *  Use this method to send a product add on the cart metric.
 *
 *  @param name         Name of product
 *  @param productId    ID of product
 *  @param price        Price of product
 *  @param currency     Currency in ISO 4217 codification
 */
+ (void)sendMetricAddCartProduct:(NSString *)name
                       productId:(NSString *)productId
                           price:(NSNumber *)price
                        currency:(NSString *)currency;

/**
 *  Use this method to send a product remove from the cart metric.
 *
 *  @param name         Name of product
 *  @param productId    ID of product
 *  @param price        Price of product
 *  @param currency     Currency in ISO 4217 codification
 */
+ (void)sendMetricDeleteCartProduct:(NSString *)name
                          productId:(NSString *)productId
                              price:(NSNumber *)price
                           currency:(NSString *)currency;

/**
 *  Use this method to send a content view name metric.
 *
 *  @param name         Content view name.
 */
+ (void)sendMetricContentViewName:(NSString *)name;

/**
 *  Use this method to send a user first name metric.
 *
 *  @param name     User's first name.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricFirstName:(NSString *)name onChange:(BOOL)state;

/**
 *  Use this method to send a user last name metric.
 *
 *  @param name     User's last name.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricLastName:(NSString *)name onChange:(BOOL)state;

/**
 *  Use this method to send a user gender metric.
 *
 *  @param gender   Gender of user.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricGender:(PSHGenderType)gender onChange:(BOOL)state;

/**
 *  Use this method to send a user birthday metric.
 *
 *  @param birthday Date of birthday in the current system timezone.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricBirthday:(NSDate *)birthday onChange:(BOOL)state;

/**
 *  Use this method to send a carrier name metric.
 *
 *  @param carrier  Carrier name.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricCarrierName:(NSString *)carrier onChange:(BOOL)state;

/**
 *  Use this method to send a city name metric.
 *
 *  @param city     City name.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricCity:(NSString *)city onChange:(BOOL)state;

/**
 *  Use this method to send a country metric.
 *
 *  @param country  Country in ISO 3166-1 alpha-2 (two characters).
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricCountry:(NSString *)country onChange:(BOOL)state;

/**
 *  Use this method to send a facebook friends metric.
 *
 *  @param number   Number of facebook friends.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricFacebookFriends:(NSUInteger)number onChange:(BOOL)state;

/**
 *  Use this method to send an email metric.
 *
 *  @param email    Email address.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricEmail:(NSString *)email onChange:(BOOL)state;

/**
 *  Use this method to send a phone number metric.
 *
 *  @param phone    Phone number.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricPhone:(NSString *)phone onChange:(BOOL)state;

/**
 *  Use this method to send a product purchase metric.
 *
 *  @param productArray Array of PSHProduct objects
 *  @param state        Send only when value changed. Default is NO.
 */
+ (void)sendMetricPurchaseProducts:(NSArray<PSHProduct *> *)productArray
                          onChange:(BOOL)state;

/**
 *  Use this method to send a twitter followers metric.
 *
 *  @param number   Number of twitter followers.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricTwitterFollowers:(NSUInteger)number onChange:(BOOL)state;

/**
 *  Use this method to send a campaing viewed metric.
 *
 *  @param campaign Viewed campaign.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricViewedCampaign:(PSHCampaignDAO *)campaign onChange:(BOOL)state;

/**
 *  Use this method to send a location metric.
 *
 *  @param location Location to send.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricLocation:(CLLocation *)location onChange:(BOOL)state;

/**
 *  Use this method to send a facebook ID metric.
 *
 *  @param facebookId   Facebook ID.
 *  @param state        Send only when value changed. Default is NO.
 */
+ (void)sendMetricFacbookID:(NSString *)facebookId onChange:(BOOL)state;

/**
 *  Use this method to send a twitter ID metric.
 *
 *  @param twitterId    Twitter ID.
 *  @param state        Send only when value changed. Default is NO.
 */
+ (void)sendMetricTwitterID:(NSString *)twitterId onChange:(BOOL)state;

/**
 *  Use this method to send a google ID metric.
 *
 *  @param googleId     Google ID.
 *  @param state        Send only when value changed. Default is NO.
 */
+ (void)sendMetricGoogleID:(NSString *)googleId onChange:(BOOL)state;

/**
 *  Use this method to send a user ID metric.
 *
 *  @param userId       User ID.
 *  @param state        Send only when value changed. Default is NO.
 */
+ (void)sendMetricUserID:(NSString *)userId onChange:(BOOL)state;

/**
 *  Use this method to send a number of products in the cart metric.
 *
 *  @param number       Number of products in the cart.
 *  @param state        Send only when value changed. Default is NO.
 */
+ (void)sendMetricCartProducts:(NSUInteger)number onChange:(BOOL)state;

/**
 *  Use this method to send a product add on the cart metric.
 *
 *  @param name         Name of product
 *  @param productId    ID of product
 *  @param price        Price of product
 *  @param currency     Currency in ISO 4217 codification
 *  @param state        Send only when value changed. Default is NO.
 */
+ (void)sendMetricAddCartProduct:(NSString *)name
                       productId:(NSString *)productId
                           price:(NSNumber *)price
                        currency:(NSString *)currency
                        onChange:(BOOL)state;

/**
 *  Use this method to send a product remove from the cart metric.
 *
 *  @param name         Name of product
 *  @param productId    ID of product
 *  @param price        Price of product
 *  @param currency     Currency in ISO 4217 codification
 *  @param state        Send only when value changed. Default is NO.
 */
+ (void)sendMetricDeleteCartProduct:(NSString *)name
                          productId:(NSString *)productId
                              price:(NSNumber *)price
                           currency:(NSString *)currency
                           onChange:(BOOL)state;

/**
 *  Use this method to send a content view name metric.
 *
 *  @param name     Content view name.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendMetricContentViewName:(NSString *)name onChange:(BOOL)state;

/**
 *  Use this method to send your custom metrics to the manager with boolean value.
 *
 *  @param value   Boolean value.
 *  @param type    An NSString defining the type of your metric.
 *  @param subtype An NSString defining the subtype of your metric.
 */
+ (void)sendCustomMetricBoolean:(BOOL)value
                           type:(NSString *)type
                        subtype:(NSString *)subtype;

/**
 *  Use this method to send your custom metrics to the manager with string value.
 *
 *  @param value   String value.
 *  @param type    An NSString defining the type of your metric.
 *  @param subtype An NSString defining the subtype of your metric.
 */
+ (void)sendCustomMetricString:(NSString *)value
                          type:(NSString *)type
                       subtype:(NSString *)subtype;

/**
 *  Use this method to send your custom metrics to the manager with number value.
 *
 *  @param value   Number value.
 *  @param type    An NSString defining the type of your metric.
 *  @param subtype An NSString defining the subtype of your metric.
 */
+ (void)sendCustomMetricNumber:(NSNumber *)value
                          type:(NSString *)type
                       subtype:(NSString *)subtype;

/**
 *  Use this method to send your custom metrics to the manager with date value.
 *
 *  @param value   Date value.
 *  @param type    An NSString defining the type of your metric.
 *  @param subtype An NSString defining the subtype of your metric.
 */
+ (void)sendCustomMetricDate:(NSDate *)value
                        type:(NSString *)type
                     subtype:(NSString *)subtype;

/**
 *  Use this method to send your custom metrics to the manager with boolean value.
 *
 *  @param value    Boolean value.
 *  @param type     An NSString defining the type of your metric.
 *  @param subtype  An NSString defining the subtype of your metric.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendCustomMetricBoolean:(BOOL)value
                           type:(NSString *)type
                        subtype:(NSString *)subtype
                       onChange:(BOOL)state;

/**
 *  Use this method to send your custom metrics to the manager with string value.
 *
 *  @param value    String value.
 *  @param type     An NSString defining the type of your metric.
 *  @param subtype  An NSString defining the subtype of your metric.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendCustomMetricString:(NSString *)value
                          type:(NSString *)type
                       subtype:(NSString *)subtype
                      onChange:(BOOL)state;

/**
 *  Use this method to send your custom metrics to the manager with number value.
 *
 *  @param value    Number value.
 *  @param type     An NSString defining the type of your metric.
 *  @param subtype  An NSString defining the subtype of your metric.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendCustomMetricNumber:(NSNumber *)value
                          type:(NSString *)type
                       subtype:(NSString *)subtype
                      onChange:(BOOL)state;

/**
 *  Use this method to send your custom metrics to the manager with date value.
 *
 *  @param value    Date value.
 *  @param type     An NSString defining the type of your metric.
 *  @param subtype  An NSString defining the subtype of your metric.
 *  @param state    Send only when value changed. Default is NO.
 */
+ (void)sendCustomMetricDate:(NSDate *)value
                        type:(NSString *)type
                     subtype:(NSString *)subtype
                    onChange:(BOOL)state;

/**
 *  Use this method to send the metrics immediately.
 */
+ (void)forceSendMetrics;

/**
 *  By default the send interval is 5 minutes.
 *
 *  @param timeInterval
 */
+ (void)setMetricSendInterval:(NSTimeInterval)timeInterval;

@end
