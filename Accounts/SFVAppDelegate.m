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

/************* CODE CATS ARE NOT AMUSED *****************
 
        *     ,MMM8&&&.            *
            MMMM88&&&&&    .
            MMMM88&&&&&&&
 *          MMM88&&&&&&&&
            MMM88&&&&&&&&
            'MMM88&&&&&&'
              'MMM8&&&'        *     _
     |\___/|                          \\
    =) ^Y^ (=        |\_/|             ||    '
     \  ^  /         )a a '._.-""""-.  //
      )=*=(         =\T_= /    ~  ~  \//
     /     \          `"`\   ~   / ~  /
     |     |              |~   \ |  ~/
    /| | | |\             \  ~/- \ ~\
    \| | |_|/|            || |  // /`
 jgs_/\_//_// __//\_/\_/\_((_|\((_//\_/\_/\_
 |  |  |  | \_) |  |  |  |  |  |  |  |  |  |
 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
 |  |  |  |  |  |  |  |  |  |  |  |  |  |  |
 
 *******************************************************/

#import "SFVAppDelegate.h"
#import "RootViewController.h"
#import "DetailViewController.h"
#import "SFVUtil.h"
#import "MGSplitViewController.h"
#import "PRPConnection.h"
#import "SFVAppCache.h"
#import "OAuthViewController.h"

@implementation SFVAppDelegate

#pragma mark - app lifecycle

@synthesize window, detailViewController, splitViewController, rootViewController;

+ (SFVAppDelegate *)sharedAppDelegate {
    return (SFVAppDelegate *)[[UIApplication sharedApplication] delegate];
}

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
    [[SFAnalytics sharedInstance] startWithService:@"Localytics" token:LOCALYTICS_APPKEY];
    
    [[self class] applyAppStyles];
    
    self.window.rootViewController = self.splitViewController;
    [self.window addSubview:splitViewController.view];
    
    splitViewController.showsMasterInPortrait = NO;
    splitViewController.splitPosition = masterWidth;
    splitViewController.splitWidth = kSplitWidth;
    splitViewController.allowsDraggingDivider = NO;
    
    [self.window makeKeyAndVisible];
    
    [self.rootViewController performSelector:@selector(appFinishedLaunching) withObject:nil afterDelay:0.5];
           
    return YES;
}

// ********************************************

- (void)applicationWillResignActive:(UIApplication *)application
{
    NSLog(@"app will resign active");
    /*
     Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
     Use this method to pause ongoing tasks, disable timers, and throttle down OpenGL ES frame rates. Games should use this method to pause the game.
     */
}

- (void)applicationDidEnterBackground:(UIApplication *)application
{
    NSLog(@"app did enter background");
}

- (void)applicationWillEnterForeground:(UIApplication *)application
{
    NSLog(@"app will enter foreground");
    
    /*
     Called as part of the transition from the background to the inactive state; here you can undo many of the changes made on entering the background.
     */
}

- (void)applicationDidBecomeActive:(UIApplication *)application
{
    NSLog(@"app did become active");
        
    // If we are displaying our OAuth window, refresh it.
    if( self.splitViewController.modalViewController 
        && [self.splitViewController.modalViewController isKindOfClass:[UINavigationController class]]
        && [[((UINavigationController *)self.splitViewController.modalViewController) visibleViewController] isKindOfClass:[OAuthViewController class]] )
        [((OAuthViewController *)[((UINavigationController *)self.splitViewController.modalViewController) visibleViewController]) reloadWebView];
    
    /*
     Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
     */
}

- (void)applicationWillTerminate:(UIApplication *)application
{
    NSLog(@"app will terminate");

    [[SFVAppCache sharedSFVAppCache] emptyCaches];
    [[SFVUtil sharedSFVUtil] emptyCaches:YES];
}

- (void) applicationDidReceiveMemoryWarning:(UIApplication *)application {
    NSLog(@"received memory warning (delegate)");
    [[SFVUtil sharedSFVUtil] emptyCaches:NO];
}

- (void)dealloc
{
    [window release];
    [splitViewController release];
    [rootViewController release];
    [detailViewController release];
    [super dealloc];
}

+ (void)applyAppStyles {
    static const UIEdgeInsets kBackgroundImageCapInsets = { 20.0f, 0.0f, 20.0f, 0.0f };
    
    // toolbar styling
    UIImage *resizeableImage = [[UIImage imageNamed:@"blue_header_bg.png"] resizableImageWithCapInsets:kBackgroundImageCapInsets];
    
    [[UINavigationBar appearanceWhenContainedIn:[FlyingWindowController class], nil]
     setBackgroundImage:resizeableImage
     forBarMetrics:UIBarMetricsDefault];
    
    [[UIToolbar appearanceWhenContainedIn:[UINavigationBar class], nil]
     setBackgroundImage:resizeableImage
     forToolbarPosition:UIToolbarPositionTop
     barMetrics:UIBarMetricsDefault];
}

@end
