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

#import "CreateRecordButton.h"
#import "SFVUtil.h"
#import "SFVAppCache.h"
#import "SFVAsync.h"
#import "DetailViewController.h"

@implementation CreateRecordButton

@synthesize detailViewController, fieldDictionary;

#pragma mark - checks

+ (BOOL)objectCanBeCreated:(NSString *)object {
    // skip certain objects that require special handling
    if( [[NSArray arrayWithObjects:@"OpportunityLineItem", @"QuoteLineItem", nil] containsObject:object] )
        return NO;
    
    // Special handling for casecomment
    if( [object isEqualToString:@"CaseComment"] )
        return YES;
    
    return [[SFVAppCache sharedSFVAppCache] doesObject:object
                                          haveProperty:ObjectIsCreatable]
           && [[SFVAppCache sharedSFVAppCache] doesGlobalObject:object
                                                   haveProperty:GlobalObjectIsLayoutable];
}

#pragma mark - init

+ (id)buttonForObject:(NSString *)object {
    return [CreateRecordButton buttonForObject:object text:nil fields:nil];
}

+ (id)buttonForObject:(NSString *)object text:(NSString *)text {
    return [CreateRecordButton buttonForObject:object text:text fields:nil];
}

+ (id)buttonForObject:(NSString *)object text:(NSString *)text fields:(NSDictionary *)fields {
    CreateRecordButton *button = [CreateRecordButton alloc];
    
    if( text )
        button = [button initWithTitle:text
                                 style:UIBarButtonItemStyleBordered
                                target:button
                                action:@selector(tappedButton:)];
    else
        button = [button initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                              target:button
                                              action:@selector(tappedButton:)];
    
    NSMutableDictionary *dict = nil;
    
    if( fields )
        dict = [NSMutableDictionary dictionaryWithDictionary:fields];
    else
        dict = [NSMutableDictionary dictionary];
    
    [dict setObject:object forKey:kObjectTypeKey];
    
    button.fieldDictionary = dict;
    
    return [button autorelease];
}

- (void)dealloc {
    self.detailViewController = nil;
    self.fieldDictionary = nil;
    
    [super dealloc];
}

#pragma mark - POOSH BUTTON

- (void)tappedButton:(id)sender {
    if( [[SFVAppCache sharedSFVAppCache] doesObject:[fieldDictionary objectForKey:kObjectTypeKey]
                                       haveProperty:ObjectHasCustomNewRecordURL] )
        [self.detailViewController addFlyingWindow:FlyingWindowWebView
                                           withArg:[[SFVAppCache sharedSFVAppCache] object:[fieldDictionary objectForKey:kObjectTypeKey]
                                                                            stringProperty:ObjectNewURL]];
    else
        [self.detailViewController addFlyingWindow:FlyingWindowRecordEditor
                                           withArg:fieldDictionary];
}

@end
