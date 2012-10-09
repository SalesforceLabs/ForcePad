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

// This singleton calls out for and caches metadata about apps (tabsets) and tabs

#import <Foundation/Foundation.h>
#import "zkSforce.h"

// fuck yeah semicolons
#define kSalesforcePicklistValueSeparator   @";"

#define kRecordTypeIdField                  @"RecordTypeId"
#define kRecordTypeRelationshipField        @"RecordType"

@interface SFVAppCache : NSObject {    
    // Cache of tab sets
    NSMutableArray *appCache;
    
    // key: sobject name
    NSMutableDictionary *tabImageCache;
    
    // Global describe cache. key: sObject name
    NSMutableDictionary *globalDescribeCache;
    
    // Individual object describe cache. key: sObject name
    NSMutableDictionary *objectDescribeCache;
}

+ (SFVAppCache *)sharedSFVAppCache; 

// Properties to check on a global object's describe
typedef enum GlobalDescribeBooleanProperties {
    GlobalObjectIsSearchable = 0,
    GlobalObjectIsLayoutable,
    GlobalObjectIsQueryable,
    GlobalObjectIsFeedEnabled,
    GlobalObjectIsDeletable,
    GlobalObjectIsCustom
} GlobalDescribeBooleanProperty;

// Strings to return from a global object's describe
typedef enum GlobalDescribeStringProperties {
    GlobalObjectKeyPrefix = 0,
    GlobalObjectName,
    GlobalObjectLabel,
    GlobalObjectLabelPlural
} GlobalDescribeStringProperty;

// Properties to check on an object's describe
typedef enum ObjectDescribeBooleanProperties {
    ObjectIsRecordTypeEnabled = 0,
    ObjectIsDeletable,
    ObjectIsCreatable,
    ObjectIsUpdatable,
    ObjectHasCustomNewRecordURL,
    ObjectHasCustomEditRecordURL,
    ObjectHasCustomDetailRecordURL
} ObjectDescribeBooleanProperty;

// Strings to return from an object's describe
typedef enum ObjectDescribeStringProperties {
    ObjectDetailURL = 0,
    ObjectEditURL,
    ObjectNewURL
} ObjectDescribeStringProperty;

// Properties to check on a field describe
typedef enum FieldDescribeBooleanProperties {
    FieldIsFormulaField = 0,
    FieldIsCustom,
    FieldIsHTML,
    FieldIsNameField,
    FieldIsCreateable,
    FieldIsUpdateable,
    FieldIsNillable,
    FieldIsDependentPicklist,
    FieldIsRestrictedPicklist,
    FieldIsReferenceField
} FieldDescribeBooleanProperty;

// Strings to return from a field's describe
typedef enum FieldDescribeStringProperties {
    FieldCalculatedFormula = 0,
    FieldDefaultValue,
    FieldDefaultValueFormula,
    FieldInlineHelpText,
    FieldName,
    FieldLabel,
    FieldRelationshipName,
    FieldRelationshipOrder,
    FieldControllingFieldName,
    FieldType
} FieldDescribeStringProperty;

// Arrays to return from a field's describe
typedef enum FieldDescribeArrayProperties {
    FieldPicklistValues = 0,
    FieldReferenceTo,
} FieldDescribeArrayProperty;

// Integers to return from a field's describe
typedef enum FieldDescribeNumberProperties {
    FieldDigits = 0,
    FieldLength,
    FieldPrecision,
    FieldScale
} FieldDescribeNumberProperty;

// util

+ (NSString *) valueOrEmptyStringForString:(id)string;

// init

- (BOOL) isLoaded;
- (void) emptyCaches;

// caching. these expect REST (NSDictionary) responses, not SOAP (zksforce) responses

- (void) cacheTabSetResults:(NSArray *)results;
- (void) cacheGlobalDescribeResults:(NSDictionary *)results;
- (void) cacheDescribeObjectResult:(NSDictionary *)result;

// apps

// Return an array of zkDescribeTabSetResult, one per app
- (NSArray *) listAllApps;
// Return an array of NSString, app labels
- (NSArray *) listAllAppLabels;
// Return the URL for an app's logo
- (NSString *) logoURLForAppLogoImage:(NSString *)appLabel;

- (NSUInteger) indexOfSelectedApp;

// tabs

// Return an array of zkDescribeTabs
- (NSArray *) listTabsForAppWithLabel:(NSString *)label;
- (NSArray *) listTabsForAppAtIndex:(NSUInteger)index;
// Return the URL for an sobject's tab
- (NSString *) logoURLForSObjectTab:(NSString *)sObject;
- (UIImage *) imageForSObjectFromCache:(NSString *)sObject;

// global describe sObjects

- (BOOL) isMultiCurrencyEnabled;
- (BOOL) isChatterEnabled;
- (BOOL) doesGlobalObject:(NSString *)object haveProperty:(GlobalDescribeBooleanProperty)property;
- (NSString *) globalObject:(NSString *)object property:(GlobalDescribeStringProperty)property;

- (UIImage *) imageForSObject:(NSString *)sObject;
- (NSString *) labelForSObject:(NSString *)sObject usePlural:(BOOL)usePlural;

// array of strings
- (NSArray *) allGlobalSObjects;

// array of strings
- (NSArray *) allLayoutableSObjects;

// array of strings
- (NSArray *) allFeedEnabledSObjects;

- (NSDictionary *) describeGlobalsObject:(NSString *)sObject;
- (NSString *) sObjectFromRecordId:(NSString *)recordId;

// describing individual objects

// check cache
- (NSDictionary *) cachedDescribeForObject:(NSString *)object;

- (BOOL) isPersonAccountEnabled;

- (BOOL) doesObject:(NSString *)object haveProperty:(ObjectDescribeBooleanProperty)property;
- (BOOL) doesField:(NSString *)field onObject:(NSString *)object haveProperty:(FieldDescribeBooleanProperty)property;
- (NSString *) object:(NSString *)object stringProperty:(ObjectDescribeStringProperty)property;
- (NSDictionary *) describeForField:(NSString *)field onObject:(NSString *)object;


// fields
- (NSArray *) field:(NSString *)field onObject:(NSString *)object arrayProperty:(FieldDescribeArrayProperty)property;
- (NSString *) field:(NSString *)field onObject:(NSString *)object stringProperty:(FieldDescribeStringProperty)property;
- (NSInteger) field:(NSString *)field onObject:(NSString *)object numberProperty:(FieldDescribeNumberProperty)property;

- (NSString *) nameFieldForsObject:(NSString *)sObject;
- (NSString *) nameForSObject:(NSDictionary *)object;
- (NSString *) descriptionFieldForObject:(NSString *)object;
- (NSString *) descriptionValueForRecord:(NSDictionary *)record;

- (NSArray *) relatedObjectsOnObject:(NSString *)object;
- (NSArray *) shortFieldListForObject:(NSString *)sObject;

// array of names
- (NSArray *) namesOfFieldsOnObject:(NSString *)object;

// urls, misc

- (NSString *) webURLForURL:(NSString *)url;


@end
