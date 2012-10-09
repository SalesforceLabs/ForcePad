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
#import "OAuthLoginHostPicker.h"
#import "OAuthCustomHostCreator.h"

// keys for login
#define OAuthClientID               @"Your OAuth Key"
#define OAuthConsumerSecret         @"Your OAuth secret"

@interface OAuthViewController : UIViewController <UIWebViewDelegate, UIPopoverControllerDelegate, 
            OAuthLoginHostPickerDelegate, UINavigationControllerDelegate, OAuthCustomHostCreatorDelegate> {
    SEL action;
    NSString *accessToken;
    NSString *refreshToken;
    NSString *instanceUrl;
    
    UIBarButtonItem *loginHostGear;
    UIBarButtonItem *loginRefresh;
    UIPopoverController *popoverController;
}

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector;

@property (readonly) NSString *accessToken;
@property (readonly) NSString *refreshToken;
@property (readonly) NSString *instanceUrl;

@property (nonatomic, retain) UIWebView *webView;

@property (nonatomic, assign) id target;

+ (NSString *) OAuthClientId;
+ (NSString *) redirectURL;
+ (NSString *) HTMLStringForError:(NSString *)error description:(NSString *)description;

- (void) reloadWebView;
- (void) dismissPopover;

- (IBAction) tappedLoginHostGear:(id)sender;

// cache destruction
+ (void) wipeLoginCaches;
+ (void) removeApplicationLibraryDirectoryWithDirectory:(NSString *)dirName;

@end
