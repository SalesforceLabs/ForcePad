/*
 * Copyright, 2012, salesforce.com
 * All Rights Reserved
 * Company Confidential
 */

#import <UIKit/UIKit.h>

static NSUInteger const kBucketDefaultSize = 25;

@interface SFAnalytics : NSObject

+ (SFAnalytics *)sharedInstance;
- (void)startWithService:(NSString *)string token:(NSString *)token;
- (void)tagEvent:(NSString *)event;
- (void)tagEvent:(NSString *)event attributes:(NSDictionary *)attributes;
- (void)tagScreen:(NSString *)screen;

/**
 * Returns a string representing a bucketed value of some variable.
 * Useful for analytics services that don't do this on their own *cough* localytics
 * e.g. for value 34 and bucket size 25, returns "25 - 49"
 * Note: will convert the value to a positive number.
 * Note: defaults to 10 max buckets
 * @param value - the value of your variable
 * @param bucketSize - the size of the bucket to use, or kBucketDefaultSize (25)
 * @return the bucket string
 */
+ (NSString *) bucketStringForNumber:(NSNumber *)value
                          bucketSize:(NSUInteger)bucketSize;

/**
 * Returns a string representing a bucketed value of some variable.
 * Useful for analytics services that don't do this on their own *cough* localytics
 * e.g. for value 34 and bucket size 25, returns "25 - 49"
 * Note: will convert the value to a positive number.
 * @param value - the value of your variable
 * @param bucketSize - the size of the bucket to use, or kBucketDefaultSize (25)
 * @param maxBuckets - the maximum number of bucket strings, or 0 for unlimited
 * @return the bucket string
 */
+ (NSString *) bucketStringForNumber:(NSNumber *)value
                          bucketSize:(NSUInteger)bucketSize
                          maxBuckets:(NSUInteger)maxBuckets;

@end
