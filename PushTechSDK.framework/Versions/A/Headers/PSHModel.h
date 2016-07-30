#import <Foundation/Foundation.h>
#import <CoreData/CoreData.h>
#import "PSHCampaignDAO.h"
#import "PSHManagerInfo.h"

@interface PSHModel : NSObject

+(instancetype)sharedInstance;

-(void)setupCoreDataStack;

@property (nonatomic, strong) PSHManagerInfo* managerInfo;

-(void)saveUpdatedManagerInfo;

-(void)deleteDefaults;

@property (nonatomic, readonly) NSArray* campaignList;

-(void)deleteCampaign:(PSHCampaignDAO*)campaignDAO;

-(void)deleteCampaign:(NSString*)campaignId context:(NSManagedObjectContext*)context;

@property (nonatomic, readonly) NSManagedObjectContext* defaultContext;

@property (nonatomic, strong) NSManagedObjectContext* defaultManagedObjectContext;

-(NSManagedObjectContext*)defaultContext;
-(NSManagedObjectContext*)newContext;

@end