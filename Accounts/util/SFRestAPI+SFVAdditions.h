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

// Special Salesforce Viewer-specific additions to the SFRestAPI

#import <Foundation/Foundation.h>
#import "SFRestAPI.h"
#import "SFRestAPI+Blocks.h"

// If yes, caches sObject describes and will return cached results always instead of re-describing
#define kObjectDescribeCacheEnabled YES

@interface SFRestAPI (SFVAdditions) <SFRestDelegate>

/**
 * Executes a global describe.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) SFVperformDescribeGlobalWithFailBlock:(SFRestFailBlock)failBlock 
                                            completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

/**
 * Executes a describe on a single sObject.
 * @param objectType the API name of the object to describe.
 * @param failBlock the block to be executed when the request fails (timeout, cancel, or error)
 * @param completeBlock the block to be executed when the request successfully completes
 * @return the newly sent SFRestRequest
 */
- (SFRestRequest *) SFVperformDescribeWithObjectType:(NSString *)objectType 
                                           failBlock:(SFRestFailBlock)failBlock 
                                       completeBlock:(SFRestDictionaryResponseBlock)completeBlock;

@end
