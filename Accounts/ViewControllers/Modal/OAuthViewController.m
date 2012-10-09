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

#import "OAuthViewController.h"
#import "NSURL+Additions.h"
#import "WebViewController.h"
#import "DSActivityView.h"
#import "PRPSmartTableViewCell.h"

@interface OAuthViewController (Private)

- (NSURL *)loginURL;
- (void)sendActionToTarget:(NSError *)error;

@end

@implementation OAuthViewController

@synthesize accessToken;
@synthesize refreshToken;
@synthesize instanceUrl;
@synthesize webView, target;

- (id)initWithTarget:(id)aTarget selector:(SEL)aSelector {
    if ((self = [super init])) {
        self.target = aTarget;
        action = aSelector;
        
        [self.view setFrame:CGRectMake(0, 0, 540, 575)];
        
        if( !self.webView ) {
            self.webView = [[[UIWebView alloc] initWithFrame:CGRectMake(0, 0, 540, 575)] autorelease];
            webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight ;
            webView.delegate = self;
            webView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
            webView.scalesPageToFit = YES;
            
            [self.view addSubview:self.webView];
        }
    }
    
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if( !loginHostGear ) {
        UIButton *btn = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *gear = [UIImage imageNamed:@"gear2.png"];
        
        [btn setImage:gear forState:UIControlStateNormal];
        [btn addTarget:self action:@selector(tappedLoginHostGear:) forControlEvents:UIControlEventTouchUpInside];
        [btn setFrame:CGRectMake(0, 0, gear.size.width, gear.size.height)];
        
        loginHostGear = [[UIBarButtonItem alloc] initWithCustomView:btn];
        
        [self.navigationItem setRightBarButtonItem:loginHostGear animated:YES];
    }
    
    if( !loginRefresh ) {
        loginRefresh = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                     target:self
                                                                     action:@selector(reloadWebView)];
        
        [self.navigationItem setLeftBarButtonItem:loginRefresh animated:YES];
    }
    
    [self reloadWebView];
}

- (void)reloadWebView {
    [DSBezelActivityView removeViewAnimated:NO];

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:[self loginURL]];
    [request setCachePolicy:NSURLRequestReloadIgnoringLocalCacheData];
    [self.webView loadRequest:request];
    
    self.navigationItem.title = [NSString stringWithFormat:@"%@ (%@)", 
                                 NSLocalizedString(@"Secure Log In", @"log in window title"),
                                 [OAuthLoginHostPicker nameForCurrentLoginHost]];
    
    [DSBezelActivityView newActivityViewForView:self.webView];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void)dealloc {
    [accessToken release];
    [instanceUrl release];
    [refreshToken release];
    self.webView = nil;
    self.target = nil;
    
    SFRelease(loginRefresh);
    SFRelease(loginHostGear);
    SFRelease(popoverController);
    [super dealloc];
}

- (NSURL *)loginURL {
    NSString *urlTemplate = @"%@services/oauth2/authorize?response_type=token&scope=id refresh_token full web visualforce&client_id=%@&display=touch&redirect_uri=%@";
    NSString *urlString = [NSString stringWithFormat:urlTemplate, 
                           [OAuthLoginHostPicker URLForCurrentLoginHost], 
                           [[self class] OAuthClientId], 
                           [[self class] redirectURL]];
    
    urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
    
    NSURL *url = [NSURL URLWithString:urlString];
    return url;
}

- (void)sendActionToTarget:(NSError *)error {
    [target performSelector:action withObject:self withObject:error];
}

#pragma mark - UIWebViewDelegate

- (void)webViewDidStartLoad:(UIWebView *)webView {
    loginRefresh.enabled = NO;
}

- (void) webView:(UIWebView *)wv didFailLoadWithError:(NSError *)error {
    [DSBezelActivityView removeViewAnimated:NO];
    
    loginRefresh.enabled = YES;
    
    if( [error code] != -999 )
        [webView loadHTMLString:[[self class] HTMLStringForError:@"By Great Odin's Beard!"
                                                     description:[error localizedDescription]]
                        baseURL:nil];
}

- (void) webViewDidFinishLoad:(UIWebView *)wv {
    [DSBezelActivityView removeViewAnimated:YES];
    
    loginRefresh.enabled = YES;
    
    [wv stringByEvaluatingJavaScriptFromString:@"document.login.rememberUn.checked=true"];
}

- (BOOL)webView:(UIWebView *)myWebView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType 
{
    NSString *urlString = [[request URL] absoluteString];
    
    // Catch the user denying the authorization
    if( [[[request URL] parameterWithName:@"error"] isEqualToString:@"access_denied"] ) {
        [[self class] wipeLoginCaches];
        [self reloadWebView];
        return NO;
    }

    NSRange range = [urlString rangeOfString:[[self class] redirectURL]];
    
    if (range.length > 0 && range.location == 0) 
    {
        NSString * newInstanceURL = [[request URL] parameterWithName:@"instance_url"];
        if (newInstanceURL)
        {
            [instanceUrl release];
            instanceUrl = [newInstanceURL retain];
        }
        
        NSString *newRefreshToken = [[request URL] parameterWithName:@"refresh_token"];
        if (newRefreshToken)
        {
            [refreshToken release];
            refreshToken = [newRefreshToken retain];
        }
        
        NSString *newAccessToken = [[request URL] parameterWithName:@"access_token"];
        if (newAccessToken)
        {
            [accessToken release];
            accessToken = [newAccessToken retain];
            [self sendActionToTarget:nil];
        }
        return NO;
    }
    
    return YES;
}

#pragma mark - popover delegate

- (void) dismissPopover {
    if( popoverController ) {
        if( [popoverController isPopoverVisible] )
            [popoverController dismissPopoverAnimated:YES];
        
        SFRelease(popoverController);
    }
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)pc {
    SFRelease(popoverController);
}

#pragma mark - login host

+ (NSString *)OAuthClientId {
    // This was working around a bug that's since been fixed. Used to require a separate
    // client ID for sandbox
    //if( [[OAuthLoginHostPicker URLForCurrentLoginHost] hasPrefix:kSandboxLoginURL] )
    //    return OAuthClientIDSandbox;
    
    return OAuthClientID;
}

- (void)tappedLoginHostGear:(id)sender {
    if( popoverController ) {
        [self dismissPopover];
        return;
    }
    
    // View controller
    OAuthLoginHostPicker *pickerController = [[OAuthLoginHostPicker alloc] initWithStyle:UITableViewStylePlain];
    pickerController.delegate = self;
    
    // Nav controller
    UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:pickerController];
    navController.delegate = self;
    
    // Popover controller
    popoverController = [[UIPopoverController alloc] initWithContentViewController:navController];
    [navController release];
    
    popoverController.delegate = self;
    
    [popoverController presentPopoverFromBarButtonItem:loginHostGear
                              permittedArrowDirections:UIPopoverArrowDirectionUp
                                              animated:YES];
    
    popoverController.popoverContentSize = CGSizeMake( CGRectGetWidth(pickerController.view.frame), CGRectGetHeight(pickerController.view.frame) + 37);
    [pickerController release];
}

#pragma mark - util

+ (NSString *) redirectURL {
    return [NSString stringWithFormat:@"%@services/oauth2/success", [OAuthLoginHostPicker URLForCurrentLoginHost]];
}

+ (NSString *)HTMLStringForError:(NSString *)error description:(NSString *)description {
    return [NSString stringWithFormat:@"<html><head></head><body><br/><br/><br/><br/><center><p style=\"font-size:48px\" color=\"#333333\" font-family=\"Verdana\">"
                                        "<strong>%@</strong></p><p style=\"font-size:36px\" font-family=\"Verdana\">%@</p></center></body></html>",
                        error,
                        description];
}

#pragma mark - navigation

- (UINavigationController *) currentCustomHostNavController {
    if( !popoverController )
        return nil;
    
    return (UINavigationController *)[popoverController contentViewController];
}

#pragma mark - login host picker delegate

- (void)OAuthLoginHost:(OAuthLoginHostPicker *)controller didSelectLoginHostAtIndex:(NSInteger)index {
    if( index != [OAuthLoginHostPicker indexOfCurrentLoginHost] ) {
        // This is a little janky, but we have to clear the page when we switch hosts
        [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:@"about:blank"]]];
        
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        // write this selection to defaults
        [defaults setInteger:index forKey:kLoginHostIndexKey];
        [defaults synchronize];
        
        [self performSelector:@selector(reloadWebView) withObject:nil afterDelay:0.1f];
    }
    
    [self dismissPopover];
}

- (void)OAuthLoginHostDidTapAddCustomHostButton:(OAuthLoginHostPicker *)controller {
    OAuthCustomHostCreator *creator = [[OAuthCustomHostCreator alloc] initWithStyle:UITableViewStyleGrouped];
    creator.delegate = self;
    
    [[self currentCustomHostNavController] pushViewController:creator animated:YES];
    [creator release];
}

#pragma mark - custom host creator delegate

- (void)OAuthCustomHostCreator:(OAuthCustomHostCreator *)creator didSaveNewHostAtCustomHostIndex:(NSInteger)index {
    // pop to home
    [[self currentCustomHostNavController] popViewControllerAnimated:YES];
    
    UITableViewController *cont = (UITableViewController *)[[self currentCustomHostNavController] visibleViewController];
    
    if( [cont respondsToSelector:@selector(reloadAndResize)] ) {
        [cont performSelector:@selector(reloadAndResize)];
        
        popoverController.popoverContentSize = cont.contentSizeForViewInPopover;
    }
}

- (void)OAuthCustomHostCreatorNeedsRedisplay:(OAuthCustomHostCreator *)creator {
    [popoverController presentPopoverFromBarButtonItem:loginHostGear
                              permittedArrowDirections:UIPopoverArrowDirectionUp
                                              animated:YES];
}

#pragma mark - navigation delegate

- (void)navigationController:(UINavigationController *)navigationController didShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if( animated ) {
        popoverController.popoverContentSize = viewController.contentSizeForViewInPopover;
        
        [self OAuthCustomHostCreatorNeedsRedisplay:nil];
    }
}

#pragma mark - login cache destruction

+ (void)removeApplicationLibraryDirectoryWithDirectory:(NSString *)dirName {
	NSString *dir = [[[[NSSearchPathForDirectoriesInDomains(NSApplicationDirectory, NSUserDomainMask, YES) lastObject] stringByDeletingLastPathComponent] stringByAppendingPathComponent:@"Library"] stringByAppendingPathComponent:dirName];
	if ([[NSFileManager defaultManager] fileExistsAtPath:dir]) {
		[[NSFileManager defaultManager] removeItemAtPath:dir error:nil];
	}
}

+ (void)wipeLoginCaches {
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
	[[self class] removeApplicationLibraryDirectoryWithDirectory:@"Caches"];
	[[self class] removeApplicationLibraryDirectoryWithDirectory:@"WebKit"];
    
    NSArray *cookiesToSave = [NSArray arrayWithObjects:@"rememberUn", @"login", @"autocomplete", nil];
    
	for (NSHTTPCookie *cookie in [[NSHTTPCookieStorage sharedHTTPCookieStorage] cookies])        
        if( ![cookiesToSave containsObject:[cookie name]] )
            [[NSHTTPCookieStorage sharedHTTPCookieStorage] deleteCookie:cookie];
    
	[[self class] removeApplicationLibraryDirectoryWithDirectory:@"Cookies"];
}

@end
