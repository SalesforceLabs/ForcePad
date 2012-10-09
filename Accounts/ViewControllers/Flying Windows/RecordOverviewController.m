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

#import "RecordOverviewController.h"
#import "DetailViewController.h"
#import "RootViewController.h"
#import "SubNavViewController.h"
#import "SFVUtil.h"
#import "zkSforce.h"
#import "AddressAnnotation.h"
#import <QuartzCore/QuartzCore.h>
#import "PRPConnection.h"
#import "zkParser.h"
#import "DSActivityView.h"
#import "AccountGridCell.h"
#import "FieldPopoverButton.h"
#import "PRPAlertView.h"
#import "FollowButton.h"
#import "FlyingWindowController.h"
#import "CommButton.h"
#import "SBJson.h"
#import "SFVAsync.h"
#import "SFVAppCache.h"
#import "SFRestAPI+SFVAdditions.h"

static float cornerRadius = 4.0f;

@implementation RecordOverviewController

@synthesize accountMap, mapView, gridView, addressButton, recenterButton, geocodeButton, detailButton, recordLayoutView, scrollView, commButtonBackground, followButton, sObjectType, contactMenu;

int describesCompleted;

- (id) initWithFrame:(CGRect)frame {
    if((self = [super initWithFrame:frame])) {      
        int curY = self.navBar.frame.size.height;
        
        self.view.backgroundColor = [UIColor whiteColor];
        isLoading = NO;
        describesCompleted = 0;
        
        // gridview
        UIImage *gridBG = [UIImage imageNamed:@"gridGradient.png"];
        AQGridView *gv = [[AQGridView alloc] initWithFrame:CGRectMake( 0, curY, frame.size.width, gridBG.size.height )];
        
        //gv.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleWidth;
        gv.scrollEnabled = NO;
        gv.requiresSelection = NO;
        gv.delegate = self;
        gv.dataSource = self;
        gv.separatorStyle = AQGridViewCellSeparatorStyleSingleLine;
        gv.separatorColor = UIColorFromRGB(0xdddddd);
        gv.backgroundColor = [UIColor colorWithPatternImage:gridBG];
        gv.hidden = YES;
        
        self.gridView = gv;
        [gv release];
        
        [self.view addSubview:self.gridView];
        
        curY += self.gridView.frame.size.height + 10;
        
        // Comm buttons
        if( !self.commButtonBackground ) {
            self.commButtonBackground = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 50 )] autorelease];
            self.commButtonBackground.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"gridGradient.png"]];
            commButtonBackground.hidden = YES;
            
            CAGradientLayer *shadowLayer = [CAGradientLayer layer];
            shadowLayer.backgroundColor = [UIColor clearColor].CGColor;
            shadowLayer.frame = CGRectMake(0, CGRectGetHeight(commButtonBackground.frame), self.view.frame.size.width + 10, 5);
            shadowLayer.shouldRasterize = YES;
            
            shadowLayer.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0.0 alpha:0.01].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.2].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.4].CGColor,
                                  (id)[UIColor colorWithWhite:0.0 alpha:0.8].CGColor, nil];		
            
            shadowLayer.startPoint = CGPointMake(0.0, 1.0);
            shadowLayer.endPoint = CGPointMake(0.0, 0.0);
            
            shadowLayer.shadowPath = [UIBezierPath bezierPathWithRect:shadowLayer.bounds].CGPath;
            
            [self.commButtonBackground.layer addSublayer:shadowLayer];
            
            [self.view addSubview:self.commButtonBackground];
            
            curY += CGRectGetHeight(commButtonBackground.frame);
        }
        
        // Scrollview
        if( !self.scrollView ) {
            self.scrollView = [[[UIScrollView alloc] initWithFrame:CGRectMake( 0, curY, self.view.frame.size.width,
                                                                             self.view.frame.size.height - curY )] autorelease];
            self.scrollView.showsVerticalScrollIndicator = YES;
            self.scrollView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleBottomMargin;

            [self.scrollView setContentOffset:CGPointZero animated:NO];
            [self.scrollView setContentSize:CGSizeMake( frame.size.width, self.mapView.frame.size.height )];
            
            [self.view insertSubview:self.scrollView belowSubview:self.commButtonBackground];
        }

        // Container for the map
        UIView *mv = [[UIView alloc] initWithFrame:CGRectMake( 0, 0, 100, 100 )];
        mv.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        mv.autoresizesSubviews = YES;
        mv.backgroundColor = [UIColor clearColor];
        
        self.mapView = mv;
        [mv release];
        
        [self.scrollView addSubview:self.mapView];
        
        // Retry geocode button   
        if( !self.geocodeButton ) {
            self.geocodeButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            [geocodeButton setTitleColor:AppLinkColor forState:UIControlStateNormal];
            geocodeButton.titleLabel.textAlignment = UITextAlignmentCenter;
            [geocodeButton.titleLabel setFont:[UIFont boldSystemFontOfSize:18]];
            [geocodeButton setTitle:NSLocalizedString(@"Geocode Failed — Tap to retry", @"Geocode failure") forState:UIControlStateNormal];
            geocodeButton.backgroundColor = [UIColor clearColor];
            [geocodeButton addTarget:self action:@selector(configureMap) forControlEvents:UIControlEventTouchUpInside];
            geocodeButton.layer.borderColor = [UIColor darkGrayColor].CGColor;       
            geocodeButton.hidden = YES;
            
            [self.mapView addSubview:self.geocodeButton];
        }
        
        // Address label
        UIView *addressLabel = [SFVUtil createViewForSection:NSLocalizedString(@"Address", @"Address label") maxWidth:450];
        [addressLabel setFrame:CGRectMake( 0, 0, self.view.frame.size.width, addressLabel.frame.size.height )];        
        [self.mapView addSubview:addressLabel];
        
        // Recenter Button
        if( !self.recenterButton ) {
            self.recenterButton = [UIButton buttonWithType:UIButtonTypeCustom];
            self.recenterButton.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.6];
            self.recenterButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
            [self.recenterButton setTitle:NSLocalizedString(@"Recenter", @"Recenter label") forState:UIControlStateNormal];
            [self.recenterButton setTitleColor:UIColorFromRGB(0x1679c9) forState:UIControlStateNormal];
            [self.recenterButton addTarget:self action:@selector(recenterMap:) forControlEvents:UIControlEventTouchUpInside];
            self.recenterButton.titleLabel.font = [UIFont boldSystemFontOfSize:17];
            self.recenterButton.titleLabel.shadowColor = [UIColor blackColor];
            self.recenterButton.titleLabel.shadowOffset = CGSizeMake(0, 1);
            self.recenterButton.layer.borderWidth = 2.0f;
            self.recenterButton.layer.borderColor = gv.separatorColor.CGColor;
            self.recenterButton.layer.cornerRadius = cornerRadius;
            self.recenterButton.layer.masksToBounds = YES;
            
            [self.mapView addSubview:self.recenterButton];
        }
        
        // account map
        MKMapView *map = [[MKMapView alloc] initWithFrame:CGRectMake(0, 0, 100, 100)];
        [map.layer setMasksToBounds:YES];
        map.layer.cornerRadius = cornerRadius;
        map.autoresizingMask = mv.autoresizingMask;
        map.delegate = self;
        
        self.accountMap = map;
        [map release];
        
        [self.mapView addSubview:self.accountMap];
        self.mapView.hidden = YES;
    }
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self 
     selector:@selector(layoutView)
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
    
    return self;
}

- (void)setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    [self layoutView];
}

- (void) layoutView {   
    float curY = self.navBar.frame.size.height;
    CGSize s;
    
    // Gridview
    if( !self.gridView.hidden ) {
        [self.gridView setFrame:CGRectMake( 0, curY, self.view.frame.size.width, gridView.frame.size.height )];
        [self.gridView reloadData];
                
        curY += self.gridView.frame.size.height;
    }
    
    // Comm button background
    if( self.contactMenu || [[commButtonBackground subviews] count] > 0 ) {
        commButtonBackground.hidden = NO;
        [self.commButtonBackground setFrame:CGRectMake(0, curY, self.view.frame.size.width, self.commButtonBackground.frame.size.height )];
        curY += self.commButtonBackground.frame.size.height;
        
        // Layout comm buttons
        float buttonWidth = self.commButtonBackground.frame.size.width / ( [[commButtonBackground subviews] count] + ( self.contactMenu ? 1 : 0 ) );
        float curX = 0;
        
        for( UIButton *button in [commButtonBackground subviews] ) {
            s = [(UIButton *)button imageForState:UIControlStateNormal].size;
            
            if( s.width < 40 )
                s.width = 40;
            
            if( s.height < 40 )
                s.height = 40;
            
            [button setFrame:CGRectMake( floorf( curX + ( ( buttonWidth - s.width ) / 2.0f ) ), 
                                        floorf( ( self.commButtonBackground.frame.size.height - s.height ) / 2.0f ), 
                                        s.width, s.height )];
                        
            curX += buttonWidth;
        }
        
        if( self.contactMenu )
            [contactMenu setStartPoint:CGPointMake( curX + 2 * contactMenu.image.size.width, 
                                                   CGRectGetMinY(self.commButtonBackground.frame) + floorf( CGRectGetHeight(self.commButtonBackground.frame) / 2.0f ))];
    }
    
    // Scrollview frame
    CGRect r = CGRectMake( 0, curY, self.view.frame.size.width - 5, self.view.frame.size.height - curY);
    
    if( !CGRectEqualToRect( r, self.scrollView.frame ) )
        [self.scrollView setFrame:r];
    
    if( !self.mapView.hidden ) {
        // Reset curY for the scrollView inner content
        curY = 40;
        
        [self.mapView setFrame:CGRectMake( 0, 10, self.view.frame.size.width, 10 )];
        
        // Account address button
        if( !self.addressButton.hidden ) {
            s = [self.addressButton.titleLabel.text sizeWithFont:self.addressButton.titleLabel.font
                                                      constrainedToSize:CGSizeMake( self.view.frame.size.width - 20, 999 )];
            [self.addressButton setFrame:CGRectMake( 10, curY, s.width, s.height)];
            
            curY += self.addressButton.frame.size.height + 5;
        }
        
        // Geocode failed button
        [geocodeButton setFrame:CGRectMake( 10, 40, self.mapView.frame.size.width - 30, 40)];
        
        // Account map
        if( !self.accountMap.hidden ) {
            r = CGRectMake( 10, curY, self.view.frame.size.width - 20, 200 );
            
            [self.accountMap setFrame:r];
            curY += self.accountMap.frame.size.height;
        } else
            curY += self.geocodeButton.frame.size.height + 10;
        
        // Mapview container
        [self.mapView setFrame:CGRectMake( 0, 10, self.view.frame.size.width, 
                                          ( self.geocodeButton.hidden ? curY : 100 ) )];
        
        curY += 15;    
        
        // Recenter button
        CGSize buttonSize = CGSizeMake( lroundf(self.view.frame.size.width / 2.6f), 35 );
        [self.recenterButton setFrame:CGRectMake( self.accountMap.frame.origin.x + self.accountMap.frame.size.width - buttonSize.width, 
                                                 self.accountMap.frame.origin.y, buttonSize.width, buttonSize.height )];
        [self.recenterButton.superview bringSubviewToFront:self.recenterButton];
    } else
        curY = 5;
    
    // Account detail view
    r = CGRectMake( 0, curY, 
                   self.view.frame.size.width, self.recordLayoutView.frame.size.height );
    
    if( !CGRectEqualToRect( r, self.recordLayoutView.frame ) )
        [self.recordLayoutView setFrame:r];
    
    curY += self.recordLayoutView.frame.size.height;
    
    // Scrollview content size
    s.width = self.scrollView.frame.size.width;    
    s.height = MAX( curY, self.scrollView.frame.size.height + 1 );
    
    if( !CGSizeEqualToSize( s, self.scrollView.contentSize ) )
        [self.scrollView setContentSize:s];
}

- (void) selectAccount:(NSDictionary *) acc {
    [super selectAccount:acc];
    
    if( isLoading )
        return;
    
    [self wipeRecordForLoad];
    
    self.sObjectType = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[acc objectForKey:@"Id"]];
    
    isLoading = YES;
    
    [self pushNavigationBarWithTitle:NSLocalizedString(@"Loading...", @"Loading...")
                            leftItem:self.navBar.topItem.leftBarButtonItem
                           rightItem:nil
                            animated:NO];
    
    [DSBezelActivityView newActivityViewForView:self.view];
    
    // Describe every related object
    NSArray *relatedObjects = [[SFVAppCache sharedSFVAppCache] relatedObjectsOnObject:sObjectType];
            
    if( !relatedObjects || [relatedObjects count] == 0 )
        [self describeComplete];
    else for( NSString *object in relatedObjects )
        [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:object
                                                        failBlock:nil
                                                    completeBlock:^(NSDictionary *desc) {
                                                        if( ![self isViewLoaded] ) 
                                                            return;
                                                        
                                                        [self describeComplete];
                                                    }];

}

- (void) describeComplete {
    int targetCount = [[[SFVAppCache sharedSFVAppCache] relatedObjectsOnObject:sObjectType] count];
    
    describesCompleted++;
    
    if( describesCompleted < targetCount )
        return;
    
    describesCompleted = 0;
    
    [[SFVUtil sharedSFVUtil] describeLayoutForsObject:sObjectType
                                        completeBlock:^(ZKDescribeLayoutResult * result) {                                                                                                        
                                                    if( ![self isViewLoaded] ) 
                                                        return;
                                                    
                                                    [self performSelector:@selector(loadRecord) withObject:nil afterDelay:0.6f];
                                                }];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
} 

- (void) setupCommButtons {
    for( UIView *view in [commButtonBackground subviews] )
        [view removeFromSuperview];
    
    if( self.contactMenu )
        [self.contactMenu removeFromSuperview];
    
    QCContactMenu *qcm = [QCContactMenu contactMenuForRecord:self.account];
    
    if( qcm ) {
        self.contactMenu = qcm;
        contactMenu.detailViewController = self.detailViewController;
        [self.view addSubview:contactMenu];
    }

    for( int x = 0; x < CommNumButtonTypes; x++ )
        if( [CommButton supportsButtonOfType:x] ) {
            CommButton *button = [CommButton commButtonWithType:x withRecord:self.account];    
            
            if( !button ) // no actual fields to display for this button
                continue;
            
            button.detailViewController = self.detailViewController;
            
            [self.commButtonBackground addSubview:button];
        }
    
    commButtonBackground.hidden = [[commButtonBackground subviews] count] > 0;
}

- (void) wipeRecordForLoad {
    [accountMap removeAnnotations:[accountMap annotations]];
    mapView.hidden = YES;   
    gridView.hidden = YES;
    geocodeButton.hidden = YES;
    addressButton.hidden = YES;
    commButtonBackground.hidden = YES;
    scrollView.hidden = YES;
    self.followButton = nil;
    
    if( self.recordLayoutView ) {
        [self.recordLayoutView removeFromSuperview];
        self.recordLayoutView = nil;
    }
}

- (void) addRelatedLists {
    [self.detailViewController addFlyingWindow:FlyingWindowListofRelatedLists withArg:self.account];
}

- (void) loadRecord {    
    int fieldLayoutTag = 11;
        
    // Only query the fields that will be displayed in the page layout for this account, given its record type and page layout.
    NSString *layoutId = [[[SFVUtil sharedSFVUtil] layoutForRecord:self.account] Id];
    
    // Let's be optimistic and add it to history before the load succeeded
    [[SFVUtil sharedSFVUtil] addRecentRecord:[self.account objectForKey:@"Id"]];
    
    [[SFRestAPI sharedInstance] performRetrieveWithObjectType:sObjectType
                                                     objectId:[self.account objectForKey:@"Id"]
                                                    fieldList:[[SFVUtil sharedSFVUtil] fieldListForLayoutId:layoutId]
                                                    failBlock:^(NSError *e) {                                                        
                                                        [DSBezelActivityView removeViewAnimated:NO];
                                                        isLoading = NO;
                                                        
                                                        if( ![self isViewLoaded] ) 
                                                            return;
                                                        
                                                        [[SFAnalytics sharedInstance] tagEventOfType:SFVUserRecordLoadFailed
                                                                                          attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                                     self.sObjectType, @"Object",
                                                                                                                     [[e userInfo] objectForKey:@"message"], @"Message",
                                                                                                                     nil]];
                                                        
                                                        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                                                            message:[[e userInfo] objectForKey:@"message"]
                                                                        cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                                                        cancelBlock:^(void) {
                                                                            [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
                                                                            
                                                                            if( [self.detailViewController numberOfFlyingWindows] == 0 )
                                                                                [self.detailViewController addFlyingWindow:FlyingWindowRecentRecords withArg:nil];
                                                                        }
                                                                         otherTitle:NSLocalizedString(@"Retry", @"Retry")
                                                                         otherBlock:^(void) {
                                                                             [self loadRecord];
                                                                         }];
                                                    }
                                                completeBlock:^(NSDictionary *results) {
                                                    if( ![self isViewLoaded] )
                                                        return;
                                                    
                                                    isLoading = NO;
                                                    
                                                    if( !results || [results count] == 0 ) {
                                                        [[SFAnalytics sharedInstance] tagEventOfType:SFVUserRecordLoadFailed
                                                                                          attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                                     self.sObjectType, @"Object",
                                                                                                                     nil]];
                                                        
                                                        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                                                            message:NSLocalizedString(@"Failed to load this Record.", @"Account load failed")
                                                                        cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                                                        cancelBlock:^(void) {
                                                                            [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
                                                                            
                                                                            if( [self.detailViewController numberOfFlyingWindows] == 0 )
                                                                                [self.detailViewController addFlyingWindow:FlyingWindowRecentRecords withArg:nil];
                                                                        }
                                                                         otherTitle:NSLocalizedString(@"Retry", @"Retry")
                                                                         otherBlock: ^ (void) {
                                                                             [self loadRecord];
                                                                         }];
                                                        
                                                        return;
                                                    }
                                                    
                                                    [[SFAnalytics sharedInstance] tagEventOfType:SFVUserViewedRecord
                                                                                      attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                                                 self.sObjectType, @"Object",
                                                                                                                 [SFAnalytics bucketStringForNumber:[NSNumber numberWithInt:[results count]] bucketSize:kBucketDefaultSize], @"Field Count",
                                                                                                                 nil]];
                                                    
                                                    NSMutableDictionary *d = [NSMutableDictionary dictionaryWithDictionary:results];
                                                    [d setObject:[results valueForKeyPath:@"attributes.type"]
                                                          forKey:kObjectTypeKey];
                                                    
                                                    self.account = d;
                                                    self.recordLayoutView = [[SFVUtil sharedSFVUtil] layoutViewForsObject:self.account 
                                                                                                               withTarget:self.detailViewController 
                                                                                                             singleColumn:YES];
                                                    self.recordLayoutView.tag = fieldLayoutTag;
                                                    scrollView.hidden = NO;
                                                    
                                                    UIBarButtonItem *rightItem = nil;
                                                    
                                                    // no follow buttons for converted leads
                                                    if( [[SFVAppCache sharedSFVAppCache] doesGlobalObject:sObjectType 
                                                                                             haveProperty:GlobalObjectIsFeedEnabled]
                                                        && ![[self.account objectForKey:@"IsConverted"] boolValue] ) {                
                                                        self.followButton = [FollowButton followButtonWithParentId:[self.account objectForKey:@"Id"]];
                                                        self.followButton.delegate = self;
                                                        [self.followButton performSelector:@selector(loadFollowState) withObject:nil afterDelay:0.5];
                                                        
                                                        rightItem = [FollowButton loadingBarButtonItem];
                                                    }
                                                    
                                                    [self pushNavigationBarWithTitle:[[SFVAppCache sharedSFVAppCache] nameForSObject:self.account]
                                                                            leftItem:nil
                                                                           rightItem:rightItem];
                                                    
                                                    self.gridView.hidden = NO;
                                                    
                                                    [self.scrollView addSubview:self.recordLayoutView];
                                                    [self.scrollView setContentOffset:CGPointZero animated:NO];
                                                    
                                                    [self setupCommButtons];
                                                    
                                                    [self layoutView];
                                                    
                                                    [self.rootViewController subNavSelectAccountWithId:[self.account objectForKey:@"Id"]];
                                                    [self configureMap];
                                                    
                                                    [DSBezelActivityView removeViewAnimated:YES];
                                                    
                                                    [self performSelector:@selector(addRelatedLists) withObject:nil afterDelay:0.25f];
                                                    [self.detailViewController performSelector:@selector(setPopoverButton:) withObject:nil afterDelay:0.2f];
                                                    
                                                    // If we own this lead, and it was unread, mark it read
                                                    if( [[self.account objectForKey:kObjectTypeKey] isEqualToString:@"Lead"] 
                                                        && ![[self.account objectForKey:@"IsConverted"] boolValue]
                                                        && [[self.account objectForKey:@"OwnerId"] isEqualToString:[[SFVUtil sharedSFVUtil] currentUserId]]
                                                        && [[self.account objectForKey:@"IsUnreadByOwner"] boolValue] ) {
                                                        [[SFRestAPI sharedInstance] performUpdateWithObjectType:@"Lead"
                                                                                                       objectId:[self.account objectForKey:@"Id"]
                                                                                                         fields:[NSDictionary dictionaryWithObject:[NSNumber numberWithBool:NO]
                                                                                                                                            forKey:@"IsUnreadByOwner"]
                                                                                                      failBlock:nil
                                                                                                  completeBlock:nil];
                                                    }
                                                }];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self 
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
    
    followButton.delegate = nil;
    gridView.delegate = nil;
    gridView.dataSource = nil;
    accountMap.delegate = nil;
    
    self.mapView = nil;
    self.accountMap = nil;
    self.gridView = nil;
    self.recordLayoutView = nil;
    self.scrollView = nil;
    self.commButtonBackground = nil;
    self.followButton = nil;
    self.sObjectType = nil;
    self.addressButton = nil;
    self.recenterButton = nil;
    self.geocodeButton = nil;
    self.detailButton = nil;
    self.contactMenu = nil;

    [super dealloc];
}

#pragma mark - follow button delegate

- (void)followButtonDidChangeState:(FollowButton *)followButton toState:(enum FollowButtonState)state isUserAction:(BOOL)isUserAction {    
    if( state == FollowLoading )
        [self.navBar.topItem setRightBarButtonItem:[FollowButton loadingBarButtonItem] animated:NO];
    else
        [self.navBar.topItem setRightBarButtonItem:self.followButton animated:NO];
    
    if( isUserAction ) {
        if( state == FollowNotFollowing )
            [self.detailViewController.subNavViewController removeFollowedRecordWithId:[self.account objectForKey:@"Id"]];
        else if( state == FollowFollowing )
            [self.detailViewController.subNavViewController insertFollowedRecord:self.account];
    }
}

#pragma mark - displaying MKMapView for an account's address

- (IBAction) recenterMap:(id)sender {
    if( [[accountMap annotations] count] > 0 ) {
        AddressAnnotation *pin = [[accountMap annotations] objectAtIndex:0];
        CLLocationCoordinate2D loc = pin.coordinate;
        loc.latitude += 0.008;
            
        MKCoordinateSpan span = MKCoordinateSpanMake(0.03, 0.03);
        MKCoordinateRegion region = MKCoordinateRegionMake( loc, span);
        
        [accountMap setRegion:region animated:(sender != nil)];    
        [accountMap selectAnnotation:pin animated:YES];
    }
}

- (void) mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)views {
    [self performSelector:@selector(recenterMap:)
               withObject:nil
               afterDelay:1.0];
}

- (void)configureMap {    
    NSArray *cached = [[SFVUtil sharedSFVUtil] coordinatesFromCache:[self.account objectForKey:@"Id"]];
    CLLocationCoordinate2D loc;
    
    mapView.hidden = YES;
    geocodeButton.hidden = YES;
    accountMap.hidden = YES;
    recenterButton.hidden = YES;
    addressButton.hidden = YES;
    
    if( cached ) {        
        loc.latitude = [[cached objectAtIndex:0] doubleValue];
        loc.longitude = [[cached objectAtIndex:1] doubleValue];
    } else {                
        NSString *addressStr = [SFVUtil addressForsObject:self.account useBillingAddress:![SFVUtil isEmpty:[self.account objectForKey:@"BillingStreet"]]];
        
        if( !addressStr || [addressStr isEqualToString:@""] )
            return;
                
        NSString *urlStr = [NSString stringWithFormat:@"%@%@&sensor=true", 
                            GEOCODE_ENDPOINT,
                            [[SFVUtil trimWhiteSpaceFromString:addressStr] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
        
        NSLog(@"geocoding %@", urlStr);
        
        PRPConnectionCompletionBlock complete = ^(PRPConnection *connection, NSError *error) {
            [[SFVUtil sharedSFVUtil] endNetworkAction];
            
            if( ![self isViewLoaded] ) 
                return;
            
            if( !error ) {                    
                NSString *responseStr = [[NSString alloc] initWithData:connection.downloadData encoding:NSUTF8StringEncoding];
                
                //NSLog(@"received response %@", responseStr);
                
                SBJsonParser *jp = [[SBJsonParser alloc] init];
                NSDictionary *json = [jp objectWithString:responseStr];
                [responseStr release];
                [jp release];
                
                CLLocationCoordinate2D loc;
                
                NSArray *geoResults = [json valueForKeyPath:@"results.geometry.location"];
                
                if( geoResults && [geoResults count] > 0 ) {
                    NSDictionary *coords = [geoResults objectAtIndex:0];
                    
                    if( coords && [coords count] == 2 ) {
                        loc = CLLocationCoordinate2DMake( [[coords objectForKey:@"lat"] floatValue],
                                                          [[coords objectForKey:@"lng"] floatValue] );
                    
                        [[SFVUtil sharedSFVUtil] addCoordinatesToCache:loc accountId:[self.account objectForKey:@"Id"]];
                        
                        // Fire this function again, which will now read the coordinates from the cache and update the map
                        [self configureMap];
                    }
                }
            } else {
                mapView.hidden = NO;
                geocodeButton.hidden = NO;
                
                [self layoutView];
                
                return;
            }
        };
        
        NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:urlStr]];
        [req addValue:[SFVUtil appFullName] forHTTPHeaderField:@"Referer"];
        
        [[SFVUtil sharedSFVUtil] startNetworkAction];
        PRPConnection *conn = [PRPConnection connectionWithRequest:req
                                                     progressBlock:nil
                                                   completionBlock:complete];
        [conn start]; 
        return;
    }
    
    if( [[NSNumber numberWithDouble:loc.latitude] integerValue] != 0 ) {  
        if( self.addressButton )
            [self.addressButton removeFromSuperview];
        
        NSString *address = [SFVUtil addressForsObject:self.account useBillingAddress:![SFVUtil isEmpty:[self.account objectForKey:@"BillingStreet"]]];
        
        self.addressButton = [FieldPopoverButton buttonWithText:address
                                                      fieldType:AddressField
                                                     detailText:address];
        [self.mapView addSubview:self.addressButton];
        
        mapView.hidden = NO;
        accountMap.hidden = NO;
        recenterButton.hidden = NO;
        addressButton.hidden = NO;
        
        AddressAnnotation *addAnnotation = [[AddressAnnotation alloc] initWithCoordinate:loc];
        addAnnotation.title = [[SFVAppCache sharedSFVAppCache] nameForSObject:self.account];
        addAnnotation.subtitle = nil;
                
        [accountMap addAnnotation:addAnnotation];
        [addAnnotation release];
        
        [self recenterMap:nil];
        
        [self layoutView];
    }
}

#pragma mark - gridview

- (NSUInteger) numberOfItemsInGridView: (AQGridView *) aGridView {
    return AccountGridNumItems;
}

- (CGSize) portraitGridCellSizeForGridView: (AQGridView *) aGridView {
    return CGSizeMake( floorf( CGRectGetWidth(self.view.frame) / 2.0f ), floorf( self.gridView.frame.size.height / 2.0f ) );
}

- (AQGridViewCell *) gridView: (AQGridView *) aGridView cellForItemAtIndex: (NSUInteger) index {    
    AccountGridCell *cell = [AccountGridCell cellForGridView:aGridView];
    
    NSString *value = nil;
    enum FieldType ft = TextField;
    NSInteger indexCounter = index;
        
    ZKDescribeLayout *layout = [[SFVUtil sharedSFVUtil] layoutForRecord:self.account];
    
    for( ZKDescribeLayoutSection *section in [layout detailLayoutSections] )
        for( ZKDescribeLayoutRow *row in [section layoutRows] )
            for( ZKDescribeLayoutItem *item in [row layoutItems] ) {
                if( [item placeholder] )
                    continue;
                
                NSArray *components = [item layoutComponents];
                
                if( !components || [components count] != 1 )
                    continue;
                
                ZKDescribeLayoutComponent *component = [components objectAtIndex:0];
                
                if( [component type] != zkComponentTypeField )
                    continue;
                
                if( [[SFVAppCache sharedSFVAppCache] doesField:[component value]
                                                      onObject:[self.account objectForKey:kObjectTypeKey]
                                                  haveProperty:FieldIsHTML] )
                    continue;
                
                NSString *fieldType = [[SFVAppCache sharedSFVAppCache] field:[component value]
                                                                    onObject:[self.account objectForKey:kObjectTypeKey]
                                                              stringProperty:FieldType];
                
                if( [fieldType isEqualToString:@"reference"] )
                    continue;
                
                indexCounter--;
                
                if( indexCounter < 0 ) {                    
                    value = [[SFVUtil sharedSFVUtil] textValueForField:[component value]
                                                        withDictionary:self.account];
                    
                    if( [fieldType isEqualToString:@"email"] )
                        ft = EmailField;
                    else if( [fieldType isEqualToString:@"url"] )
                        ft = URLField;
                    else if( [fieldType isEqualToString:@"phone"] )
                        ft = PhoneField;
                                        
                    CGSize s = [self portraitGridCellSizeForGridView:aGridView];
                    
                    [cell setFrame:CGRectMake(0, 0, s.width, s.height)];
                    
                    [cell setupCellWithButton:[item label] 
                                   buttonType:ft 
                                   buttonText:value 
                                   detailText:value];
                    
                    ((FieldPopoverButton *)cell.gridButton).detailViewController = self.detailViewController;
                    [cell layoutCell];
                    
                    return cell;
                }
            }
    
    CGSize s = [self portraitGridCellSizeForGridView:aGridView];
    
    [cell setFrame:CGRectMake(0, 0, s.width, s.height)];
    [cell setupCellWithButton:nil buttonType:ft buttonText:nil detailText:nil];
    ((FieldPopoverButton *)cell.gridButton).detailViewController = self.detailViewController;
    [cell layoutCell];
    
    return cell;
}

@end
