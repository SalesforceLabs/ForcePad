/* 
 * Copyright (c) 2011, salesforce.com, inc.
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

#import "NSURL+Additions.h"
#import "SFVUtil.h"

FIX_CATEGORY_BUG(Additions);

@implementation NSURL (Additions)

- (NSString *)parameterWithName:(NSString *)name
{
    NSString *urlString = [self absoluteString];
    NSString *value = nil;

    NSString *regex = [NSString stringWithFormat:@"%@=[^\\s&]+", name];
    
    NSRange regexRange = [urlString rangeOfString:regex options:NSRegularExpressionSearch];
    if (regexRange.location != NSNotFound) 
    {
        NSString *valueFullString = [urlString substringWithRange:regexRange];
        NSInteger variableNameLength = [name length]+1;
        NSString *valueString = [valueFullString substringWithRange:NSMakeRange(variableNameLength, regexRange.length - variableNameLength)];
        value = [valueString stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    }
    return value;
}

@end
