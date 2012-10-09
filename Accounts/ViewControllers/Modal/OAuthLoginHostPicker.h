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

@protocol OAuthLoginHostPickerDelegate;

#define kLoginHostIndexKey      @"login_host"
#define kCustomHostArrayKey     @"custom_hosts"

#define kProdLoginURL           @"https://login.salesforce.com/"
#define kSandboxLoginURL        @"https://test.salesforce.com/"

@interface OAuthLoginHostPicker : UITableViewController {}

@property (nonatomic, assign) id <OAuthLoginHostPickerDelegate> delegate;

// Standard custom hosts to list in the tableview
typedef enum LoginHostTypes {
    LoginProduction = 0,
    LoginSandbox,
    LoginNumStandardTypes,
} LoginHostType;

// Each custom host is an NSArray with the following format
typedef enum CustomLoginHost {
    CustomHostURL = 0,
    CustomHostName,
    CustomHostNumFields
} CustomLoginHost;

- (id) initWithStyle:(UITableViewStyle)style;

// Custom hosts
+ (NSArray *) customHosts;
+ (NSUInteger) indexOfCurrentLoginHost;
+ (NSString *) URLForCurrentLoginHost;
+ (NSString *) nameForCurrentLoginHost;

// actions
- (IBAction) tappedEdit:(id)sender;
- (IBAction) tappedAddHost:(id)sender;
- (void) reloadAndResize;

@end

// START:Delegate
@protocol OAuthLoginHostPickerDelegate <NSObject>

@required

- (void) OAuthLoginHost:(OAuthLoginHostPicker *)controller didSelectLoginHostAtIndex:(NSInteger)index;
- (void) OAuthLoginHostDidTapAddCustomHostButton:(OAuthLoginHostPicker *)controller;

@end
// END:Delegate
