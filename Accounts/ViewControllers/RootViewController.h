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
#import "zkSforce.h"
#import "PullRefreshTableViewController.h"
#import "SubNavViewController.h"
#import "SFVUtil.h"
#import "MGSplitViewController.h"
#import "IASKAppSettingsViewController.h"
#import "SFVEULAAcceptController.h"
#import "SFVFirstRunController.h"
#import "SFRestAPI.h"

@class DetailViewController;
@class OAuthViewController;

// Keys for login
#define PartnerTokenID      @"Your Partner Token"

// Keys for storing login details in the keychain
#define refreshTokenKey     @"refreshToken2_1"
#define instanceURLKey      @"instanceURL"
#define accessTokenKey      @"accessToken2_1"

// Keys for storing in NSUserDefaults
#define firstRunKey         @"firstRunComplete_20"
#define EULAAcceptKey       @"acceptedEULA_2_1"
#define emptyFieldsKey      @"show_empty_fields"

#define AppPickerApps       [NSArray arrayWithObjects:NSNumberFromInt(SubNavAppPicker), NSNumberFromInt(SubNavAllObjects), NSNumberFromInt(SubNavFavoriteObjects), nil]

@interface RootViewController : UINavigationController <MGSplitViewControllerDelegate, IASKSettingsDelegate, 
                UIPopoverControllerDelegate, UINavigationControllerDelegate, EULADelegate, FirstRunDelegate> {
    int totalLoginMetadataOperations, completedLoginMetadataOperations;
}

@property (nonatomic, retain) ZKSforceClient *client;
@property (nonatomic, retain) IBOutlet DetailViewController *detailViewController;
@property (nonatomic, retain) UIPopoverController *popoverController;

@property (nonatomic, assign) IBOutlet MGSplitViewController *splitViewController;

// Class methods
+ (BOOL) isPortrait;
+ (BOOL) hasStoredOAuthRefreshToken;

// Main app entry point once launching has finished
- (void) appFinishedLaunching;

// Subnav management

// Names of available apps to switch to
- (NSArray *) availableApps;
- (void) pushSubNavControllerForAppAtIndex:(NSUInteger)index;
- (void) pushSubNavControllerWithType:(enum SubNavTableType)subNavType animated:(BOOL)animated;
- (void) pushSubNavControllerForSObject:(NSString *)sObject;
- (void) pushSubNavControllerWithObjectListType:(enum SubNavObjectListType)objectListType sObject:(NSString *)sObject;
- (void) popAllSubNavControllers;
- (void) subNavSelectAccountWithId:(NSString *)recordId;
- (void) popToHome;
- (void) refreshAllSubNavs;
- (SubNavViewController *) currentSubNavViewController;
- (NSArray *)viewControllers;

- (void) updateBarButtonItemWithButton:(UIBarButtonItem *)barButtonItem;

// Loading modal
- (void) showLoadingModal;
- (void) hideLoadingModal;

// Failsafe logout switches
- (void) performLogoutWithDelay:(float)delay;
- (void) cancelPerformLogoutWithDelay;

// Login
- (void) hideLoginAnimated:(BOOL)animated;
- (void) loginFromCallbackUrl:(NSURL *)url;
- (void) loginOAuth:(OAuthViewController *)controller error:(NSError *)error;
- (void) logInOrOut:(id)sender;
- (BOOL) isLoggedIn;
- (NSString *) loginAction;
- (void) appDidLogin;
- (void) appDidCompleteLoginMetadataOperation;
- (IBAction) showSettings:(id)sender;
- (void) doLogout;
- (OAuthViewController *) loginController;
- (void) showLogin;

// First-run
- (void) showFirstRunModal:(BOOL)showEULA;

@end
