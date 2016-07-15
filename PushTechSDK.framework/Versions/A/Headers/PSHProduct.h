//
//  PSHProduct.h
//  PushTechSDK
//
//  Created by Andreu Santaren Llop on 18/2/16.
//  Copyright © 2016 PushTech. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface PSHProduct : NSObject

@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSString *productId;
@property (nonatomic, readonly) NSNumber *price;
@property (nonatomic, readonly) NSString *currency;

- (instancetype)initWithProduct:(NSString *)name
                      productId:(NSString *)productId
                          price:(NSNumber *)price
                       currency:(NSString *)currency;

- (NSDictionary *)offerDictionary;

@end
