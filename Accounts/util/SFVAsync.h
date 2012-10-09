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

#import "SFVUtil.h"

// Reserved characters that must be escaped in SOSL search terms
// backslash goes first!
#define kSOSLReservedCharacters @"\\?&|!{}[]()^~*:\"'+-"
#define kSOSLEscapeCharacter    @"\\"

// Maximum number of records in a retrieve
#define kMaxRetrieveRecords     2000

// Maximum character length of a SOQL query
#define kMaxSOQLLength          10000

// Maximum number of records in a subquery, excluding openactivity and activityhistory (which are 500)
#define kMaxSOQLSubQueryLimit   200

// Maximum number of records returned via SOSL search
#define kMaxSOSLSearchLimit     200

#define kObjectTypeKey          @"sObjectType"

@interface SFVAsync : NSObject {}

typedef void (^SFVAsyncOperation) (void);
typedef void (^SFVFailBlock) (NSException *e);
typedef void (^SFVArrayCompleteBlock) (NSArray *records);
typedef void (^SFVQueryResultCompleteBlock) (ZKQueryResult *result);
typedef void (^SFVDictionaryCompleteBlock) (NSDictionary *results);

// Sanitizing
+ (NSString *) sanitizeSOSLSearchTerm:(NSString *)searchTerm;
+ (NSString *) sanitizeSOQLQueryFieldList:(NSString *)fieldList;

// Given an array of zksobjects, convert to an array of dictionaries. convert recursively on fields
+ (NSArray *) ZKSObjectArrayToDictionaryArray:(NSArray *)zkArray;
// Likewise for a single object
+ (NSDictionary *) ZKSObjectToDictionary:(ZKSObject *)object;

// Generating queries

// Generate a SOSL query.
// term - the search term. This is sanitized for proper characters
// fieldscope - IN ALL FIELDS, IN NAME FIELDS (default if nil)
// objectScope - nil for all objects, or a dictionary with keys sObjectName and values NSString of field term to search on each object
// limit - overall limit (max 200)
+ (NSString *) SOSLQueryWithSearchTerm:(NSString *)term 
                            fieldScope:(NSString *)fieldScope 
                           objectScope:(NSDictionary *)objectScope;

+ (NSString *) SOSLQueryWithSearchTerm:(NSString *)term 
                            fieldScope:(NSString *)fieldScope 
                           objectScope:(NSDictionary *)objectScope 
                                 limit:(NSInteger)limit;

// Generate a SOQL query.
// fields - an array of fields to select
// object - object to query
// where - where clause
// limit - limit count, or 0 for no limit (for use with query locators)
+ (NSString *) SOQLQueryWithFields:(NSArray *)fields 
                           sObject:(NSString *)sObject 
                             where:(NSString *)where 
                             limit:(NSUInteger)limit;

+ (NSString *) SOQLQueryWithFields:(NSArray *)fields 
                           sObject:(NSString *)sObject 
                             where:(NSString *)where 
                           groupBy:(NSArray *)groupBy 
                            having:(NSString *)having
                           orderBy:(NSArray *)orderBy 
                             limit:(NSUInteger)limit;

+ (void) performSFVAsyncRequest:(NSObject *(^)(void))operation 
                      failBlock:(SFVFailBlock)failBlock 
                  completeBlock:(void(^)(id results))completeBlock;

// Actually execute a SOQL query.
// query - the query
// failblock - block executed on fail
// completeblock - block executed on complete
+ (void) performSOQLQuery:(NSString *)query 
                failBlock:(SFVFailBlock)failBlock
            completeBlock:(SFVQueryResultCompleteBlock)completeBlock;

// Execute a querymore
+ (void) performQueryMore:(NSString *)queryLocator
                failBlock:(SFVFailBlock)failBlock 
            completeBlock:(SFVQueryResultCompleteBlock)completeBlock;

// Actually execute a SOSL query.
// query - the query
// failblock - block executed on fail
// completeblock - block executed on complete
+ (void) performSOSLQuery:(NSString *)query 
                failBlock:(SFVFailBlock)failBlock
            completeBlock:(SFVArrayCompleteBlock)completeBlock;

// Actually execute a retrieve.
// fields - NSArray of fields to retrieve
// sObject - name of sObject
// ids - NSArray of ids to retrieve
// failblock - block executed on fail
// completeblock - block executed on complete
+ (void) performRetrieveWithFields:(NSArray *)fields 
                           sObject:(NSString *)sObject 
                               ids:(NSArray *)ids 
                         failBlock:(SFVFailBlock)failBlock 
                     completeBlock:(SFVDictionaryCompleteBlock)completeBlock;

// Perform a DML insert.
// sObjects - array of zkSObjects
// failblock - to be executed on fail
// completeblock - to be executed on complete
+ (void) createSObjects:(NSArray *)sObjects
              failBlock:(SFVFailBlock)failBlock
          completeBlock:(SFVArrayCompleteBlock)completeBlock;

// Perform a DML delete
// sObjects - array of IDs to delete
// failblock - to be executed on fail
// completeblock - to be executed on complete
+ (void) deleteSObjects:(NSArray *)sObjects
              failBlock:(SFVFailBlock)failBlock
          completeBlock:(SFVArrayCompleteBlock)completeBlock;

// Perform a describe tabs
+ (void) describeTabsWithFailBlock:(SFVFailBlock)failBlock 
                     completeBlock:(SFVArrayCompleteBlock)completeBlock;

@end
