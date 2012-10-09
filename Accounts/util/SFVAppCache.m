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

#import "SFVAppCache.h"
#import "SFVUtil.h"
#import "SynthesizeSingleton.h"
#import "SimpleKeychain.h"
#import "RootViewController.h"
#import "SFVAsync.h"
#import "NSData+Base64.h"
#import "UIImage+ImageUtils.h"

@implementation SFVAppCache

static NSString *kFieldsKey = @"fields";
static NSString *kNameField = @"name";

// keys for things we add to an object's describe dictionary
static NSString *kReferenceToKey = @"referenceTo";
static NSString *kRelatedObjectsArrayKey = @"relatedObjects";
static NSString *kNameFieldKey = @"nameField";

// dictionary where key = controlling parent value, value = array of valid child values
//static NSString *kDependentPicklistDictionaryKey = @"dependentPicklistDictionary";

SYNTHESIZE_SINGLETON_FOR_CLASS(SFVAppCache);

+ (NSString *)valueOrEmptyStringForString:(id)string {
    if( !string || [SFVUtil isEmpty:string] )
        return @"";
    
    return (NSString *)string;
}

#pragma mark - init

- (BOOL) isLoaded {
    return appCache != nil;
}

#pragma mark - caching

- (void)cacheGlobalDescribeResults:(NSDictionary *)results {    
    if( globalDescribeCache )
        SFRelease(globalDescribeCache);
    
    globalDescribeCache = [[NSMutableDictionary dictionary] retain];
    
    for( NSDictionary *object in [results objectForKey:@"sobjects"] )
        [globalDescribeCache setObject:object forKey:[object objectForKey:kNameField]];
}

- (void)cacheTabSetResults:(NSArray *)results {    
    if( appCache )
        SFRelease(appCache);
    
    appCache = [[NSMutableArray array] retain];
    
    if( tabImageCache )
        SFRelease(tabImageCache);
    
    tabImageCache = [[NSMutableDictionary dictionary] retain];
    
    if( results && [results count] > 0 )            
        for( ZKDescribeTabSetResult *tabset in results ) {
            [appCache addObject:tabset];
            
            for( ZKDescribeTab *tab in [tabset tabs] ) {                        
                if( [SFVUtil isEmpty:[tab sobjectName]] || [SFVUtil isEmpty:[tab iconUrl]] )
                    continue;
                
                [tabImageCache setObject:[tab iconUrl] forKey:[tab sobjectName]];
            }
        }
}

- (void) cacheDescribeObjectResult:(NSDictionary *)result {    
    NSMutableDictionary *describe = [NSMutableDictionary dictionaryWithDictionary:result];
    
    // Replace the fields array with a dictionary
    NSMutableDictionary *fieldDict = [NSMutableDictionary dictionary];
    NSMutableSet *objectIsRelatedTo = [NSMutableSet set];
    NSString *nameField = nil;
    
    for( NSDictionary *fieldDesc in [describe objectForKey:kFieldsKey] ) {   
        // cache what other objects we're related to, but avoid polymorphics
        if( ![SFVUtil isEmpty:[fieldDesc objectForKey:kReferenceToKey]]
            && ![[NSArray arrayWithObjects:@"WhatId", @"WhoId", nil] containsObject:[fieldDesc objectForKey:kNameField]] )
            [objectIsRelatedTo addObjectsFromArray:[fieldDesc objectForKey:kReferenceToKey]];
        
        // cache our name field
        if( [[fieldDesc objectForKey:@"nameField"] boolValue] )
            nameField = [fieldDesc objectForKey:kNameField];
        
        // Is this a picklist with a controlling field?
        /*if( [[fieldDesc objectForKey:@"dependentPicklist"] boolValue] ) {
            NSString *controllingField = [fieldDesc objectForKey:@"controllerName"];
            
            NSMutableDictionary *dependentDictionary = [NSMutableDictionary dictionary];
            
            NSLog(@"field %@ valid values?", [fieldDesc objectForKey:kNameField]);
            
            // assumes the controlling field is a picklist
            for( NSDictionary *picklistValue in [fieldDesc objectForKey:@"picklistValues"] ) {
                NSString *base64ValidFor = [picklistValue objectForKey:@"validFor"];
                NSData *data = [NSData dataFromBase64String:base64ValidFor];
                NSUInteger len = [data length];
                Byte *byteData = (Byte*)malloc(len);
                memcpy(byteData, [data bytes], len);
                
                for( int i = 0; i < [base64ValidFor length]; i++ ) {
                    // Controlling value at this index
                    NSDictionary *controllingValue;
                    
                    
                    if( ( byteData[i >> 3] & (0x80 >> i % 8)) != 0 ) {
                        NSLog(@"valid: %@", [picklistValue objectForKey:@"value"]);
                    }
                }
                
                free(byteData);
            }
        }*/
        
        [fieldDict setObject:fieldDesc forKey:[fieldDesc objectForKey:kNameField]];
    }
        
    [describe setObject:[objectIsRelatedTo allObjects] forKey:kRelatedObjectsArrayKey];
    [describe setObject:fieldDict forKey:kFieldsKey];
    
    // If there is no name, use Id. If there is a field named 'name', always use that
    if( ![SFVUtil isEmpty:[fieldDict objectForKey:[kNameField capitalizedString]]] )
        nameField = [kNameField capitalizedString];
    
    if( !nameField )
        nameField = @"Id";
    
    [describe setObject:nameField forKey:kNameFieldKey];
    
    if( objectDescribeCache )
        [objectDescribeCache setObject:describe 
                                forKey:[describe objectForKey:kNameField]];
    else
        objectDescribeCache = [[NSMutableDictionary dictionaryWithObject:describe 
                                                                  forKey:[describe objectForKey:kNameField]] 
                               retain];
}

- (void) emptyCaches {
    NSLog(@"EMPTYING APP CACHE");
    [appCache removeAllObjects];
    SFRelease(appCache);
    
    [tabImageCache removeAllObjects];
    SFRelease(tabImageCache);
    
    [globalDescribeCache removeAllObjects];
    SFRelease(globalDescribeCache);
    
    [objectDescribeCache removeAllObjects];
    SFRelease(objectDescribeCache);
}

#pragma mark - apps

- (NSArray *) listAllApps {
    return appCache;
}

- (ZKDescribeTabSetResult *)appWithLabel:(NSString *)label {
    for( ZKDescribeTabSetResult *app in appCache )
        if( [[app label] isEqualToString:label] )
            return app;
    
    return nil;
}

- (NSArray *) listAllAppLabels {
    NSMutableArray *labels = [NSMutableArray arrayWithCapacity:[appCache count]];
    
    for( ZKDescribeTabSetResult *app in appCache )
        [labels addObject:[app label]];
    
    return labels;
}

- (NSString *) logoURLForAppLogoImage:(NSString *)appLabel {
    return [[self appWithLabel:appLabel] logoUrl];
}

- (NSUInteger)indexOfSelectedApp {
    for( int i = 0; i < [appCache count]; i++ )
        if( [[appCache objectAtIndex:i] selected] )
            return i;
    
    return 0;
}

#pragma mark - tabs

- (NSArray *) listTabsForAppWithLabel:(NSString *)label {
    NSArray *tabs = [[self appWithLabel:label] tabs];
    
    if( !tabs || [tabs count] == 1 )
        return tabs;
    
    if( [[[tabs objectAtIndex:0] label] isEqualToString:@"Home"] && ![[tabs objectAtIndex:0] custom] )
        return [tabs objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [tabs count] - 1)]];
    
    return tabs;
}

- (NSArray *) listTabsForAppAtIndex:(NSUInteger)index {
    NSArray *tabs = [[appCache objectAtIndex:index] tabs];
    
    if( !tabs || [tabs count] == 1 )
        return tabs;
    
    if( [[[tabs objectAtIndex:0] label] isEqualToString:@"Home"] && ![[tabs objectAtIndex:0] custom] )
        return [tabs objectsAtIndexes:[NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [tabs count] - 1)]];
    
    return tabs;
}

- (NSString *) logoURLForSObjectTab:(NSString *)sObject {
    if( [tabImageCache objectForKey:sObject] )
        return [tabImageCache objectForKey:sObject];
    
    return nil;
}

- (UIImage *) imageForSObjectFromCache:(NSString *)sObject {    
    NSString *url = [self logoURLForSObjectTab:sObject];
    
    if( url && [[SFVUtil sharedSFVUtil] userPhotoFromCache:url] )
        return [[SFVUtil sharedSFVUtil] userPhotoFromCache:url];
    
    if( [self imageForSObject:sObject] )
        return [self imageForSObject:sObject];
    
    return nil;
}

#pragma mark - global describe sObjects

- (NSDictionary *)cachedDescribeForObject:(NSString *)object {
    return ( objectDescribeCache ? [objectDescribeCache objectForKey:object] : nil );
}

- (NSArray *)allGlobalSObjects {
    if( !globalDescribeCache )
        return nil;
    
    return [[[globalDescribeCache allKeys] copy] autorelease];
}

- (NSArray *)allLayoutableSObjects {
    return [[SFVUtil sharedSFVUtil] filterGlobalObjectArray:[self allGlobalSObjects]];
}

- (NSArray *)allFeedEnabledSObjects {
    NSMutableArray *ret = [NSMutableArray array];
    
    for( NSString *object in [self allLayoutableSObjects] )
        if( [self doesGlobalObject:object
                      haveProperty:GlobalObjectIsFeedEnabled] )
            [ret addObject:object];
    
    return ret;
}

- (NSDictionary *)describeGlobalsObject:(NSString *)sObject {
    if( !globalDescribeCache )
        return nil;
    
    return [[[globalDescribeCache objectForKey:sObject] copy] autorelease];
}

- (BOOL) isChatterEnabled {
    if( !globalDescribeCache )
        return NO;
    
    for( NSString *ob in [self allGlobalSObjects] )
        if( [self doesGlobalObject:ob haveProperty:GlobalObjectIsFeedEnabled] )
            return YES;
    
    return NO;
}

- (BOOL)isMultiCurrencyEnabled {
    if( !globalDescribeCache )
        return NO;
    
    return [[self allGlobalSObjects] containsObject:@"CurrencyType"];
}

- (BOOL)doesGlobalObject:(NSString *)object haveProperty:(GlobalDescribeBooleanProperty)property {
    if( !globalDescribeCache )
        return NO;
    
    NSDictionary *ob = [globalDescribeCache objectForKey:object];
    
    if( !ob )
        return NO;
    
    NSString *key = nil;
    
    switch( property ) {
        case GlobalObjectIsQueryable:
            key = @"queryable";
            break;
        case GlobalObjectIsLayoutable:
            key = @"layoutable";
            break;
        case GlobalObjectIsSearchable:
            key = @"searchable";
            break;
        case GlobalObjectIsFeedEnabled:
            key = @"feedEnabled";
            break;
        case GlobalObjectIsCustom:
            key = @"custom";
            break;
        case GlobalObjectIsDeletable:
            key = @"deletable";
            break;
    }
    
    if( [SFVUtil isEmpty:[ob objectForKey:key]] )
        return NO;
    
    return [[ob objectForKey:key] boolValue];
}

- (NSString *)globalObject:(NSString *)object property:(GlobalDescribeStringProperty)property {
    if( !globalDescribeCache )
        return nil;
    
    NSDictionary *ob = [globalDescribeCache objectForKey:object];
    
    if( !ob )
        return nil;
    
    NSString *key = nil;
    
    switch( property ) {
        case GlobalObjectName:
            key = @"name";
            break;
        case GlobalObjectKeyPrefix:
            key = @"keyPrefix";
            break;
        case GlobalObjectLabel:
            key = @"label";
            break;
        case GlobalObjectLabelPlural:
            key = @"labelPlural";
            break;
    }
    
    if( [SFVUtil isEmpty:[ob objectForKey:key]] )
        return nil;
    
    return [[[ob objectForKey:key] copy] autorelease];
}

- (NSString *) labelForSObject:(NSString *)sObject usePlural:(BOOL)usePlural {
    return [self globalObject:sObject property:( usePlural ? GlobalObjectLabelPlural : GlobalObjectLabel )];
}

- (NSString *) sObjectFromRecordId:(NSString *)recordId {
    if( !recordId || [recordId length] < 15 )
        return nil; // local record
    
    NSString *prefix = [recordId substringToIndex:3];
    
    for( NSString *sObject in [self allGlobalSObjects] )
        if( [self doesGlobalObject:sObject haveProperty:GlobalObjectIsQueryable] &&
            [[self globalObject:sObject property:GlobalObjectKeyPrefix] isEqualToString:prefix] )
            return sObject;
    
    return nil;
}

- (UIImage *) imageForSObject:(NSString *)sObject {
    NSString *format = @"%@32.png";
    UIImage *defaultImage = [UIImage imageNamed:@"record.png"];
    
    NSDictionary *ob = [[SFVAppCache sharedSFVAppCache] describeGlobalsObject:sObject];
    sObject = [sObject lowercaseString];
        
    if( !ob )
        return defaultImage;    
    else if( [self doesGlobalObject:sObject haveProperty:GlobalObjectIsCustom] )
        sObject = @"custom";
    else if( [sObject rangeOfString:@"contactrole"].location != NSNotFound )
        sObject = @"contact";
    else if( [sObject isEqualToString:@"accountteammember"] )
        sObject = @"account";
    else if( [sObject isEqualToString:@"contentversion"] || [sObject isEqualToString:@"attachment"] )
        sObject = @"noteandattachment";
    else if( [sObject isEqualToString:@"contractlineitem"] || [sObject isEqualToString:@"servicecontract"] )
        sObject = @"contract";
    else if( [sObject isEqualToString:@"task"] )
        sObject = @"home";
    else if( [sObject isEqualToString:@"opportunitylineitem"] )
        sObject = @"opportunity";
    else if( [sObject isEqualToString:@"orderitem"] )
        sObject = @"order";
    else if( [sObject isEqualToString:@"casesolution"] )
        sObject = @"solution";
        
    UIImage *img = [UIImage imageNamed:[NSString stringWithFormat:format, sObject]];
    
    return [( img ? img : defaultImage ) imageAtScale];
}

#pragma mark - describing individual objects

- (BOOL)isPersonAccountEnabled {
    return [self describeForField:@"PersonContactId" onObject:@"Account"] != nil;
}

- (BOOL)doesObject:(NSString *)object haveProperty:(ObjectDescribeBooleanProperty)property {
    if( !objectDescribeCache )
        return NO;
    
    NSDictionary *ob = [objectDescribeCache objectForKey:object];
    
    if( !ob )
        return NO;
    
    NSString *key = nil;
    
    switch( property ) {
        case ObjectIsRecordTypeEnabled:
            return [self describeForField:kRecordTypeIdField onObject:object] != nil;
        case ObjectIsDeletable:
            key = @"deletable";
            break;
        case ObjectIsCreatable:
            key = @"createable";
            break;
        case ObjectIsUpdatable:
            key = @"updateable";
            break;
        case ObjectHasCustomNewRecordURL:
            // standard new pages end in /keyprefix/e
            return ( [self object:object stringProperty:ObjectNewURL]
                     && ![[self object:object stringProperty:ObjectNewURL] 
                          hasSuffix:[NSString stringWithFormat:@"%@/e",
                                [self globalObject:object property:GlobalObjectKeyPrefix]]] );
        case ObjectHasCustomEditRecordURL:
            // standard edit pages end in /{ID}/e
            return ( [self object:object stringProperty:ObjectEditURL] 
                     && ![[self object:object stringProperty:ObjectEditURL] hasSuffix:@"{ID}/e"] );
        case ObjectHasCustomDetailRecordURL:
            // standard detail pages end in /{ID}
            return ( [self object:object stringProperty:ObjectDetailURL] 
                     && ![[self object:object stringProperty:ObjectDetailURL] hasSuffix:@"/{ID}"] );
    }
    
    return [[ob objectForKey:key] boolValue];
}

- (NSString *)object:(NSString *)object stringProperty:(ObjectDescribeStringProperty)property {
    if( !objectDescribeCache )
        return NO;
    
    NSDictionary *ob = [objectDescribeCache objectForKey:object];
    
    if( !ob )
        return NO;
    
    NSString *keyPath = nil, *key = nil;
    
    switch( property ) {
        case ObjectNewURL:
            keyPath = @"urls.uiNewRecord";
            break;
        case ObjectDetailURL:
            keyPath = @"urls.uiDetailTemplate";
            break;
        case ObjectEditURL:
            keyPath = @"urls.uiEditTemplate";
            break;
    }
    
    if( keyPath )
        return [ob valueForKeyPath:keyPath];
    
    return [ob objectForKey:key];
}

- (NSDictionary *)describeForField:(NSString *)field onObject:(NSString *)object {
    if( !field || !object || !objectDescribeCache )
        return nil;
    
    return [[objectDescribeCache objectForKey:object] valueForKeyPath:[NSString stringWithFormat:@"%@.%@", 
                                                                       kFieldsKey, field]];
}

- (NSArray *)namesOfFieldsOnObject:(NSString *)object {
    if( !objectDescribeCache )
        return nil;
    
    NSDictionary *objectDesc = [objectDescribeCache objectForKey:object];
    
    if( !objectDesc )
        return nil;
    
    return [[objectDesc objectForKey:kFieldsKey] allKeys];
}

- (BOOL)doesField:(NSString *)field onObject:(NSString *)object haveProperty:(FieldDescribeBooleanProperty)property {
    NSDictionary *fieldDesc = [self describeForField:field onObject:object];
    
    if( !fieldDesc )
        return NO;
    
    NSString *key = nil;
    
    switch( property ) {
        case FieldIsCustom:
            key = @"custom";
            break;
        case FieldIsHTML:
            key = @"htmlFormatted";
            break;
        case FieldIsCreateable:
            key = @"createable";
            break;
        case FieldIsUpdateable:
            key = @"updateable";
            break;
        case FieldIsNameField:
            key = @"nameField";
            break;
        case FieldIsFormulaField:
            key = @"calculated";
            break;
        case FieldIsNillable:
            key = @"nillable";
            break;
        case FieldIsDependentPicklist:
            key = @"dependentPicklist";
            break;
        case FieldIsReferenceField:
            return [[self field:field onObject:object stringProperty:FieldType] isEqualToString:@"reference"];
        case FieldIsRestrictedPicklist:
            key = @"restrictedPicklist";
            break;
    }
    
    if( [fieldDesc objectForKey:key] )    
        return [[fieldDesc objectForKey:key] boolValue];
    
    return NO;
}

- (NSString *)field:(NSString *)field onObject:(NSString *)object stringProperty:(FieldDescribeStringProperty)property {
    NSDictionary *fieldDesc = [self describeForField:field onObject:object];
    
    if( !fieldDesc )
        return nil;
    
    NSString *key = nil;
    
    switch( property ) {
        case FieldName:
            key = @"name";
            break;
        case FieldLabel:
            key = @"label";
            break;
        case FieldType:
            key = @"type";
            break;
        case FieldDefaultValue:
            key = @"defaultValue";
            break;
        case FieldCalculatedFormula:
            key = @"calculatedFormula";
            break;
        case FieldInlineHelpText:
            key = @"inlineHelpText";
            break;
        case FieldDefaultValueFormula:
            key = @"defaultValueFormula";
            break;
        case FieldRelationshipName:
            key = @"relationshipName";
            break;
        case FieldRelationshipOrder:
            key = @"relationshipOrder";
            break;
        case FieldControllingFieldName:
            key = @"controllerName";
            break;
    }
    
    return [SFVAppCache valueOrEmptyStringForString:[fieldDesc objectForKey:key]];
}

- (NSArray *)field:(NSString *)field onObject:(NSString *)object arrayProperty:(FieldDescribeArrayProperty)property {
    NSDictionary *fieldDesc = [self describeForField:field onObject:object];
    
    if( !fieldDesc )
        return nil;
    
    NSString *key = nil;
    
    switch( property ) {
        case FieldReferenceTo:
            key = kReferenceToKey;
            break;
        case FieldPicklistValues:
            key = @"picklistValues";
            break;
    }
    
    return [[(NSArray *)[fieldDesc objectForKey:key] copy] autorelease];
}

- (NSInteger)field:(NSString *)field onObject:(NSString *)object numberProperty:(FieldDescribeNumberProperty)property {
    NSDictionary *fieldDesc = [self describeForField:field onObject:object];
    
    if( !fieldDesc )
        return 0;
    
    NSString *key = nil;
    
    switch( property ) {
        case FieldScale:
            key = @"scale";
            break;
        case FieldDigits:
            key = @"digits";
            break;
        case FieldLength:
            key = @"length";
            break;
        case FieldPrecision:
            key = @"precision";
            break;
    }
    
    return [[fieldDesc objectForKey:key] integerValue];
}

- (NSString *)nameFieldForsObject:(NSString *)sObject {
    if( !objectDescribeCache || !sObject )
        return [kNameField capitalizedString];
    
    if( [sObject isEqualToString:@"Name"] )
        return [kNameField capitalizedString];
    
    NSDictionary *desc = [objectDescribeCache objectForKey:sObject];
    
    if( desc )
        return [desc objectForKey:kNameFieldKey];
    
    return @"Id";
}

- (NSString *) nameForSObject:(NSDictionary *)object {
    if( [SFVUtil isEmpty:object] )
        return @"";
    
    NSString *objectType = [object objectForKey:kObjectTypeKey];
    
    if( !objectType )
        objectType = [self sObjectFromRecordId:[object objectForKey:@"Id"]];
    
    NSString *nameField = [self nameFieldForsObject:objectType];
        
    return [SFVAppCache valueOrEmptyStringForString:[object objectForKey:nameField]];
}

- (NSString *)descriptionFieldForObject:(NSString *)sObject {
    NSDictionary *fields = [NSDictionary dictionaryWithObjectsAndKeys:
                            @"Subject", @"Case",
                            @"Account.Name", @"Opportunity",
                            @"Account.Name", @"Contact",
                            @"ActivityDateTime", @"Event",
                            @"ActivityDate", @"Task",
                            @"ProductCode", @"Product2",
                            @"Account.Name", @"Contract",
                            @"Description", @"ContentVersion",
                            @"Type", @"Entitlement",
                            @"Company", @"Lead",
                            @"Description", @"ServiceContract",
                            nil];
    
    //NSString *field = [fields objectForKey:sObject];
    
    // Verify we have access
    /*if( [field rangeOfString:@"."].location == NSNotFound &&
       ![self describeForField:field onObject:sObject] )
        return nil;*/
    
    return [fields objectForKey:sObject];
}

- (NSString *)descriptionValueForRecord:(NSDictionary *)record {
    NSString *field = [self descriptionFieldForObject:[record objectForKey:kObjectTypeKey]];
    
    if( [field rangeOfString:@"."].location != NSNotFound )
        return [SFVAppCache valueOrEmptyStringForString:[record valueForKeyPath:field]];
    
    if( [[NSArray arrayWithObjects:@"date", @"datetime", nil] containsObject:[self field:field
                                                                                onObject:[record objectForKey:kObjectTypeKey]
                                                                          stringProperty:FieldType]] )
        return [[SFVUtil sharedSFVUtil] textValueForField:field withDictionary:record];
    
    return [SFVAppCache valueOrEmptyStringForString:[record objectForKey:field]];
}

- (NSArray *)relatedObjectsOnObject:(NSString *)object {
    if( !object || !objectDescribeCache )
        return nil;
    
    return [objectDescribeCache valueForKeyPath:[NSString stringWithFormat:@"%@.%@",
                                                 object, kRelatedObjectsArrayKey]];
}

- (NSArray *) shortFieldListForObject:(NSString *)sObject {
    NSMutableSet *fields = [NSMutableSet setWithObjects:@"Id", @"createddate", @"lastmodifieddate", nil];
    
    if( [self nameFieldForsObject:sObject] )
        [fields addObject:[self nameFieldForsObject:sObject]];
    
    if( [self descriptionFieldForObject:sObject] )
        [fields addObject:[self descriptionFieldForObject:sObject]];
    
    if( [self doesObject:sObject haveProperty:ObjectIsRecordTypeEnabled] )
        [fields addObject:kRecordTypeIdField];
    
    // Users, Leads and Contacts have firstname/lastname
    if( [[NSArray arrayWithObjects:@"Lead", @"Contact", @"User", nil] containsObject:sObject] )
        [fields addObjectsFromArray:[NSArray arrayWithObjects:@"FirstName", @"LastName", nil]];
    
    if( [sObject isEqualToString:@"Account"] && [self isPersonAccountEnabled] )
        [fields addObjectsFromArray:[NSArray arrayWithObjects:@"PersonContactId", @"IsPersonAccount", nil]];
    
    if( [self isChatterEnabled]
       && ( [sObject isEqualToString:@"User"] || [sObject isEqualToString:@"CollaborationGroup"] )) {
        [fields addObject:@"SmallPhotoUrl"];
        
        if( [sObject isEqualToString:@"CollaborationGroup"] )
            [fields addObjectsFromArray:[NSArray arrayWithObjects:@"MemberCount", @"CollaborationType", nil]];       
    }
    
    return [fields allObjects];
}

#pragma mark - misc

- (NSString *) webURLForURL:(NSString *)u {
    return [NSString stringWithFormat:@"%@/secur/frontdoor.jsp?sid=%@&retURL=%@",
            [SimpleKeychain load:instanceURLKey],
            [[SFVUtil sharedSFVUtil] sessionId],
            u];
}

@end
