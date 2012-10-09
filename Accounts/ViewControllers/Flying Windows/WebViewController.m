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

#import "SFVUtil.h"
#import "WebViewController.h"
#import "DetailViewController.h"
#import "RootViewController.h"
#import "SubNavViewController.h"
#import "PRPAlertView.h"
#import "ChatterPostController.h"
#import "DSActivityView.h"
#import <Twitter/Twitter.h>
#import "SFVAppCache.h"
#import "SFVAsync.h"

@implementation WebViewController

@synthesize webView, navBar, myActionSheet, chatterPop, actionButton, destURL, isFullScreen;

- (id) initWithFrame:(CGRect)frame {
    if((self = [super initWithFrame:frame])) {                
        self.modalPresentationStyle = UIModalPresentationFullScreen;
        self.modalTransitionStyle = UIModalTransitionStyleCoverVertical;
        
        self.webView = [[[UIWebView alloc] initWithFrame:CGRectMake(0, self.navBar.frame.size.height, 
                                                                    frame.size.width, frame.size.height - self.navBar.frame.size.height)] autorelease];
        self.webView.delegate = self;
        self.webView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;
        self.webView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
        self.webView.scalesPageToFit = YES;
        self.webView.allowsInlineMediaPlayback = YES;
        
        if( [self.webView respondsToSelector:@selector(mediaPlaybackAllowsAirPlay)] )
            self.webView.mediaPlaybackAllowsAirPlay = YES;
                
        [self.view addSubview:self.webView];
        
        self.isFullScreen = NO;
        
        webviewLoads = 0;
    }
        
    return self;
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if( self.myActionSheet && [self.myActionSheet isVisible] )
        [self.myActionSheet dismissWithClickedButtonIndex:-1 animated:NO];
    
    if( self.chatterPop && [self.chatterPop isPopoverVisible] )
        [self.chatterPop dismissPopoverAnimated:NO];
}

- (void)dealloc {
    self.actionButton = nil;
    self.myActionSheet = nil;
    self.chatterPop = nil;
    self.destURL = nil;
    self.webView = nil;
    
    [super dealloc];
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (UIToolbar *) toolBarForSide:(BOOL)isLeftSide {
    UIToolbar* toolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];
    NSArray *buttons = nil;
    
    toolbar.tintColor = self.navBar.tintColor;
    toolbar.opaque = YES;
    
    CGRect toolbarFrame = CGRectMake( 0, 0, 130, CGRectGetHeight(self.navBar.frame) );
    
    UIBarButtonItem *spacer = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                            target:nil
                                                                             action:nil] autorelease];
    
    // Set up our right side nav bar
    if( !isLeftSide ) { 
        toolbarFrame.size.width = 110;
        
        self.actionButton = [[[UIBarButtonItem alloc]
                                         initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                         target:self
                                         action:@selector(showActionPopover:)] autorelease];
        
        self.actionButton.enabled = ![[[[self.webView request] URL] absoluteString] isEqualToString:@"about:blank"];
        
        UIBarButtonItem *expandButton = nil;
        
        if( !self.isFullScreen )
            expandButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"zoom.png"] 
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(toggleFullScreen:)] autorelease];
        else
            expandButton = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"zoom.png"] 
                                                             style:UIBarButtonItemStylePlain
                                                            target:self
                                                            action:@selector(toggleFullScreen:)] autorelease];
            
        
        buttons = [NSArray arrayWithObjects:spacer, actionButton, spacer, expandButton, nil];
    } else {
        // left side toolbar
        UIBarButtonItem *back = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"back.png"] 
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(backAction)] autorelease];
        back.enabled = [self.webView canGoBack];
        
        UIBarButtonItem *reload = nil;
        
        if( [webView isLoading] )
            reload = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemStop
                                                                                target:self 
                                                                                action:@selector(stopLoading)] autorelease];
        else
            reload = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                   target:self
                                                                   action:@selector(refreshMe)] autorelease];
        
        reload.style = UIBarButtonItemStylePlain;
        
        UIBarButtonItem *forward = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"forward.png"]
                                                                               style:UIBarButtonItemStylePlain
                                                                              target:self
                                                                              action:@selector(forwardAction)] autorelease];
        forward.enabled = [self.webView canGoForward];
        
        buttons = [NSArray arrayWithObjects:back, spacer, reload, spacer, forward, nil];
    }
        
    if( buttons )
        [toolbar setItems:buttons animated:NO];
    
    [toolbar setFrame:toolbarFrame];
    
    return [toolbar autorelease];
}

- (IBAction) toggleFullScreen:(id)sender {
        
    if( !self.isFullScreen ) {  
        WebViewController *wvc = [[WebViewController alloc] initWithFrame:self.view.frame];
        wvc.isFullScreen = YES;
        wvc.delegate = self.delegate;
        wvc.flyingWindowType = self.flyingWindowType;
        wvc.detailViewController = self.detailViewController;
        wvc.rootViewController = self.rootViewController;
        wvc.account = [self.detailViewController mostRecentlySelectedRecord];
        
        [wvc loadURL:[[[self.webView request] URL] absoluteString]];    
        
        [self.detailViewController clearFlyingWindows];
        
        [self.rootViewController.splitViewController presentViewController:wvc
                                                                  animated:YES
                                                                completion:nil];
        [wvc release];
    } else         
        [self.rootViewController.splitViewController dismissViewControllerAnimated:NO
                                                                        completion:^{
                                                                            if( [self.detailViewController numberOfFlyingWindows] == 0 ) {
                                                                                if( self.account )
                                                                                    [self.detailViewController didSelectAccount:[[self.account copy] autorelease]];
                                                                                else
                                                                                    [self.detailViewController addFlyingWindow:FlyingWindowRecentRecords withArg:nil];
                                                                            }
                                                                        }];
}

- (void) resetNavToolbar {
    UIToolbar *leftBar = [self toolBarForSide:YES];
    navBar.topItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:leftBar] autorelease];
    
    UIToolbar *rightBar = [self toolBarForSide:NO];
    navBar.topItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithCustomView:rightBar] autorelease];
}

- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    [[SFVUtil sharedSFVUtil] endNetworkAction];
    navBar.topItem.title = @"";    
    webviewLoads--;
    
    if( webviewLoads == 0 )
        [self resetNavToolbar];
    
    [[SFVUtil sharedSFVUtil] receivedAPIError:error];
    
    switch( [error code] ) {
        case -1004:
        case -999:
            break;
        case -1003:
        case -1009:
            [PRPAlertView showWithTitle:[[error userInfo] objectForKey:@"NSErrorFailingURLStringKey"]
                                message:[error localizedDescription]
                            cancelTitle:nil
                            cancelBlock:nil
                             otherTitle:NSLocalizedString(@"OK", @"OK") 
                             otherBlock:^(void) {
                                 [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
                             }];            
            break;
        default: 
            [PRPAlertView showWithTitle:[[error userInfo] objectForKey:@"NSErrorFailingURLStringKey"]
                                message:[error localizedDescription]
                            buttonTitle:NSLocalizedString(@"OK", @"OK")];
            break;
    }
}

- (void)webViewDidStartLoad:(UIWebView *)wv {        
    self.destURL = [[[wv request] URL] absoluteString];
    
    [self pushNavigationBarWithTitle:self.destURL
                            leftItem:navBar.topItem.leftBarButtonItem
                           rightItem:navBar.topItem.rightBarButtonItem
                            animated:NO];
    
    if( webviewLoads == 0 )
        [self resetNavToolbar];
    
    webviewLoads++;
    [[SFVUtil sharedSFVUtil] startNetworkAction];
}

- (void)webViewDidFinishLoad:(UIWebView *)wv {    
    [[SFVUtil sharedSFVUtil] endNetworkAction];
    webviewLoads--;
    
    [[NSUserDefaults standardUserDefaults] setInteger:0 forKey:@"WebKitCacheModelPreferenceKey"];
    
    if( webviewLoads > 0 )
        return;
    
    [self pushNavigationBarWithTitle:[wv stringByEvaluatingJavaScriptFromString:@"document.title"]
                            leftItem:navBar.topItem.leftBarButtonItem
                           rightItem:navBar.topItem.rightBarButtonItem
                            animated:NO];
    
    self.destURL = [[[wv request] URL] absoluteString];
    
    [self resetNavToolbar];
    
    if( self.chatterPop && [self.chatterPop isPopoverVisible] ) {
        ChatterPostController *cpc = (ChatterPostController *)[(UINavigationController *)[self.chatterPop contentViewController] visibleViewController];
        
        [cpc updatePostDictionary:[NSDictionary dictionaryWithObjectsAndKeys:
                                   self.destURL, kLinkField,
                                   nil]];
    }
}

- (void) stopLoading {
    [webView stopLoading];
    [[SFVUtil sharedSFVUtil] endNetworkAction];
    navBar.topItem.title = nil;
    
    [self resetNavToolbar];
}

- (void) refreshMe {
    if( ![webView request] || [[[[webView request] URL] absoluteString] isEqualToString:@""] ) 
        [webView loadRequest:[NSURLRequest requestWithURL:[NSURL URLWithString:destURL]]];
    else
        [webView loadRequest:[webView request]];
}

- (void) backAction {
    if( [webView canGoBack] ) {
        [webView goBack];
        
        [self resetNavToolbar];
    }
}

- (void) forwardAction {
    if( [webView canGoForward] ) {
        [webView goForward];
         
        [self resetNavToolbar];
    }
}

- (BOOL) supportsButtonAtIndex:(WebViewActionButton)index {
    switch( index ) {
        case ButtonPostToChatter:
            return [[SFVAppCache sharedSFVAppCache] isChatterEnabled];
        case ButtonMailLink:
            return [MFMailComposeViewController canSendMail];
        case ButtonTweet:
            return[TWTweetComposeViewController canSendTweet];
        default:
            return YES;
    }
    
    return YES;
}

- (void) showActionPopover:(id)sender {    
    if( self.myActionSheet && [self.myActionSheet isVisible] ) {
        [self.myActionSheet dismissWithClickedButtonIndex:-1 animated:YES];
        self.myActionSheet = nil;
        return;
    } else
        self.myActionSheet = nil;
    
    if( self.chatterPop ) {
        [self.chatterPop dismissPopoverAnimated:YES];
        self.chatterPop = nil;
    }
    
    UIActionSheet *action = [[UIActionSheet alloc] init];
    
    [action setTitle:self.destURL];
    [action setDelegate:self];
    
    for( int i = 0; i < ButtonNumButtons; i++ ) {
        if( ![self supportsButtonAtIndex:i] )
            continue;
        
        switch( i ) {
            case ButtonPostToChatter:
                [action addButtonWithTitle:NSLocalizedString(@"Share on Chatter", @"Share on Chatter")];
                break;
            case ButtonCopyLink:
                [action addButtonWithTitle:NSLocalizedString(@"Copy Link", @"Copy link")];
                break;
            case ButtonOpenInSafari:
                [action addButtonWithTitle:NSLocalizedString(@"Open in Safari", @"Open in safari")];
                break;
            case ButtonMailLink:
                [action addButtonWithTitle:NSLocalizedString(@"Mail Link", @"Mail Link")];
                break;
            case ButtonTweet:
                [action addButtonWithTitle:NSLocalizedString(@"Tweet", @"Tweet")];
                break;
            default: break;
        }
    } 
    
    [action showFromBarButtonItem:sender animated:YES];
    self.myActionSheet = action;
    [action release];
}

- (void) loadURL:(NSString *)url {
    if( ![[url lowercaseString] hasPrefix:@"http://"] && ![[url lowercaseString] hasPrefix:@"https://"] )
        url = [NSString stringWithFormat:@"http://%@", url];
    
    self.destURL = url;
    
    [self stopLoading];
    
    NSURLRequest *req = [NSURLRequest requestWithURL:[NSURL URLWithString:url]];
    [self.webView loadRequest:req];
}

- (BOOL) disablesAutomaticKeyboardDismissal {
    return NO;
}

//This is one of the delegate methods that handles success or failure
//and dismisses the mail
- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {    
    [self dismissModalViewControllerAnimated:YES];
    
    if (result == MFMailComposeResultFailed && error )
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                            message:[error localizedDescription] 
                        buttonTitle:NSLocalizedString(@"OK", @"OK")];
}

// We've clicked a button in this contextual menu
-(void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if( buttonIndex == -1 )
        return;
    
    if( self.chatterPop ) {
        [self.chatterPop dismissPopoverAnimated:NO];
        self.chatterPop = nil;
    }
    
    int mappedIndex = 0;
    
    for( int x = 0; x < ButtonNumButtons; x++ ) {
        if( [self supportsButtonAtIndex:x] )
            buttonIndex--;
        
        if( buttonIndex < 0 ) {
            mappedIndex = x;
            break;
        }
    }
        
    switch( mappedIndex ) {
        case ButtonPostToChatter: {
            NSDictionary *account = nil;
            
            if( [self.detailViewController mostRecentlySelectedRecord] && 
               [[SFVAppCache sharedSFVAppCache] doesGlobalObject:[[self.detailViewController mostRecentlySelectedRecord] objectForKey:kObjectTypeKey]
                                                    haveProperty:GlobalObjectIsFeedEnabled] )
                account = [self.detailViewController mostRecentlySelectedRecord];        
            
            ChatterPostController *cpc = [[ChatterPostController alloc] initWithPostDictionary:
                                          [NSDictionary dictionaryWithObjectsAndKeys:
                                           self.destURL, kLinkField,
                                           [self.webView stringByEvaluatingJavaScriptFromString:@"document.title"], kTitleField,
                                           ( account ? [[SFVAppCache sharedSFVAppCache] nameForSObject:account] : 
                                                       [[SFVUtil sharedSFVUtil] currentUserName] ), kParentName,
                                           ( account ? [account objectForKey:@"Id"] : [[SFVUtil sharedSFVUtil] currentUserId] ), kParentField,
                                           ( account ? [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[account objectForKey:@"Id"]] : @"User" ), kParentType,
                                           nil]];
            cpc.delegate = self;
                    
            UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:cpc];
            [cpc release];
            
            self.chatterPop = [[[UIPopoverController alloc] initWithContentViewController:aNavController] autorelease];
            self.chatterPop.delegate = self;
            [aNavController release];
            
            [self.chatterPop presentPopoverFromBarButtonItem:self.actionButton
                                    permittedArrowDirections:UIPopoverArrowDirectionAny
                                                    animated:YES];
            
            break;
        } 
        case ButtonCopyLink: {
            UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
            pasteboard.string = self.destURL; 
            break;
        } 
        case ButtonOpenInSafari: {
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:self.destURL]];
            break;
        } 
        case ButtonMailLink: {
            MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
            mailViewController.mailComposeDelegate = self;
            [mailViewController setSubject:@""];
            [mailViewController setMessageBody:[NSString stringWithFormat:@"%@\n%@",
                                            [webView stringByEvaluatingJavaScriptFromString:@"document.title"],
                                            self.destURL]
                                        isHTML:NO];
            
            [self presentModalViewController:mailViewController animated:YES];
            [mailViewController release];
            break;
        }
        case ButtonTweet: {
            TWTweetComposeViewController *tVC = [[TWTweetComposeViewController alloc] init];
            
            tVC.completionHandler = ^(TWTweetComposeViewControllerResult result) {
                dispatch_async(dispatch_get_main_queue(), ^{            
                    [self dismissViewControllerAnimated:YES completion:nil];
                });
            };
            
            [tVC setInitialText:[self.webView stringByEvaluatingJavaScriptFromString:@"document.title"]];
            [tVC addURL:[NSURL URLWithString:self.destURL]];
            
            [self presentViewController:tVC animated:YES completion:nil];
            [tVC release];
            
            break;
        }
        default: break;
    }
    
    myActionSheet = nil;
}

#pragma mark - popover delegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    UINavigationController *cont = (UINavigationController *)[popoverController contentViewController];
    ChatterPostController *post = (ChatterPostController *)[cont visibleViewController];
    
    return ![post isDirty];
}

#pragma mark - chatter post delegate

- (void) chatterPostDidPost:(ChatterPostController *)chatterPostController {
    [self dismissPopover];
}

- (void) dismissPopover {    
    [self.chatterPop dismissPopoverAnimated:YES];
    self.chatterPop = nil;
}

- (void) chatterPostDidDismiss:(ChatterPostController *)chatterPostController {
    [self dismissPopover];
}

- (void) chatterPostDidFailWithError:(ChatterPostController *)chatterPostController error:(NSError *)e {
    [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert") 
                        message:[e localizedDescription]
                    buttonTitle:@"OK"];
}

@end
