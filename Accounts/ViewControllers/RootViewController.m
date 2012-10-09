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

#import "SFVAppDelegate.h"
#import "RootViewController.h"
#import "SFVUtil.h"
#import "DetailViewController.h"
#import "SubNavViewController.h"
#import "PRPSmartTableViewCell.h"
#import "PRPAlertView.h"
#import "OAuthViewController.h"
#import "MGSplitViewController.h"
#import "zkSforce.h"
#import "DSActivityView.h"
#import "IASKSettingsReader.h"
#import "IASKSpecifier.h"
#import "SFVFirstRunController.h"
#import "SimpleKeychain.h"
#import "PRPConnection.h"
#import "CloudyLoadingModal.h"
#import "SFVAppCache.h"
#import "NSURL+Additions.h"
#import "SFVAsync.h"
#import "SFOAuthCoordinator.h"
#import "SFRestAPI+SFVAdditions.h"

@implementation RootViewController

@synthesize detailViewController, client, popoverController, splitViewController;

static int const kExtraLoginOperations = 2;

#pragma mark - init and dealloc

- (void)dealloc {
    [detailViewController release];
    [client release];
    [popoverController release];
    [super dealloc];
}

- (void) awakeFromNib {
    [super awakeFromNib];
    
    self.delegate = self;
        
    [self.navigationBar setBarStyle:UIBarStyleBlackOpaque];  
    self.contentSizeForViewInPopover = CGSizeMake( masterWidth, 704 );
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
    
    self.client = [[[ZKSforceClient alloc] init] autorelease];
    [client setClientId:PartnerTokenID];
}

- (void) appFinishedLaunching {   
    NSLog(@"app finished launching");
    
    if( ![[NSUserDefaults standardUserDefaults] boolForKey:EULAAcceptKey] )
        [self showFirstRunModal:YES];
    else if( ![[NSUserDefaults standardUserDefaults] boolForKey:firstRunKey] )
        [self showFirstRunModal:NO];
    else
        [self logInOrOut:nil];
}

#pragma mark - subnav management

- (void) pushSubNavControllerWithType:(enum SubNavTableType)subNavType animated:(BOOL)animated {
    if( subNavType == SubNavDummyController ) {
        UIViewController *dummy = [[UIViewController alloc] init];
        [self pushViewController:dummy animated:NO];
        [dummy release];
        return;
    }
    
    SubNavViewController *snvc = [[SubNavViewController alloc] initWithTableType:subNavType];
    snvc.rootViewController = self;
    snvc.detailViewController = self.detailViewController;
    self.detailViewController.subNavViewController = snvc;
    
    [snvc refresh];
    [self pushViewController:snvc animated:animated];
    
    [snvc release];
}

- (void) pushSubNavControllerForAppAtIndex:(NSUInteger)index {
    SubNavViewController *snvc = [[SubNavViewController alloc] initWithTableType:SubNavAppTabPicker];
    snvc.rootViewController = self;
    snvc.detailViewController = self.detailViewController;
    self.detailViewController.subNavViewController = snvc;
    
    snvc.appIndex = index;
    
    [snvc refresh];
    [self pushViewController:snvc animated:YES];
    
    [snvc release];
}

- (void) pushSubNavControllerForSObject:(NSString *)sObject {
    SubNavViewController *snvc = [[SubNavViewController alloc] initWithTableType:SubNavObjectListTypePicker];
    snvc.rootViewController = self;
    snvc.detailViewController = self.detailViewController;
    snvc.sObjectType = sObject;
    
    self.detailViewController.subNavViewController = snvc;
    [snvc refresh];
    
    [self pushViewController:snvc animated:YES];
    [snvc release];
}

- (void) pushSubNavControllerWithObjectListType:(enum SubNavObjectListType)objectListType sObject:(NSString *)sObject {
    SubNavViewController *snvc = [[SubNavViewController alloc] initWithTableType:SubNavListOfRemoteRecords];
    snvc.rootViewController = self;
    snvc.detailViewController = self.detailViewController;
    snvc.subNavObjectListType = objectListType;
    snvc.sObjectType = sObject;
    
    self.detailViewController.subNavViewController = snvc;
    
    [snvc performSelector:@selector(refresh) withObject:nil afterDelay:0.5];
    [self pushViewController:snvc animated:YES];
    [snvc release];
}

- (void) popToHome {
    if( ![self isLoggedIn] )
        return;
    
    if( ![[self currentSubNavViewController] isMemberOfClass:[SubNavViewController class]] ||
            [self currentSubNavViewController].subNavTableType != SubNavAppTabPicker ) {
        [self popToRootViewControllerAnimated:NO];
        [self pushSubNavControllerWithType:SubNavDummyController animated:NO];    
        
        NSUInteger selectedIndex = [[SFVAppCache sharedSFVAppCache] indexOfSelectedApp];
        
        [self pushSubNavControllerWithType:SubNavAppPicker animated:NO];
        [self pushSubNavControllerForAppAtIndex:selectedIndex];
    }
}

- (void) popAllSubNavControllers {
    [self popToRootViewControllerAnimated:NO];
}

- (SubNavViewController *) currentSubNavViewController {
    return (SubNavViewController *)[self visibleViewController];
}

- (void) subNavSelectAccountWithId:(NSString *)recordId {
    UIViewController *vc = [self currentSubNavViewController];
    
    if( [vc isMemberOfClass:[SubNavViewController class]] )
        [(SubNavViewController *)vc selectAccountWithId:recordId];
}

- (NSArray *) availableApps {
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[AppPickerApps count] - 1];
    int counter = 0;
    SubNavViewController *vc = [self currentSubNavViewController];
            
    for( ; counter < [AppPickerApps count]; counter++ ) {
        int mapped = [[AppPickerApps objectAtIndex:counter] intValue];
        
        if( mapped != vc.subNavTableType )
            [ret addObject:NSNumberFromInt(mapped)];
    }
    
    return ret;
}

- (NSArray *) viewControllers {
    NSMutableArray *ret = [NSMutableArray array];
    
    for( UIViewController *vc in [super viewControllers] )
        if( [vc isKindOfClass:[SubNavViewController class]] )
            [ret addObject:vc];
    
    return ret;
}

- (void)refreshAllSubNavs {
    for( UIViewController *cont in [self viewControllers] )
        if( [cont isKindOfClass:[SubNavViewController class]] )
            [(SubNavViewController *)cont refresh];
}

- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration: 0.5];
    
    SubNavViewController *viewController = (SubNavViewController *)[super popViewControllerAnimated:NO];
    
    if( [viewController respondsToSelector:@selector(animationTransitionForPop)] )
        [UIView setAnimationTransition:[viewController animationTransitionForPop]
                               forView:self.view 
                                 cache:NO];
    
    [UIView commitAnimations];
    
    [self subNavSelectAccountWithId:nil];
    self.detailViewController.subNavViewController = (SubNavViewController *)viewController;
    
    [self updateBarButtonItemWithButton:nil];
    
    return viewController;
}

- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if( [[self currentSubNavViewController] respondsToSelector:@selector(resignResponder)] )
        [[self currentSubNavViewController] resignResponder];
    
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration: 0.5];
    
    if( [viewController respondsToSelector:@selector(animationTransitionForPush)] )
        [UIView setAnimationTransition:[(SubNavViewController *)viewController animationTransitionForPush]
                               forView:self.view 
                                 cache:NO];
    
    [super pushViewController:viewController animated:animated];
    
    self.detailViewController.subNavViewController = (SubNavViewController *)viewController;
    
    [self updateBarButtonItemWithButton:nil];
    
    [UIView commitAnimations];
}

#pragma mark - navigation controller delegate

- (void)navigationController:(UINavigationController *)navigationController willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    viewController.contentSizeForViewInPopover = CGSizeMake( masterWidth, 704 );
}

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    self.detailViewController.subNavViewController = (SubNavViewController *)viewController;
}

#pragma mark - logout failsafes

- (void) performLogoutWithDelay:(float)delay {
    [self cancelPerformLogoutWithDelay];
    [self performSelector:@selector(doLogout) withObject:nil afterDelay:delay];
}

- (void) cancelPerformLogoutWithDelay {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(doLogout) object:nil];
}

#pragma mark - loading modals

- (void) showLoadingModal {
    CloudyLoadingModal *clm = [[CloudyLoadingModal alloc] init];
    
    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:clm];
    nav.modalPresentationStyle = clm.modalPresentationStyle;
    nav.modalTransitionStyle = clm.modalTransitionStyle;
    nav.navigationBar.tintColor = AppSecondaryColor;
    
    clm.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                          target:self
                                                                                          action:@selector(doLogout)] autorelease];
    [clm release];
    
    [self.splitViewController presentModalViewController:nav animated:YES];
    [nav release];
}

- (void) hideLoadingModal {
    if( self.splitViewController.modalViewController
        && [self.splitViewController.modalViewController isKindOfClass:[UINavigationController class]]
        && [[((UINavigationController *)self.splitViewController.modalViewController) visibleViewController] isKindOfClass:[CloudyLoadingModal class]] )
        [self.splitViewController dismissModalViewControllerAnimated:YES];
}

#pragma mark - Split view controller

+ (BOOL)isPortrait {    
    return UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]);
}


- (void) updateBarButtonItemWithButton:(UIBarButtonItem *)barButtonItem {    
    if( !barButtonItem )
        barButtonItem = self.detailViewController.browseButton;
    
    if( !barButtonItem )
        return;
    
    barButtonItem.title = NSLocalizedString(@"Records", @"Records");
    
    UIViewController *controller = [self currentSubNavViewController];
    
    if( [controller respondsToSelector:@selector(subNavTableType)] )
        switch( [self currentSubNavViewController].subNavTableType ) {
            case SubNavAppTabPicker:
                barButtonItem.title = NSLocalizedString(@"Tabs", @"Tabs");
                break;
            case SubNavAllObjects:
                barButtonItem.title = NSLocalizedString(@"Objects", @"Objects");
                break;
            case SubNavObjectListTypePicker:
                barButtonItem.title = NSLocalizedString(@"Lists", @"Lists");
                break;
            case SubNavAppPicker:
                barButtonItem.title = NSLocalizedString(@"Apps", @"Apps");
                break;
            case SubNavFavoriteObjects:
                barButtonItem.title = NSLocalizedString(@"Favorites", @"Favorites");
                break;
            default: 
                barButtonItem.title = NSLocalizedString(@"Records",@"Records button");
        }
        
    if( [RootViewController isPortrait] )
        [self.detailViewController setPopoverButton:barButtonItem];
}

- (void)splitViewController:(MGSplitViewController *)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem *)barButtonItem forPopoverController: (UIPopoverController *)pc {
    self.popoverController = pc;
    pc.popoverContentSize = CGSizeMake( masterWidth, 704 );
    
    [self updateBarButtonItemWithButton:barButtonItem];
}

- (void)splitViewController:(MGSplitViewController *)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem {  
        
    self.popoverController = nil;
    [self.detailViewController setPopoverButton:nil];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

#pragma mark - log in / log out

- (void)logInOrOut:(id)sender {   
    if( self.popoverController )
        [self.popoverController dismissPopoverAnimated:YES];
    
    // log in
    if( ![self isLoggedIn] ) {           
        if( [[self class] hasStoredOAuthRefreshToken] ) {               
            [self showLoadingModal];
            
            // Logout fallback
            [self performLogoutWithDelay:60];
            
            // use our saved OAuth token  
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,0), ^(void) {
                @try {
                    [client loginWithRefreshToken:[SimpleKeychain load:refreshTokenKey]
                                          authUrl:[NSURL URLWithString:[SimpleKeychain load:instanceURLKey]]
                                 oAuthConsumerKey:[OAuthViewController OAuthClientId]];
                } @catch( NSException *e ) {                        
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self cancelPerformLogoutWithDelay];
                        [[SFVUtil sharedSFVUtil] receivedException:e];
                        
                        [self doLogout];
                    });
                    
                    return;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    [self cancelPerformLogoutWithDelay];

                    if( [client loggedIn] ) {
                        NSLog(@"OAuth session successfully resumed");
                                                
                        [self appDidLogin];  
                    } else {
                        // OAuth failed for some reason
                        NSLog(@"OAuth session failed to resume");
                        [self performSelector:@selector(hideLoadingModal) withObject:nil afterDelay:3.0];
                        [self performLogoutWithDelay:3.5];
                    }
                });
            });
        } else
            [self showLogin];      
    } else { 
        // are you sure you want to log out?
        [PRPAlertView showWithTitle:NSLocalizedString(@"Log Out",@"Log Out")
                            message:[NSString stringWithFormat:@"%@ %@?", 
                                     NSLocalizedString(@"Log out",@"Log out"),
                                     [[[[SFVUtil sharedSFVUtil] client] getUserInfo] userName]] 
                        cancelTitle:NSLocalizedString(@"Cancel",@"Cancel")
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"Log Out",@"Log Out")
                         otherBlock:^(void) {
                             [self doLogout];
            }];
    }
}

// Logging in with OAuth and NOT refreshing an existing OAuth key
- (void) loginFromCallbackUrl:(NSURL *)url {
    @try {
        [client loginFromOAuthCallbackUrl:[url absoluteString] oAuthConsumerKey:[OAuthViewController OAuthClientId]];
    } @catch( NSException *e ) {
        [[SFVUtil sharedSFVUtil] receivedException:e];
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert",@"Alert")
                            message:NSLocalizedString(@"Failed to authenticate.", @"Generic OAuth failure")
                        buttonTitle:NSLocalizedString(@"OK", @"OK")];
        
        [self doLogout];
        return;
    }
    
    if( [client loggedIn] ) {
        NSLog(@"logged in with oauth callback");    
        
        NSString *urlString = [url absoluteString];
        NSRange range = [urlString rangeOfString:OAUTH_CALLBACK];
        
        if (range.length > 0 && range.location == 0) {            
            NSURL *u = [[NSURL alloc] initWithString:urlString];
            
            NSString * newInstanceURL = [u parameterWithName:@"instance_url"];
            if (newInstanceURL)
                [SimpleKeychain save:instanceURLKey data:newInstanceURL];
            
            NSString *newRefreshToken = [u parameterWithName:@"refresh_token"];
            if (newRefreshToken)
                [SimpleKeychain save:refreshTokenKey data:newRefreshToken];
            
            NSString *newAccessToken = [u parameterWithName:@"access_token"];
            if (newAccessToken)
                [SimpleKeychain save:accessTokenKey data:newAccessToken];
            
            [u release];
        }
        
        [self hideLoginAnimated:NO];
        [self showLoadingModal];
        [self appDidLogin];
    } else {
        NSLog(@"error logging in with oauth");
        [self hideLoginAnimated:YES];
        [self doLogout];
    }
}

- (void)loginOAuth:(OAuthViewController *)controller error:(NSError *)error {    
    if ([controller refreshToken] && !error) {   
        @try {
            [client loginWithRefreshToken:[controller refreshToken] 
                              authUrl:[NSURL URLWithString:[controller instanceUrl]] 
                     oAuthConsumerKey:[OAuthViewController OAuthClientId]];
        } @catch( NSException *e ) {
            [[SFVUtil sharedSFVUtil] receivedException:e];
            
            [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                message:[e reason]
                            cancelTitle:nil
                            cancelBlock:nil
                             otherTitle:NSLocalizedString(@"OK", nil)
                             otherBlock:^(void) {
                                 [self doLogout];
                             }];
            return;
        }
        
        if( [client loggedIn] ) {
            NSLog(@"logged in with oauth");  
                        
            [SimpleKeychain save:refreshTokenKey data:[controller refreshToken]];
            [SimpleKeychain save:instanceURLKey data:[controller instanceUrl]];
            
            [self hideLoginAnimated:NO];
            [self showLoadingModal];
            [self appDidLogin];
        } else {
            NSLog(@"error logging in with oauth");
            [self hideLoginAnimated:YES];
            [self doLogout];
        }
        
    } else if (error) {
        [[SFVUtil sharedSFVUtil] receivedAPIError:error];
        [self hideLoginAnimated:YES];
        [self doLogout];
    }
}

- (void)hideLoginAnimated:(BOOL)animated {
    [self.splitViewController dismissModalViewControllerAnimated:animated];
    [OAuthViewController wipeLoginCaches];
}

- (BOOL) isLoggedIn {
    return [client loggedIn];
}

- (NSString *) loginAction {
    if( [self isLoggedIn] )
        return NSLocalizedString(@"Log Out", @"Log Out action");
    
    return NSLocalizedString(@"Log In", @"Log In action");
}

- (void) appDidLogin {    
    NSLog(@"app did login");  
    
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:GlobalObjectOrderingKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
                    
    // Grab my user info
    ZKUserInfo *userinfo = nil;
    
    @try {
        userinfo = [client getUserInfo];
        [client setUserInfo:userinfo]; 
    } @catch( NSException *e ) {
        [[SFVUtil sharedSFVUtil] receivedException:e];
        
        [self doLogout];
        
        [PRPAlertView showWithTitle:@"Alert"
                            message:[e description]
                        buttonTitle:@"OK"];
        
        return;
    }        
    
    [[SFAnalytics sharedInstance] tagEventOfType:SFVUserLoggedIn 
                                      attributes:[NSDictionary dictionaryWithObject:[OAuthLoginHostPicker nameForCurrentLoginHost]
                                                                                            forKey:@"Login Host"]];
    
    [[SFVUtil sharedSFVUtil] setClient:client];
    
    // REST - set up our coordinator
    SFOAuthCredentials *creds = [[SFOAuthCredentials alloc] initWithIdentifier:@"RESTLogin"
                                                                      clientId:[OAuthViewController OAuthClientId]
                                                                     encrypted:YES];
    creds.refreshToken = [SimpleKeychain load:refreshTokenKey];
    creds.instanceUrl = [NSURL URLWithString:[SimpleKeychain load:instanceURLKey]];  
    creds.accessToken = [[SFVUtil sharedSFVUtil] sessionId];
        
    SFOAuthCoordinator *coordinator = [[SFOAuthCoordinator alloc] initWithCredentials:creds];
    [creds release];
    
    [[SFRestAPI sharedInstance] setCoordinator:coordinator];
    [coordinator release];
    [[SFRestAPI sharedInstance] setApiVersion:@"v25.0"];
    // END - REST setup
    
    // Metadata
    completedLoginMetadataOperations = 0;
    totalLoginMetadataOperations = 0;
    
    [[SFRestAPI sharedInstance] SFVperformDescribeGlobalWithFailBlock:^(NSError *err) {
                                                            [self doLogout];
        
                                                            [PRPAlertView showWithTitle:@"Alert"
                                                                                message:[[err userInfo] objectForKey:@"message"]
                                                                            buttonTitle:@"OK"];
                                                        }
                                                     completeBlock:^(NSDictionary *results) {
                                                         // describe every feed-enabled object for great SOSL justice
                                                         if( [[SFVAppCache sharedSFVAppCache] isChatterEnabled] )                                                             
                                                             for( NSString *object in [[SFVAppCache sharedSFVAppCache] allFeedEnabledSObjects] ) {
                                                                 totalLoginMetadataOperations++;
                                                                 [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:object
                                                                                                                 failBlock:^(NSError *e) {
                                                                                                                     NSLog(@"ERROR %@", e);
                                                                                                                     [self appDidCompleteLoginMetadataOperation];
                                                                                                                 }
                                                                                                             completeBlock:^(NSDictionary *complete) {
                                                                                                                 [self appDidCompleteLoginMetadataOperation];
                                                                                                             }];
                                                             }
                                                         
                                                         [self appDidCompleteLoginMetadataOperation];
                                                     }];
    
    [SFVAsync describeTabsWithFailBlock:^(NSException *ex) {
                                [self doLogout];
        
                                [PRPAlertView showWithTitle:@"Alert"
                                                    message:[ex description]
                                                buttonTitle:@"OK"];
                            }
                          completeBlock:^(NSArray *tabSets) {
                              [[SFVAppCache sharedSFVAppCache] cacheTabSetResults:tabSets];
                              [self appDidCompleteLoginMetadataOperation];
                          }];
    
    // Logout fallback
    [self performLogoutWithDelay:45];
}

// Delay completing the login until crucial metadata operations, namely describing Account
// and its layout, are complete.
- (void) appDidCompleteLoginMetadataOperation {
    // if you've fast fingers on the cancel button...
    if( ![self isLoggedIn] )
        return;
    
    completedLoginMetadataOperations++;
        
    if( completedLoginMetadataOperations < totalLoginMetadataOperations + kExtraLoginOperations )
        return;
    
    [self cancelPerformLogoutWithDelay];
    
    if( self.splitViewController.modalViewController 
        && [self.splitViewController.modalViewController isKindOfClass:[UINavigationController class]] )
        [((UINavigationController *)self.splitViewController.modalViewController).navigationBar.topItem setLeftBarButtonItem:nil animated:YES];
    
    NSLog(@"app did login async complete");
    
    [self popToHome];    

    [self.detailViewController eventLogInOrOut]; 
    [self performSelector:@selector(updateBarButtonItemWithButton:) withObject:nil afterDelay:0.5f];
    [self performSelector:@selector(hideLoadingModal) withObject:nil afterDelay:1.0];
}

- (void) doLogout {
    NSLog(@"app did logout");
    
    [[SFAnalytics sharedInstance] tagEventOfType:SFVUserLoggedOut attributes:nil];
    
    completedLoginMetadataOperations = 0;
    totalLoginMetadataOperations = 0;
    
    [self cancelPerformLogoutWithDelay];
    [self hideLoginAnimated:NO];
    
    // Perform actual logout
    [client setAuthenticationInfo:nil];
    [client setUserInfo:nil];
    [client flushCachedDescribes];
    
    // Wipe our stored access and refresh tokens
    [SimpleKeychain delete:refreshTokenKey];
    [SimpleKeychain delete:instanceURLKey];
    [SimpleKeychain delete:accessTokenKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:GlobalObjectOrderingKey];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:RecentRecords];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    // wipe our caches for geolocations and photos
    [[SFVUtil sharedSFVUtil] emptyCaches:YES];
    [[SFVAppCache sharedSFVAppCache] emptyCaches];
    
    [self popAllSubNavControllers];
    
    [self.detailViewController eventLogInOrOut];
    
    [self showLogin];
}

+ (BOOL) hasStoredOAuthRefreshToken {
    return ![SFVUtil isEmpty:[SimpleKeychain load:refreshTokenKey]] &&
             ![SFVUtil isEmpty:[SimpleKeychain load:instanceURLKey]];
}

- (void) showLogin {
    if( [self.popoverController isPopoverVisible] )
        [self.popoverController dismissPopoverAnimated:YES];
    
    if( self.splitViewController.modalViewController && [self.splitViewController.modalViewController isKindOfClass:[UINavigationController class]] )
        [(UINavigationController *)self.splitViewController.modalViewController pushViewController:[self loginController] animated:YES];
    else {
        [self hideLoadingModal];
        
        UIViewController *vc = [self loginController];
        
        UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:vc];
        
        aNavController.modalPresentationStyle = UIModalPresentationFormSheet;
        aNavController.navigationBar.tintColor = AppSecondaryColor;
        
        [self.splitViewController presentModalViewController:aNavController animated:YES];
        [aNavController release];
    }
}

#pragma mark - toolbar actions

- (IBAction) showSettings:(id)sender {    
    IASKAppSettingsViewController *settingsViewController = [[IASKAppSettingsViewController alloc] initWithNibName:@"IASKAppSettingsView" bundle:nil];
    settingsViewController.delegate = self;
    settingsViewController.showDoneButton = YES;
    settingsViewController.showCreditsFooter = YES;
    settingsViewController.extraFooterText = [NSString stringWithFormat:@"%@%@",
                                              ( [self isLoggedIn] ? [NSString stringWithFormat:@"%@ %@.\n", 
                                                                     NSLocalizedString(@"Logged in as", @"Logged in as"),
                                                                     [[client currentUserInfo] userName]] : @"" ),
                                              [NSString stringWithFormat:@"%@ (%@)", 
                                               [SFVUtil appFullName],
                                               [SFVUtil appVersion]]];
    settingsViewController.title = NSLocalizedString(@"Settings", @"Settings");
    
    settingsViewController.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:[self loginAction]
                                                                                                 style:UIBarButtonItemStyleBordered
                                                                                                target:self
                                                                                                action:@selector(logInOrOut:)] autorelease];
    
    if( self.popoverController )
        [self.popoverController dismissPopoverAnimated:YES];
    
    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:settingsViewController];
    [settingsViewController release];
    
    aNavController.modalPresentationStyle = UIModalPresentationFormSheet;
    aNavController.navigationBar.tintColor = AppSecondaryColor;
    
    [self.splitViewController presentModalViewController:aNavController animated:YES];
    [aNavController release];
}

#pragma mark - settings delegate

- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender {
    [self.splitViewController dismissModalViewControllerAnimated:YES];
}

- (OAuthViewController *) loginController {    
    OAuthViewController *oAuthViewController = [[OAuthViewController alloc] 
                                                initWithTarget:self 
                                                selector:@selector(loginOAuth:error:)];
    
    return [oAuthViewController autorelease];
}

#pragma mark - EULA acceptance

- (void)EULADidAccept:(SFVEULAAcceptController *)controller {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithBool:YES] forKey:EULAAcceptKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self showFirstRunModal:NO];
}

#pragma mark - first run

- (void) showFirstRunModal:(BOOL)showEULA {
    UIViewController *firstRunController = nil;
    
    if( showEULA ) {
        firstRunController = [[SFVEULAAcceptController alloc] init];
        ((SFVEULAAcceptController *)firstRunController).delegate = self;
    } else {
        firstRunController = [[SFVFirstRunController alloc] init];
        ((SFVFirstRunController *)firstRunController).delegate = self;
    }
    
    UINavigationController *controller = nil;
    
    if( self.splitViewController.modalViewController ) {
        controller = (UINavigationController *)self.splitViewController.modalViewController;
        
        [controller pushViewController:firstRunController animated:YES];
    } else {
        controller = [[UINavigationController alloc] initWithRootViewController:firstRunController];
        controller.modalPresentationStyle = UIModalPresentationFormSheet;
        controller.navigationBar.tintColor = AppSecondaryColor;
        
        [self.splitViewController presentModalViewController:controller animated:YES];
        [controller release];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:firstRunKey];
        [defaults setObject:[NSNumber numberWithBool:YES] forKey:emptyFieldsKey];
        [defaults synchronize];   
    }
    
    [firstRunController release];
}

- (void) firstRunDidComplete:(SFVFirstRunController *)controller {
    [self showLogin];
}

@end
