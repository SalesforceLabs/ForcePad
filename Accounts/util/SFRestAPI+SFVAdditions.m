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
#import <objc/runtime.h>
#import "SFRestAPI+SFVAdditions.h"
#import "SFRestAPI.h"
#import "SFVUtil.h"

FIX_CATEGORY_BUG(SFVAdditions);

@implementation SFRestAPI (SFVAdditions)

- (SFRestRequest *) SFVperformDescribeGlobalWithFailBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {    
    // SFV customization; we want to cache the result of every global describe.
    SFRestDictionaryResponseBlock newBlock = ^(NSDictionary *results) {
        [[SFVAppCache sharedSFVAppCache] cacheGlobalDescribeResults:results];
        
        if( completeBlock )
            completeBlock( results );
    };
    
    return [[SFRestAPI sharedInstance] performDescribeGlobalWithFailBlock:failBlock
                                                            completeBlock:newBlock];
}

- (SFRestRequest *) SFVperformDescribeWithObjectType:(NSString *)objectType failBlock:(SFRestFailBlock)failBlock completeBlock:(SFRestDictionaryResponseBlock)completeBlock {
    
    // Intercept; read cache first
    if( kObjectDescribeCacheEnabled ) {
        NSDictionary *cachedResult = [[SFVAppCache sharedSFVAppCache] cachedDescribeForObject:objectType];
        
        if( completeBlock && cachedResult ) {
            NSLog(@"** CACHE READ FOR OBJECT: %@", objectType);
            completeBlock( cachedResult );
            return nil;
        }
    }

    // SFV customization; we want to cache the result of every object describe.
    SFRestDictionaryResponseBlock newBlock = ^(NSDictionary *results) {
        [[SFVAppCache sharedSFVAppCache] cacheDescribeObjectResult:results];
        
        if( completeBlock )
            completeBlock( results );
    };
    
    return [[SFRestAPI sharedInstance] performDescribeWithObjectType:objectType
                                                           failBlock:failBlock
                                                       completeBlock:newBlock];
}

@end
