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

#import "SFVAsync.h"

@implementation SFVAsync

#pragma mark - creating queries

+ (NSString *) sanitizeSOQLQueryFieldList:(NSString *)fieldList {
    if( !fieldList || [fieldList length] == 0 )
        return nil;
    
    fieldList = [SFVUtil trimWhiteSpaceFromString:fieldList];
    fieldList = [fieldList stringByReplacingOccurrencesOfString:@",," withString:@","];
    fieldList = [fieldList stringByReplacingOccurrencesOfString:@".," withString:@","];
    fieldList = [fieldList stringByReplacingOccurrencesOfString:@",." withString:@","];
    
    return fieldList;
}

+ (NSString *)sanitizeSOSLSearchTerm:(NSString *)searchTerm {
    // Escape every reserved character in this term
    for( int i = 0; i < [kSOSLReservedCharacters length]; i++ ) {
        NSString *ch = [kSOSLReservedCharacters substringWithRange:NSMakeRange(i, 1)];
        
        searchTerm = [searchTerm stringByReplacingOccurrencesOfString:ch
                                                           withString:[kSOSLEscapeCharacter stringByAppendingString:ch]];
    }
    
    return searchTerm;
}

+ (NSString *)SOSLQueryWithSearchTerm:(NSString *)term fieldScope:(NSString *)fieldScope objectScope:(NSDictionary *)objectScope {
    return [self SOSLQueryWithSearchTerm:term
                              fieldScope:fieldScope
                             objectScope:objectScope 
                                   limit:0];
}

+ (NSArray *)ZKSObjectArrayToDictionaryArray:(NSArray *)zkArray {
    if( !zkArray || [zkArray count] == 0 )
        return nil;
    
    NSMutableArray *converted = [NSMutableArray arrayWithCapacity:[zkArray count]];
        
    for( id result in zkArray ) {       
        NSMutableDictionary *dict = nil; 
        
        if( [result isKindOfClass:[ZKSObject class]] ) {
            dict = [NSMutableDictionary dictionaryWithDictionary:[(ZKSObject *)result fields]];
            [dict setObject:[(ZKSObject *)result type] forKey:kObjectTypeKey];
            
            if( [(ZKSObject *)result id] )
                [dict setObject:[(ZKSObject *)result id] forKey:@"Id"];
        } else {
            dict = [NSMutableDictionary dictionaryWithDictionary:result];     
            
            if( ![SFVUtil isEmpty:[dict valueForKeyPath:@"attributes.type"]] )
                [dict setObject:[dict valueForKeyPath:@"attributes.type"] forKey:kObjectTypeKey];
        }
        
        for( NSString *field in [dict allKeys] )
            if( [[dict objectForKey:field] isKindOfClass:[ZKSObject class]] )
                [dict setObject:[[self class] ZKSObjectToDictionary:[dict objectForKey:field]]
                         forKey:field];
                        
        [converted addObject:dict];
    }
    
    return converted;
}

+ (NSDictionary *)ZKSObjectToDictionary:(ZKSObject *)object {
    NSArray *results = [self ZKSObjectArrayToDictionaryArray:[NSArray arrayWithObject:object]];
    
    if( results && [results count] > 0 )
        return [results objectAtIndex:0];
    
    return nil;
}

+ (NSString *)SOSLQueryWithSearchTerm:(NSString *)term fieldScope:(NSString *)fieldScope objectScope:(NSDictionary *)objectScope limit:(NSInteger)limit {
    if( !term || [term length] == 0 )
        return nil;
    
    term = [self sanitizeSOSLSearchTerm:term];
    
    if( ![term hasSuffix:@"*"] )
        term = [term stringByAppendingString:@"*"];
    
    if( !fieldScope || [fieldScope length] == 0 )
        fieldScope = @"IN NAME FIELDS";
    
    NSMutableString *query = [NSMutableString stringWithFormat:@"FIND {%@} %@",
                                term,
                                fieldScope];
    
    if( objectScope && [objectScope count] > 0 ) {
        NSMutableArray *scopes = [NSMutableArray array];
        
        for( NSString *sObject in [objectScope allKeys] )
            [scopes addObject:[NSString stringWithFormat:@"%@ (%@)",
                                sObject,
                                [self sanitizeSOQLQueryFieldList:[objectScope objectForKey:sObject]]]];
        
        [query appendString:[NSString stringWithFormat:@" RETURNING %@", [scopes componentsJoinedByString:@","]]];
    }
    
    if( limit > 0 )
        [query appendFormat:@" LIMIT %i", ( limit > kMaxSOSLSearchLimit ? kMaxSOSLSearchLimit : limit )];
    
    return query;
}

+ (NSString *)SOQLQueryWithFields:(NSArray *)fields sObject:(NSString *)sObject where:(NSString *)where limit:(NSUInteger)limit {
    return [self SOQLQueryWithFields:fields
                             sObject:sObject
                               where:where
                             groupBy:nil
                              having:nil
                             orderBy:nil
                               limit:limit];
}

+ (NSString *)SOQLQueryWithFields:(NSArray *)fields sObject:(NSString *)sObject where:(NSString *)where groupBy:(NSArray *)groupBy having:(NSString *)having orderBy:(NSArray *)orderBy limit:(NSUInteger)limit {
    if( !fields || [fields count] == 0 )
        return nil;
    
    if( !sObject || [sObject length] == 0 )
        return nil;
        
    NSMutableString *query = [NSMutableString stringWithFormat:@"select %@ from %@",
                              [self sanitizeSOQLQueryFieldList:[[[NSSet setWithArray:fields] allObjects] componentsJoinedByString:@","]],
                              sObject];
    
    if( where && [where length] > 0 )
        [query appendFormat:@" where %@", where];
    
    if( groupBy && [groupBy count] > 0 ) {
        [query appendFormat:@" group by %@", [groupBy componentsJoinedByString:@","]];
    
        if( having && [having length] > 0 )
            [query appendFormat:@" having %@", having];
    }
    
    if( orderBy && [orderBy count] > 0 )
        [query appendFormat:@" order by %@", [orderBy componentsJoinedByString:@","]];
    
    if( limit > 0 )
        [query appendFormat:@" limit %i", limit];
    
    return query;
}

#pragma mark - async operations

+ (void)performSFVAsyncRequest:(NSObject *(^)(void))operation failBlock:(SFVFailBlock)failBlock completeBlock:(void (^)(id))completeBlock {
    if( !operation )
        return;
    
    [[SFVUtil sharedSFVUtil] startNetworkAction];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {        
        @try {
            NSObject *result = operation();
            
            [[SFVUtil sharedSFVUtil] endNetworkAction];
            
            if( completeBlock )
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    completeBlock(result);
                });
        } @catch( NSException *e ) {            
            [[SFVUtil sharedSFVUtil] endNetworkAction];
            [[SFVUtil sharedSFVUtil] receivedException:e];
            
            if( failBlock )
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    failBlock(e);
                });
        }
    });
}

#pragma mark - DML

+ (void)performRetrieveWithFields:(NSArray *)fields sObject:(NSString *)sObject ids:(NSArray *)ids failBlock:(SFVFailBlock)failBlock completeBlock:(SFVDictionaryCompleteBlock)completeBlock {
    // require sobject and ids
    if( !sObject || !ids || [ids count] == 0 )
        return;
    
    NSLog(@"** RETRIEVE sObject: %@ Ids:%@ FIELDS: %@", sObject, ids, fields);
    
    if( fields && [fields count] == 0 )
        fields = nil;
    
    if( [ids count] > kMaxRetrieveRecords )
        ids = [ids subarrayWithRange:NSMakeRange(0, kMaxRetrieveRecords)];
    
    NSString *fieldList = [[[NSSet setWithArray:fields] allObjects] componentsJoinedByString:@","];
    
    fieldList = [self sanitizeSOQLQueryFieldList:fieldList];
    
    [SFVAsync performSFVAsyncRequest:(id)^{
                            return [[[SFVUtil sharedSFVUtil] client] retrieve:fieldList
                                                                      sobject:sObject 
                                                                          ids:ids];
                        }
                       failBlock:^(NSException *e) {
                           if( failBlock )
                               failBlock(e);
                       }
                   completeBlock:^(id results) {
                        if( completeBlock )
                            completeBlock( results );
                   }];
}

+ (void)performSOQLQuery:(NSString *)query failBlock:(SFVFailBlock)failBlock completeBlock:(SFVQueryResultCompleteBlock)completeBlock {
    if( !query || [query length] == 0 )
        return;
        
    NSLog(@"** SOQL: %@", query);
        
    [SFVAsync performSFVAsyncRequest:(id)^{
                                return [[[SFVUtil sharedSFVUtil] client] query:query];
                            }
                           failBlock:^(NSException *e) {
                               if( failBlock )
                                   failBlock( e );
                           }
                       completeBlock:^(id results) {
                           if( completeBlock )
                               completeBlock( results );
                       }];
}

+ (void)performSOSLQuery:(NSString *)query failBlock:(SFVFailBlock)failBlock completeBlock:(SFVArrayCompleteBlock)completeBlock {
    if( !query || [query length] == 0 )
        return;
    
    query = [SFVAsync sanitizeSOQLQueryFieldList:query];
    
    NSLog(@"** SOSL: %@", query);
    
    [SFVAsync performSFVAsyncRequest:(id)^{
                                return [[[SFVUtil sharedSFVUtil] client] search:query];
                            }
                           failBlock:^(NSException *e) {
                               if( failBlock )
                                   failBlock( e );
                           }
                       completeBlock:^(id results) {
                           if( completeBlock )
                               completeBlock( results );
                       }];
}

+ (void)performQueryMore:(NSString *)queryLocator failBlock:(SFVFailBlock)failBlock completeBlock:(SFVQueryResultCompleteBlock)completeBlock {
    if( !queryLocator || [queryLocator length] == 0 )
        return;
        
    NSLog(@"** SOSL QueryMore: %@", queryLocator);
    
    [SFVAsync performSFVAsyncRequest:(id)^{
                                return [[[SFVUtil sharedSFVUtil] client] queryMore:queryLocator];
                            }
                           failBlock:^(NSException *e) {
                               if( failBlock )
                                   failBlock( e );
                           }
                       completeBlock:^(id results) {
                           if( completeBlock )
                               completeBlock( results );
                       }];
}

+ (void) createSObjects:(NSArray *)sObjects failBlock:(SFVFailBlock)failBlock completeBlock:(SFVArrayCompleteBlock)completeBlock {
    if( !sObjects || [sObjects count] == 0 )
        return;
    
    NSLog(@"** INSERTING: %@", sObjects);
    
    [SFVAsync performSFVAsyncRequest:(id)^{
                                return [[[SFVUtil sharedSFVUtil] client] create:sObjects];
                            }
                           failBlock:^(NSException *e) {
                               if( failBlock )
                                   failBlock( e );
                           }
                       completeBlock:^(id results) {
                           if( completeBlock )
                               completeBlock( results );
                       }];
}

+ (void) deleteSObjects:(NSArray *)sObjects failBlock:(SFVFailBlock)failBlock completeBlock:(SFVArrayCompleteBlock)completeBlock {
    if( !sObjects || [sObjects count] == 0 )
        return;
    
    NSLog(@"** DELETING: %@", sObjects);
    
    [SFVAsync performSFVAsyncRequest:(id)^{
                                return [[[SFVUtil sharedSFVUtil] client] delete:sObjects];
                            }
                           failBlock:^(NSException *e) {
                               if( failBlock )
                                   failBlock( e );
                           }
                       completeBlock:^(id results) {
                           if( completeBlock )
                               completeBlock( results );
                       }];
}

+ (void)describeTabsWithFailBlock:(SFVFailBlock)failBlock completeBlock:(SFVArrayCompleteBlock)completeBlock {
    NSLog(@"** DESCRIBE TABS");
    
    [SFVAsync performSFVAsyncRequest:(id)^{
        return [[[SFVUtil sharedSFVUtil] client] describeTabs];
    }
                           failBlock:^(NSException *e) {
                               if( failBlock )
                                   failBlock( e );
                           }
                       completeBlock:^(id results) {
                           if( completeBlock )
                               completeBlock( results );
                       }];
}

@end
