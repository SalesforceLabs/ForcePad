/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh@salesforce.com
 * All rights reserved.
 * 
 * Redistribution and use in source and binary forms, with or without modification, are permitted provided 
 * that the following conditions are met:
 * 
 *    Redistributions of source code must retain the above copyright notice, this list of conditions and the 
 *    following disclaimer.
 *  
 *    Redistributions in binary form must reproduce the above copyright notice, this list of conditions and 
 *    the following disclaimer in the documentation and/or other materials provided with the distribution. 
 *    
 *    Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or 
 *    promote products derived from this software without specific prior written permission.
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED 
 * WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A 
 * PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR 
 * ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED 
 * TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) 
 * HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING 
 * NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE 
 * POSSIBILITY OF SUCH DAMAGE.
 */

#import <UIKit/UIKit.h>
#import "zkSforce.h"
#import <EventKit/EventKit.h>
#import <MapKit/MapKit.h>

@interface SFVUtil : NSObject {
    NSMutableDictionary *layoutCache;
    NSMutableDictionary *geoLocationCache;
    NSMutableDictionary *userPhotoCache;
    NSUInteger *activityCount;
}

+ (SFVUtil *)sharedSFVUtil;

// Image completion blocks

typedef void (^ImageCompletionBlock) (UIImage * img, BOOL wasLoadedFromCache);
typedef void (^DescribeLayoutCompletionBlock) (ZKDescribeLayoutResult *layoutDescribe);

#define OAUTH_CALLBACK @"sfdcviewer:///oauth_complete"
#define DownArrowCharacter @"▼"
#define UpArrowCharacter @"▲"

#define LabsOrgName         @"Salesforce Labs"

#define UIColorFromRGB(rgbValue) [UIColor colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 green:((float)((rgbValue & 0xFF00) >> 8))/255.0 blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]
#define RGB(r, g, b) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:1]
#define RGBA(r, g, b, a) [UIColor colorWithRed:r/255.0 green:g/255.0 blue:b/255.0 alpha:a]

#define SFRelease(var) [var release]; var = nil;
#define FIX_CATEGORY_BUG(name) @interface FIXCATEGORYBUG ## name @end @implementation FIXCATEGORYBUG ## name @end 

#define NSNumberFromInt(i)  [NSNumber numberWithInt:i]

// assuming CGRect b is smaller than CGRect a, returns a single origin point for rect b such that it is centered,
// by size, within rect a
#define CGPointCenteredOriginPointForRects(a, b)    CGPointMake( \
                                                        CGRectGetMinX(a) + floorf( ( ABS( CGRectGetWidth( a ) - CGRectGetWidth( b ) ) ) / 2.0f ), \
                                                        CGRectGetMinY(a) + floorf( ( ABS( CGRectGetHeight( a ) - CGRectGetHeight( b ) ) ) / 2.0f ) )

#define AppPrimaryColor UIColorFromRGB(0x222222)
#define AppSecondaryColor UIColorFromRGB(0x1797C0)
#define AppLinkColor UIColorFromRGB(0x1679c9)
#define AppTextCellColor RGB( 57.0f, 85.0f, 135.0f )

// Vertical space between a section header and the fields in that section
#define SECTIONSPACING 10

// Vertical space between field rows within a section
#define FIELDSPACING 8

// Standard width of a field label
#define FIELDLABELWIDTH 140

// Standard width of a field value
#define FIELDVALUEWIDTH 200

// Maximum height for a field value
#define FIELDVALUEHEIGHT 99999

#define RecentRecords @"RecentRecords"

#define VERSION                     [[UIDevice currentDevice] systemVersion]
#define AT_LEAST_IOS(xxx)           ( [[VERSION substringToIndex:1] intValue] >= xxx )

#define DeviceScale                 [[UIScreen mainScreen] scale]

#define DevicePortraitWindowWidth   CGRectGetWidth( [[UIScreen mainScreen] bounds] )
#define DevicePortraitWindowHeight  CGRectGetHeight( [[UIScreen mainScreen] bounds] )

enum dateGroups {
    GroupOneDay = 0,
    GroupOneWeek,
    GroupOneMonth,
    GroupThreeMonths,
    GroupSixMonths,
    GroupSixMonthsPlus,
    GroupNumDateGroups
};

#define DateGroupsArray [NSArray arrayWithObjects:@"1d", @"1w", @"1m", @"3m", @"6m", @"∞", nil]

@property (nonatomic, assign) ZKSforceClient *client;
@property (nonatomic, retain) EKEventStore *eventStore;

+ (NSString *) appFullName;
+ (NSString *) appVersion;

- (EKEventStore *) sharedEventStore;

- (NSString *) currentUserId;
- (NSString *) sessionId;
- (NSString *) currentOrgName;
- (NSString *) currentUserName; // not the username, but the user's name

+ (BOOL) isConnected;

- (void) emptyCaches:(BOOL)emptyAll;
- (NSArray *) coordinatesFromCache:(NSString *)accountId;
- (void) addCoordinatesToCache:(CLLocationCoordinate2D)coordinates accountId:(NSString *)accountId;
- (UIImage *) userPhotoFromCache:(NSString *)photoURL;
- (void) addUserPhotoToCache:(UIImage *)photo forURL:(NSString *)photoURL;

// Creating a page layout for a record
- (NSString *)textValueForField:(NSString *)fieldName withDictionary:(NSDictionary *)sObject;
+ (UIView *) createViewForSection:(NSString *)section maxWidth:(float)maxWidth;
- (UIView *) createViewForLayoutItem:(ZKDescribeLayoutItem *)item withRecord:(NSDictionary *)dict withTarget:(id)target;
- (UIView *) layoutViewForsObject:(NSDictionary *)sObject withTarget:(id)target singleColumn:(BOOL)singleColumn;

// Merge two arrays of sobjects together, preserving ordering and uniqueness
+ (NSArray *) mergeObjectArray:(NSArray *)objectArray withArray:(NSArray *)array;
// Filter an array of sObjects to only return those that exist in the global describe for this org
- (NSArray *) filterGlobalObjectArray:(NSArray *)objectArray;
// Sort a list of sObjects by their plural labels.
- (NSArray *) sortGlobalObjectArray:(NSArray *)objectArray;
+ (NSString *) addressForsObject:(NSDictionary *)sObject useBillingAddress:(BOOL)useBillingAddress;
+ (NSString *) cityStateForsObject:(NSDictionary *)sObject;

// Describe sObject layouts  
- (void) describeLayoutForsObject:(NSString *)sObject completeBlock:(DescribeLayoutCompletionBlock)completeBlock;
- (ZKDescribeLayout *) layoutForRecord:(NSDictionary *)record;
- (NSString *) layoutIDForRecord:(NSDictionary *)record;
- (ZKDescribeLayout *) layoutWithLayoutId:(NSString *)layoutId;
- (NSString *) sObjectFromLayoutId:(NSString *)layoutId;
- (NSArray *) fieldListForLayoutId:(NSString *)layoutId;
- (NSString *) sObjectFromRecordTypeId:(NSString *)recordTypeId;

// key: id, value: name
- (NSDictionary *) availableRecordTypesForObject:(NSString *)object;

// key: id, value: name
- (NSDictionary *) defaultRecordTypeForObject:(NSString *)object;

// key: name of picklist field. value: array of ZKPicklistEntry
- (NSDictionary *) picklistValuesForObject:(NSString *)object recordTypeId:(NSString *)recordTypeId;

// array of dictionaries with key: name of picklist value. value: label for that picklist value
- (NSArray *) picklistValuesForField:(NSString *)field onObject:(NSDictionary *)object filterByRecordType:(BOOL)filterByRecordType;

// return true if input is a member of picklist's values or labels
- (BOOL) isValue:(NSString *)value inPicklist:(NSString *)picklist onObject:(NSString *)object;

// Recent records
- (NSArray *) loadRecentRecords;
- (void) addRecentRecord:(NSString *)recordId;
- (void) removeRecentRecordWithId:(NSString *)recordId;
- (void) removeRecentRecordsWithIds:(NSArray *)recordIds;
- (NSArray *) recentRecordsForSObject:(NSString *)sObject;
- (void) clearRecentRecords;

// Misc utility functions
- (void) loadImageFromURL:(NSString *)url 
                cache:(BOOL)cache 
         maxDimension:(CGFloat)maxDimension
        completeBlock:(ImageCompletionBlock)completeBlock;

+ (NSString *) truncateURL:(NSString *)url;
+ (NSString *) trimWhiteSpaceFromString:(NSString *)source;
+ (BOOL) isEmpty:(id) thing;
+ (NSArray *) randomSubsetFromArray:(NSArray *)original ofSize:(int) size;
+ (NSDictionary *) dictionaryFromRecordsGroupedByDate:(NSArray *)records dateField:(NSString *)dateField;
+ (NSDictionary *) dictionaryFromAccountArray:(NSArray *)results;
+ (NSDictionary *) accountFromIndexPath:(NSIndexPath *)ip accountDictionary:(NSDictionary *)allAccounts;
+ (NSIndexPath *) indexPathForAccountDictionary:(NSDictionary *)account allAccountDictionary:(NSDictionary *)allAccounts;
+ (NSDictionary *) dictionaryByAddingAccounts:(NSArray *)accounts toDictionary:(NSDictionary *)allAccounts;
+ (NSString *) SOQLDatetimeFromDate:(NSDate *)date isDateTime:(BOOL)isDateTime;
+ (NSDate *) dateFromSOQLDatetime:(NSString *)datetime;
+ (NSArray *) filterRecords:(NSArray *)records dateField:(NSString *)dateField withDate:(NSDate *)date createdAfter:(BOOL)createdAfter;
+ (NSString *) relativeTime:(NSDate *)sinceDate;
+ (NSArray *) sortArray:(NSArray *) toSort;
+ (NSString *) getIPAddress;
+ (NSString *) stripHTMLTags:(NSString *)str;
+ (NSString *) stringByDecodingEntities:(NSString *)str;

// given an arbitrary HTML string from a rich text field, we scan for any SFDC-stored images
// contained therein and append a session ID to their URLs so they can be loaded
// in a webview
+ (NSString *) stringByAppendingSessionIdToImagesInHTMLString:(NSString *)htmlstring sessionId:(NSString *)sessionId;

+ (NSString *) stringByAppendingSessionIdToURLString:(NSString *)urlstring sessionId:(NSString *)sessionId;

// image operations
void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight);

- (void) startNetworkAction;
- (void) endNetworkAction;
- (void) receivedException:(NSException *)e;
- (void) receivedAPIError:(NSError *)error;
- (void) internalError:(NSError *)error;

@end
