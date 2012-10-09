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
#import "SubNavViewController.h"
#import "SFVUtil.h"
#import "RootViewController.h"
#import "DetailViewController.h"
#import "PRPSmartTableViewCell.h"
#import "DSActivityView.h"
#import <QuartzCore/QuartzCore.h>
#import "PullRefreshTableViewController.h"
#import "PRPAlertView.h"
#import "zkSforce.h"
#import "ObjectGridCell.h"
#import "DTCustomColoredAccessory.h"
#import "SFVAppCache.h"
#import "AppPickerCell.h"
#import "SFVAsync.h"
#import "SFRestAPI+SFVAdditions.h"
#import "CreateRecordButton.h"

// TODO this file is a monster. Subclass the beast within

@interface SubNavViewController (Private)
// we can drill into listviews for a tab if it's a tab for an sObject
// OR for reports/dashboards
+ (BOOL) canDrillIntoTab:(ZKDescribeTab *)tab;
+ (NSString *) sObjectNameForTab:(ZKDescribeTab *)tab;
@end

@implementation SubNavViewController

@synthesize myRecords, detailViewController, searchBar, searchResults, rootViewController, pullRefreshTableViewController, subNavTableType, subNavOrderingType, subNavObjectListType, sObjectType, appIndex;

// Maximum length of a search term
static int const maxSearchLength        = 35;

// Delay, in seconds, between keying a character into the search bar and firing SOSL
static float const searchDelay          = 0.4f;

// Tag used to locate helper views
static int const helperTag              = 11;

// Maximum number of accounts to load via queryMore chains
static int const maxAccounts            = 100000;

// Size of footer view
static CGFloat const kFooterHeight      = 52.0f;
static int const kMaxTitleLength        = 14;

static NSString *indexAlphabet          = @"#ABCDEFGHIJKLMNOPQRSTUVWXYZ";
static NSString *emptyCellIdentifier    = @"HiddenCellIdentifier";
static NSString *draggingCellIdentifier = @"DraggingCellIdentifier";

#pragma mark - setup

- (id) initWithTableType:(enum SubNavTableType)tableType {
    if((self = [super init])) {        
        [self.view setFrame:CGRectMake(0, 0, masterWidth, 704 )];
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
        self.view.autoresizingMask = UIViewAutoresizingFlexibleHeight;
        self.contentSizeForViewInPopover = self.view.frame.size;
        
        self.myRecords = [NSMutableDictionary dictionary];
        self.searchResults = [NSMutableDictionary dictionary];
        
        subNavTableType = tableType;
        storedSize = 0;
        searching = NO;
        isSearchPending = NO;
        queryingMore = NO;
        subNavOrderingType = OrderingName;
        isGridviewDraggable = ( tableType == SubNavFavoriteObjects );
        _emptyCellIndex = NSNotFound;
                
        float curY = 0.0f;
        
        // Top section
        tableHeader = [[UIView alloc] initWithFrame:CGRectZero];
        tableHeader.backgroundColor = [UIColor colorWithWhite:0.0f alpha:0.2f];
        tableHeader.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight;
        
        // search bar        
        if( subNavTableType != SubNavFavoriteObjects && subNavTableType != SubNavListOfRemoteRecords && 
            subNavTableType != SubNavAppPicker && subNavTableType != SubNavAppTabPicker ) {
            self.searchBar = [[[UISearchBar alloc] initWithFrame:CGRectZero] autorelease];
            
            CGSize s = [self.searchBar sizeThatFits:CGSizeZero];
            [searchBar setFrame:CGRectMake(0, 7, masterWidth, s.height)];
            searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
            searchBar.keyboardType = UIKeyboardTypeDefault;
            searchBar.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
            searchBar.delegate = self;
            
            // background
            [[searchBar.subviews objectAtIndex:0] removeFromSuperview];
            
            for (UIView *view in searchBar.subviews)
                if ([view isKindOfClass: [UITextField class]]) {
                    UITextField *tf = (UITextField *)view;
                    tf.delegate = self;
                    break;
                }
                        
            [tableHeader addSubview:searchBar];
            curY = CGRectGetMaxY(searchBar.frame);
        }
        
        if( subNavTableType == SubNavListOfRemoteRecords ) {
            orderingControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake( 10, curY + 5, masterWidth - 20, 30 )];
            
            [orderingControl setSegmentedControlStyle:UISegmentedControlStyleBar];
            [orderingControl insertSegmentWithTitle:NSLocalizedString(@"Name", @"Name") atIndex:0 animated:YES];
            [orderingControl setSelectedSegmentIndex:0];
            orderingControl.enabled = YES;
            orderingControl.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin;
            
            [tableHeader addSubview:orderingControl];
            
            curY = CGRectGetMaxY(orderingControl.frame) + 5;
        }
        
        [tableHeader setFrame:CGRectMake(0, 0, masterWidth, curY)];
        
        CAGradientLayer *shadowLayer = [CAGradientLayer layer];
        shadowLayer.backgroundColor = [UIColor clearColor].CGColor;
        shadowLayer.frame = CGRectMake(0, curY, masterWidth, 5);
        shadowLayer.shouldRasterize = YES;
        
        shadowLayer.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0.0 alpha:0.01].CGColor,
                              (id)[UIColor colorWithWhite:0.0 alpha:0.2].CGColor,
                              (id)[UIColor colorWithWhite:0.0 alpha:0.4].CGColor,
                              (id)[UIColor colorWithWhite:0.0 alpha:0.8].CGColor, nil];		
        
        shadowLayer.startPoint = CGPointMake(0.0, 1.0);
        shadowLayer.endPoint = CGPointMake(0.0, 0.0);
        
        shadowLayer.shadowPath = [UIBezierPath bezierPathWithRect:shadowLayer.bounds].CGPath;
        
        [tableHeader.layer addSublayer:shadowLayer];
        [self.view addSubview:tableHeader];
        
        // table view
        if( subNavTableType == SubNavFavoriteObjects ) {
            gridView = [[AQGridView alloc] initWithFrame:CGRectMake(0, curY, masterWidth, CGRectGetHeight(self.view.frame) - curY - kFooterHeight )];
            
            gridView.delegate = self;
            gridView.dataSource = self;
            gridView.separatorStyle = AQGridViewCellSeparatorStyleNone;
            gridView.backgroundColor = [UIColor clearColor];
            gridView.resizesCellWidthToFit = NO;
            gridView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
            gridView.alwaysBounceVertical = YES;
            
            if( isGridviewDraggable ) {
                // add our gesture recognizer to the grid view
                UILongPressGestureRecognizer *gr = [[UILongPressGestureRecognizer alloc] initWithTarget:self 
                                                                                                  action:@selector(moveActionGestureRecognizerStateChanged:)];
                gr.minimumPressDuration = 0.5;
                gr.delegate = self;
                [gridView addGestureRecognizer: gr];
                [gr release];
            }
            
            [self.view insertSubview:gridView belowSubview:tableHeader];
            [self.view bringSubviewToFront:tableHeader];
            
            curY = CGRectGetMaxY(gridView.frame);
        } else {
            UITableViewController *ptvc = nil;
            
            if( subNavTableType == SubNavListOfRemoteRecords )
                ptvc = (PullRefreshTableViewController *)[[PullRefreshTableViewController alloc] initWithStyle:UITableViewStylePlain useHeaderImage:NO];
            else
                ptvc = [[UITableViewController alloc] initWithStyle:UITableViewStylePlain];
            
            ptvc.tableView.delegate = self;
            ptvc.tableView.dataSource = self;
            
            ptvc.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
            ptvc.tableView.separatorColor = UIColorFromRGB(0x252525);
            ptvc.tableView.sectionIndexMinimumDisplayRowCount = 6;
            ptvc.tableView.scrollEnabled = YES;
            ptvc.tableView.showsVerticalScrollIndicator = YES;
            ptvc.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
            ptvc.tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
                        
            self.pullRefreshTableViewController = ptvc;
            [ptvc release];
            
            // Table Footer            
            UIImage *i = [UIImage imageNamed:@"tilde.png"];
            UIImageView *iv = [[[UIImageView alloc] initWithImage:i] autorelease];
            iv.alpha = 0.25f;
            [iv setFrame:CGRectMake( lroundf( ( masterWidth - i.size.width ) / 2.0f ), 10, i.size.width, i.size.height )];
            
            UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, masterWidth, 70 )] autorelease];
            [footerView addSubview:iv];
            
            self.pullRefreshTableViewController.tableView.tableFooterView = footerView;
            
            CGRect r = self.view.frame;
            r.origin.y = tableHeader.frame.size.height;
            r.size.height = self.view.frame.size.height - r.origin.y - kFooterHeight;
            [self.pullRefreshTableViewController.tableView setFrame:r];
            
            [self.view addSubview:self.pullRefreshTableViewController.view];
            
            curY = CGRectGetMaxY(self.pullRefreshTableViewController.tableView.frame);
        }
        
        // number of records count label
        rowCountLabel = [[UILabel alloc] initWithFrame:CGRectMake( 0, 0, 150, 35 )];
        rowCountLabel.backgroundColor = [UIColor clearColor];
        rowCountLabel.font = [UIFont boldSystemFontOfSize:15];
        rowCountLabel.shadowColor = [UIColor blackColor];
        rowCountLabel.shadowOffset = CGSizeMake( 0, 2 );
        rowCountLabel.textColor = [UIColor lightGrayColor];
        rowCountLabel.textAlignment = UITextAlignmentCenter;
        
        // bottom bar
        bottomBar = [[TransparentToolBar alloc] initWithFrame:CGRectMake( 0, curY, masterWidth, kFooterHeight )];
        bottomBar.tintColor = [UIColor clearColor];
        bottomBar.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        
        // bar shadow
        shadowLayer = [CAGradientLayer layer];
        shadowLayer.backgroundColor = [UIColor clearColor].CGColor;
        shadowLayer.frame = CGRectMake(0, -5, masterWidth, 5);
        shadowLayer.shouldRasterize = YES;
        
        shadowLayer.colors = [NSArray arrayWithObjects:(id)[UIColor colorWithWhite:0.0 alpha:0.01].CGColor,
                              (id)[UIColor colorWithWhite:0.0 alpha:0.2].CGColor,
                              (id)[UIColor colorWithWhite:0.0 alpha:0.4].CGColor,
                              (id)[UIColor colorWithWhite:0.0 alpha:0.8].CGColor, nil];		
        
        shadowLayer.startPoint = CGPointMake(0.0, 0.0);
        shadowLayer.endPoint = CGPointMake(0.0, 1.0);
        
        shadowLayer.shadowPath = [UIBezierPath bezierPathWithRect:shadowLayer.bounds].CGPath;
        
        [bottomBar.layer addSublayer:shadowLayer];
        
        
        UIImage *buttonImage = [UIImage imageNamed:@"gear2.png"];
        
        UIButton *gearButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [gearButton setImage:buttonImage forState:UIControlStateNormal];
        [gearButton addTarget:self
                       action:@selector(showSettings:)
             forControlEvents:UIControlEventTouchUpInside];
        [gearButton setFrame:CGRectMake( 0, 0, buttonImage.size.width, buttonImage.size.height )];
        
        UIBarButtonItem *gear = [[[UIBarButtonItem alloc] initWithCustomView:gearButton] autorelease];
        
        UIBarButtonItem *space = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                target:nil
                                                                                action:nil] autorelease];
        
        buttonImage = [UIImage imageNamed:@"home.png"];
        
        UIButton *homeButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [homeButton setImage:buttonImage forState:UIControlStateNormal];
        [homeButton addTarget:self
                       action:@selector(tappedLogo:)
             forControlEvents:UIControlEventTouchUpInside];
        [homeButton setFrame:CGRectMake( 0, 0, buttonImage.size.width, buttonImage.size.height )];
        
        UIBarButtonItem *home = [[[UIBarButtonItem alloc] initWithCustomView:homeButton] autorelease];
        
        UIBarButtonItem *count = [[[UIBarButtonItem alloc] initWithCustomView:rowCountLabel] autorelease];
        
        [bottomBar setItems:[NSArray arrayWithObjects:home, space, count, space, gear, nil] animated:YES];
        
        [self.view addSubview:bottomBar];
    }
        
    return self;
}

- (void) pushTitle:(NSString *)title leftItem:(UIBarButtonItem *)leftItem rightItem:(UIBarButtonItem *)rightItem animated:(BOOL)animated {            
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    [button setFrame:CGRectMake(0, 0, masterWidth - 85, 44 )];
    [button addTarget:self action:@selector(tappedHeader:) forControlEvents:UIControlEventTouchUpInside];
    
    UILabel *headerLabel = [[UILabel alloc] init];
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.text = title;
    headerLabel.font = [UIFont boldSystemFontOfSize:22];
    headerLabel.numberOfLines = 1;
    headerLabel.textColor = [UIColor whiteColor];
    headerLabel.textAlignment = UITextAlignmentCenter;
    headerLabel.shadowColor = [UIColor darkGrayColor];
    headerLabel.shadowOffset = CGSizeMake( 0, 2 );
    [headerLabel sizeToFit];
    
    headerLabel.frame = CGRectMake( floorf( ( CGRectGetWidth(button.frame) - headerLabel.frame.size.width ) / 2.0f ) - 10,
                                   floorf( ( 44 - CGRectGetHeight(headerLabel.frame) ) / 2.0f ), 
                                   headerLabel.frame.size.width, headerLabel.frame.size.height);
        
    UILabel *down = [[UILabel alloc] init];
    down.text = DownArrowCharacter;
    down.backgroundColor = [UIColor clearColor];
    down.textColor = AppSecondaryColor;
    down.font = [UIFont boldSystemFontOfSize:20];
    [down sizeToFit];
    
    down.frame = CGRectMake( CGRectGetMaxX(headerLabel.frame) + 3, CGRectGetMinY(headerLabel.frame) + 2, 
                            down.frame.size.width, down.frame.size.height);

    [button addSubview:headerLabel];
    [button addSubview:down];
    [down release];
    [headerLabel release];
        
    UINavigationItem *item = self.navigationItem;
    
    item.leftBarButtonItem = leftItem;
    item.rightBarButtonItem = rightItem;
    item.titleView = button;
    item.hidesBackButton = YES;
}

- (void) tappedHeader:(UIButton *)sender {    
    if( sheet ) {
        [sheet dismissWithClickedButtonIndex:-1 animated:YES];
        SFRelease(sheet);
        return;
    }
    
    sheet = [[UIActionSheet alloc] init];
    sheet.delegate = self;
    sheet.actionSheetStyle = UIActionSheetStyleBlackOpaque;
    
    for( NSNumber *appNum in [self.rootViewController availableApps] ) {
        int appval = [appNum intValue];
        
        if( appval == SubNavAppPicker )
            [sheet addButtonWithTitle:NSLocalizedString(@"Apps", @"Apps")];
        else if( appval == SubNavAllObjects )
            [sheet addButtonWithTitle:NSLocalizedString(@"All Objects", @"All Objects")];
        else if( appval == SubNavFavoriteObjects )
            [sheet addButtonWithTitle:NSLocalizedString(@"Favorites", @"Favorites")];
    }
    
    if( [RootViewController isPortrait] )
        sheet.cancelButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Cancel", @"Cancel")];
    
    [sheet showFromRect:sender.frame
                 inView:self.rootViewController.view animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {    
    if( buttonIndex != actionSheet.cancelButtonIndex ) {
        SubNavTableType type;
                
        int ourPos = INT16_MAX;
        
        for( int i = 0; i < [AppPickerApps count]; i++ )
            if( [[AppPickerApps objectAtIndex:i] intValue] == self.subNavTableType ) {
                ourPos = i;
                break;
            }
                
        type = [[AppPickerApps objectAtIndex:( buttonIndex + ( ourPos <= buttonIndex ? 1 : 0 ))] intValue];
        
        [self.rootViewController popAllSubNavControllers];
        [self.rootViewController pushSubNavControllerWithType:SubNavDummyController animated:NO];
        [self.rootViewController pushSubNavControllerWithType:type animated:YES];
    }
    
    SFRelease(sheet);
}

- (NSArray *) listsForObject {
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:ObjectListNumTypes];
    
    for( int i = 0; i < ObjectListNumTypes; i++ ) {
        if( i == ObjectListRecentRecords ) {
            NSArray *records =  [[SFVUtil sharedSFVUtil] recentRecordsForSObject:sObjectType];
            
            if( !records || [records count] == 0 )
                continue;
        }
        
        if( ( i == ObjectListMyUpcomingEvents || i == ObjectListMyPastEvents ) && ![sObjectType isEqualToString:@"Event"] )
            continue;
        
        if( i == ObjectListMyOpenCases && ![sObjectType isEqualToString:@"Case"] )
            continue;
        
        if( ( i == ObjectListMyUpcomingOpportunities || i == ObjectListMyClosedOpportunities ) && ![sObjectType isEqualToString:@"Opportunity"] )
            continue;
        
        if( i == ObjectListMyUnreadLeads && ![sObjectType isEqualToString:@"Lead"] )
            continue;
        
        if( i == ObjectListMyOpenTasks && ![sObjectType isEqualToString:@"Task"] )
            continue;
        
        if( i == ObjectListRecordsIOwn && ![[SFVAppCache sharedSFVAppCache] describeForField:@"OwnerId" onObject:sObjectType] )
            continue;
        
        if( i == ObjectListRecordsIFollow && ![[SFVAppCache sharedSFVAppCache] doesGlobalObject:sObjectType haveProperty:GlobalObjectIsFeedEnabled] )
            continue;
        
        [ret addObject:[NSNumber numberWithInt:i]];
    }
    
    return ret;
}

- (UIViewAnimationTransition) animationTransitionForPush {
    switch( subNavTableType ) {
        case SubNavFavoriteObjects:
        case SubNavAllObjects:
        case SubNavAppPicker:
            return UIViewAnimationTransitionFlipFromLeft;
        default:
            return UIViewAnimationTransitionCurlUp;
    }
}

- (UIViewAnimationTransition) animationTransitionForPop {
    switch( subNavTableType ) {
        case SubNavFavoriteObjects:
        case SubNavAllObjects:
        case SubNavAppPicker:
            return UIViewAnimationTransitionFlipFromRight;
        default:
            return UIViewAnimationTransitionCurlDown;
    }
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.searchBar resignFirstResponder];
    
    if( gridView )
        [self.view bringSubviewToFront:gridView];
        
    if( subNavTableType == SubNavAllObjects )
        [self.navigationItem setHidesBackButton:YES animated:YES];
}

- (void) clearRecords {
    [self.myRecords removeAllObjects];    
    storedSize = 0;
    
    rowCountLabel.text = @"";
    
    [gridView reloadData];
    [gridView setContentOffset:CGPointZero animated:NO];
    [self.pullRefreshTableViewController.tableView reloadData];
    [self.pullRefreshTableViewController.tableView setContentOffset:CGPointZero animated:NO];
}

- (void)dealloc {
    [searchBar release];
    [searchResults release];
    [myRecords release];
    [rowCountLabel release];
    [pullRefreshTableViewController release];
    [bottomBar release];
    [sObjectType release];
    SFRelease(orderingControl);
    SFRelease(refreshButton);
    SFRelease(gridView);
    SFRelease(queryLocator);
    SFRelease(loadingView);
    SFRelease(sheet);
    
    [super dealloc];
}

#pragma mark - query helpers

- (NSArray *) orderClauseForQuery {
    NSString *ordering = nil;
    
    if( orderingControl.selectedSegmentIndex <= 0 )
        ordering = [NSString stringWithFormat:@"%@ asc", 
                    ( [[NSArray arrayWithObjects:@"Lead", @"Contact", nil] containsObject:sObjectType]
                      ? @"LastName"
                      : [[SFVAppCache sharedSFVAppCache] nameFieldForsObject:sObjectType] )];
    else if( [[orderingControl titleForSegmentAtIndex:1] isEqualToString:NSLocalizedString(@"Created", @"Created")] &&
            orderingControl.selectedSegmentIndex == 1 )
        ordering = @"createddate desc";
    else
        ordering = @"lastmodifieddate desc";
    
    return [NSArray arrayWithObject:ordering];
}

- (NSString *) queryForRecords {
    if( subNavTableType != SubNavListOfRemoteRecords )
        return @"";
    
    NSString *where = nil;
    
    switch( subNavObjectListType ) {
        case ObjectListMyUpcomingEvents:
            where = [NSString stringWithFormat:@"ownerid='%@' and "
                      "( activitydate >= %@ or activitydatetime >= %@ )",
                      [[SFVUtil sharedSFVUtil] currentUserId],
                      [SFVUtil SOQLDatetimeFromDate:[NSDate date] isDateTime:NO],
                      [SFVUtil SOQLDatetimeFromDate:[NSDate date] isDateTime:YES]];
            break;
        case ObjectListMyPastEvents:
            where = [NSString stringWithFormat:@"ownerid='%@' and "
                     "( activitydate <= %@ or activitydatetime <= %@ )",
                     [[SFVUtil sharedSFVUtil] currentUserId],
                     [SFVUtil SOQLDatetimeFromDate:[NSDate date] isDateTime:NO],
                     [SFVUtil SOQLDatetimeFromDate:[NSDate date] isDateTime:YES]];
            break;
        case ObjectListMyOpenTasks:
        case ObjectListMyOpenCases:
            where = [NSString stringWithFormat:@"ownerid='%@' and isclosed=false",
                     [[SFVUtil sharedSFVUtil] currentUserId]];
            break;
        case ObjectListMyUnreadLeads:
            where = [NSString stringWithFormat:@"ownerid='%@' and isunreadbyowner=true and isconverted=false",
                     [[SFVUtil sharedSFVUtil] currentUserId]];
            break;
        case ObjectListRecordsICreated:
            where = [NSString stringWithFormat:@"createdbyid = '%@'", 
                     [[SFVUtil sharedSFVUtil] currentUserId]];
            break;
        case ObjectListRecordsIOwn:
            where = [NSString stringWithFormat:@"ownerid = '%@'", 
                     [[SFVUtil sharedSFVUtil] currentUserId]];
            break;
        case ObjectListRecordsIRecentlyModified:
            where = [NSString stringWithFormat:@"lastmodifiedbyid = '%@'", 
                     [[SFVUtil sharedSFVUtil] currentUserId]];
            break;
        case ObjectListMyUpcomingOpportunities:
            where = [NSString stringWithFormat:@"ownerid='%@' and isclosed=false and closedate >= %@ and closedate <= %@",
                     [[SFVUtil sharedSFVUtil] currentUserId],
                     [SFVUtil SOQLDatetimeFromDate:[NSDate date] isDateTime:NO],
                     [SFVUtil SOQLDatetimeFromDate:[NSDate dateWithTimeIntervalSinceNow:( 60 * 60 * 24 * 7 * 4 )]
                                        isDateTime:NO]];
            break;
        case ObjectListMyClosedOpportunities:
            where = [NSString stringWithFormat:@"ownerid='%@' and isclosed=true",
                     [[SFVUtil sharedSFVUtil] currentUserId]];
            break;
        default:
            break;
    }
    
    return [SFVAsync SOQLQueryWithFields:[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:sObjectType]
                                 sObject:sObjectType
                                   where:where
                                 groupBy:nil
                                  having:nil
                                 orderBy:[self orderClauseForQuery]
                                   limit:0];
}

#pragma mark - querying

- (void) refresh {            
    [self updateTitleBar];
    
    if( searching ) {
        [self searchTableView];
        return;
    }
    
    [self setLoadingViewVisible:NO];
    
    if (queryLocator)
        SFRelease(queryLocator);
    
    [self clearRecords];
    
    switch( subNavTableType ) {
        case SubNavAppPicker: {
            if( !refreshButton )
                refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                              target:self
                                                                              action:@selector(refreshGlobalObjects:)];
            
            [self pushTitle:NSLocalizedString(@"Apps", @"Apps") leftItem:refreshButton
                  rightItem:nil animated:YES];
            
            NSArray *apps = [[SFVAppCache sharedSFVAppCache] listAllAppLabels];
            
            rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                  [apps count],
                                  ( [apps count] != 1 ? 
                                   NSLocalizedString(@"Apps", @"App plural") :
                                   NSLocalizedString(@"App", @"App") )];
            
            [self.pullRefreshTableViewController.tableView reloadData];
            
            break;
        }
        case SubNavAppTabPicker: {
            NSArray *tabs = [[SFVAppCache sharedSFVAppCache] listTabsForAppAtIndex:self.appIndex];
            
            rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                  [tabs count],
                                  ( [tabs count] != 1 ? 
                                   NSLocalizedString(@"Tabs", @"Tab plural") :
                                   NSLocalizedString(@"Tab", @"Tab") )];
            
            [self.pullRefreshTableViewController.tableView reloadData];
            break;
        }
        case SubNavAllObjects:            
            if( !refreshButton )
                refreshButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemRefresh
                                                                                    target:self
                                                                                    action:@selector(refreshGlobalObjects:)];
            
            [self pushTitle:NSLocalizedString(@"All Objects", @"All Objects") leftItem:refreshButton
                                     rightItem:nil animated:YES];
            
            searchBar.placeholder = NSLocalizedString(@"Filter Objects", @"Filter Objects");
            
            NSMutableArray *objects = [NSMutableArray array];
            
            for( NSString *ob in [[SFVAppCache sharedSFVAppCache] allGlobalSObjects] )
                [objects addObject:ob];
            
            // Merge new objects with saved objects
            NSArray *savedObjects = [[NSUserDefaults standardUserDefaults] arrayForKey:GlobalObjectOrderingKey];
            
            if( savedObjects && [savedObjects count] > 0 )
                objects = [NSMutableArray arrayWithArray:[SFVUtil mergeObjectArray:objects withArray:savedObjects]];
            
            // Filter for duplicates and objects no longer existing and            
            // Sort by label plural
            NSArray *sortedObjects = [[SFVUtil sharedSFVUtil] sortGlobalObjectArray:[[SFVUtil sharedSFVUtil] filterGlobalObjectArray:objects]];
            
            for( NSString *object in sortedObjects )
                [self.myRecords setObject:[[SFVAppCache sharedSFVAppCache] labelForSObject:object usePlural:YES] forKey:object];
            
            // Write to saved records
            [[NSUserDefaults standardUserDefaults] setObject:sortedObjects forKey:GlobalObjectOrderingKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                  [self.myRecords count],
                                  ( [self.myRecords count] != 1 ? 
                                   NSLocalizedString(@"Objects", @"sObject plural") :
                                   NSLocalizedString(@"Object", @"sObject") )];
            
            [self.pullRefreshTableViewController.tableView reloadData];
            
            break;
        case SubNavListOfRemoteRecords:
            self.pullRefreshTableViewController.tableView.scrollEnabled = YES;
            
            // Ensure our segmented control is set up properly
            if( orderingControl.numberOfSegments == 1 ) {
                if( subNavObjectListType != ObjectListRecordsIRecentlyModified &&
                    subNavObjectListType != ObjectListAllRecentlyModified )
                    [orderingControl insertSegmentWithTitle:NSLocalizedString(@"Created", @"Created") atIndex:orderingControl.numberOfSegments animated:YES];
                
                if( subNavObjectListType != ObjectListRecordsICreated &&
                    subNavObjectListType != ObjectListAllRecentlyCreated )
                    [orderingControl insertSegmentWithTitle:NSLocalizedString(@"Modified", @"Modified") atIndex:orderingControl.numberOfSegments animated:YES]; 
                
                // Choose a proper default setting for the segment
                if( orderingControl.numberOfSegments == 2 )
                    [orderingControl setSelectedSegmentIndex:1];
                
                [orderingControl addTarget:self action:@selector(refresh) forControlEvents:UIControlEventValueChanged];
            }
            
            // If this is a creatable object, add a create button to our nav
            if( [CreateRecordButton objectCanBeCreated:sObjectType] ) {
                CreateRecordButton *button = [CreateRecordButton buttonForObject:sObjectType];
                button.detailViewController = self.detailViewController;
                
                [self.navigationItem setRightBarButtonItem:button
                                                  animated:YES];
            } else
                [self.navigationItem setRightBarButtonItem:nil
                                                  animated:YES];
            
            [DSBezelActivityView newActivityViewForView:self.pullRefreshTableViewController.tableView];
            orderingControl.enabled = NO;
            orderingControl.alpha = 0.3f;
            
            [[SFAnalytics sharedInstance] tagEventOfType:SFVUserLoadedListView
                                              attributes:[NSDictionary dictionaryWithObject:sObjectType forKey:@"Object"]];
            
            if( subNavObjectListType != ObjectListRecordsIFollow ) {
                
                if( subNavObjectListType == ObjectListRecentRecords ) {
                    NSArray *records = [[SFVUtil sharedSFVUtil] recentRecordsForSObject:sObjectType];
                    
                    if( !records || [records count] == 0 ) {
                        [self refreshResult:nil];
                        return;
                    }
                    
                    [SFVAsync performRetrieveWithFields:[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:sObjectType] 
                                                 sObject:sObjectType
                                                     ids:records
                                               failBlock:^(NSException *e) {
                                                   if( ![self isViewLoaded] ) 
                                                       return;
                                                   
                                                   [DSBezelActivityView removeViewAnimated:YES];
                                                   
                                                   [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                                                   
                                                   return;
                                               }
                                           completeBlock:^(NSDictionary *records) {
                                               if( ![self isViewLoaded] ) 
                                                   return;
                                               
                                               if( records && [records count] > 0 )
                                                   [self refreshResult:[records allValues]];
                                               else
                                                   [self refreshResult:nil];
                                           }];
                } else 
                    [SFVAsync performSOQLQuery:[self queryForRecords]
                                    failBlock:^(NSException *e) {
                                        if( ![self isViewLoaded] ) 
                                            return;
                                        
                                        [DSBezelActivityView removeViewAnimated:YES];
                                        
                                        [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                                        
                                        return;
                                    }
                                completeBlock:^(ZKQueryResult *qr) {
                                    if( ![self isViewLoaded] ) 
                                        return;
                                    
                                    if( qr && [qr records] && [[qr records] count] > 0 ) {
                                        [self refreshResult:[qr records]];
                                        
                                        if( [qr queryLocator] )
                                            queryLocator = [[qr queryLocator] copy];
                                    } else
                                        [self refreshResult:nil];
                                }];
            } else {
                // Nested query to get our followed records first
                
                NSString *followSOQL = [SFVAsync SOQLQueryWithFields:[NSArray arrayWithObject:@"parentId"]
                                                             sObject:@"EntitySubscription"
                                                               where:[NSString stringWithFormat:@"subscriberid = '%@' and parent.type='%@'",
                                                                                            [[SFVUtil sharedSFVUtil] currentUserId],
                                                                                            sObjectType]
                                                               limit:450];
                
                [[SFRestAPI sharedInstance] performSOQLQuery:followSOQL
                                                   failBlock:^(NSError *e) {
                                                       if( ![self isViewLoaded] ) 
                                                           return;
                                                       
                                                       [DSBezelActivityView removeViewAnimated:YES];
                                                       
                                                       [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                                                   }
                                               completeBlock:^(NSDictionary *qr) {
                                                   if( ![self isViewLoaded] ) 
                                                       return;
                                                   
                                                   // Do we follow any accounts?
                                                   if( !qr || [[qr objectForKey:@"records"] count] == 0 ) {
                                                       [self refreshResult:nil];
                                                       return;
                                                   }
                                                   
                                                   NSMutableArray *followedRecordIds = [NSMutableArray array];
                                                   
                                                   for( NSDictionary *followedRecord in [qr objectForKey:@"records"] )
                                                       [followedRecordIds addObject:[followedRecord objectForKey:@"ParentId"]];
                                                   
                                                   // TODO this should probably be a retrieve, but then we'd have to sort clientside
                                                   NSString *followQuery = [SFVAsync SOQLQueryWithFields:[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:sObjectType]
                                                                                                 sObject:sObjectType
                                                                                                   where:[NSString stringWithFormat:@"id IN ('%@')", 
                                                                                                          [followedRecordIds componentsJoinedByString:@"','"]]
                                                                                                 groupBy:nil
                                                                                                  having:nil
                                                                                                 orderBy:[NSArray arrayWithObject:[NSString stringWithFormat:@"%@ asc",
                                                                                                                                   [[SFVAppCache sharedSFVAppCache] nameFieldForsObject:sObjectType]]]
                                                                                                   limit:0];
                                                   
                                                   [[SFRestAPI sharedInstance] performSOQLQuery:followQuery
                                                                                      failBlock:^(NSError *e) {
                                                                                          if( ![self isViewLoaded] ) 
                                                                                              return;
                                                                                          
                                                                                          [DSBezelActivityView removeViewAnimated:YES];
                                                                                          
                                                                                          [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                                                                                      }
                                                                                  completeBlock:^(NSDictionary *dict) {
                                                                                      if( ![self isViewLoaded] ) 
                                                                                          return;
                                                                                      
                                                                                      if( dict && [[dict objectForKey:@"records"] count] > 0 )
                                                                                          [self refreshResult:[dict objectForKey:@"records"]];
                                                                                      else
                                                                                          [self refreshResult:nil];
                                                                                  }];
                                               }];
            }
            
            break;
        case SubNavObjectListTypePicker:
            // sObjectType isn't set until after init but before refresh, so
            // check now if this object is searchable.
            // This is a little janky            
            if( ![[SFVAppCache sharedSFVAppCache] doesGlobalObject:sObjectType haveProperty:GlobalObjectIsSearchable] && !tableHeader.hidden ) {
                [UIView animateWithDuration:0.5f 
                                      delay:0.25f
                                    options:UIViewAnimationOptionCurveEaseInOut
                                 animations:^(void) {
                                     tableHeader.alpha = 0.0f;
                                     
                                     [self.pullRefreshTableViewController.tableView setFrame:CGRectMake( 0, 0, 
                                                                                                        masterWidth, self.view.frame.size.height - kFooterHeight )];
                                 }
                                 completion:^(BOOL finished) {
                                     tableHeader.hidden = YES;
                                 }];
            } 
            
            [DSBezelActivityView newActivityViewForView:self.view];
            
            [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:sObjectType
                                                            failBlock:nil
                                                        completeBlock:^(NSDictionary *dict) {
                                                            if( ![self isViewLoaded] ) 
                                                                return;
                                                            
                                                            [DSBezelActivityView removeViewAnimated:YES];
                                                            [self.pullRefreshTableViewController.tableView reloadData];
                                                            
                                                            searchBar.placeholder = [NSString stringWithFormat:@"%@ %@",
                                                                                     NSLocalizedString(@"All", @"All"),
                                                                                     [[SFVAppCache sharedSFVAppCache] labelForSObject:sObjectType usePlural:YES]];
                                                            rowCountLabel.text = @"";
                                                            
                                                            [self.navigationItem setRightBarButtonItem:[self favoriteBarButtonItem]
                                                                                              animated:NO];
                                                        }];
            
            break;
        case SubNavFavoriteObjects: {
            [self pushTitle:NSLocalizedString(@"Favorites", @"Favorites")
                   leftItem:nil rightItem:nil animated:YES];
            
            NSArray *favs = [[self class] loadFavoriteObjects];
            
            // Save filtered favs back to device
            [[NSUserDefaults standardUserDefaults] setObject:favs forKey:FavoriteObjectsKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            if( favs && [favs count] > 0 ) {
                for( NSString *fav in favs )
                    [self.myRecords setObject:[[SFVAppCache sharedSFVAppCache] labelForSObject:fav usePlural:YES] forKey:fav];
                
                rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                      [self.myRecords count],
                                      ( [self.myRecords count] != 1 ? 
                                       NSLocalizedString(@"Objects", @"sObject plural") :
                                       NSLocalizedString(@"Object", @"sObject") )];
            } else {
                rowCountLabel.text = @"";
                
                [self toggleNoFavsView];
            }
            
            [gridView reloadData];            
            break;
        }
        default:
            NSLog(@"unhandled subnav type: %i", subNavTableType );
            break;
    }
}

- (void) refreshResult:(NSArray *)results {
    [DSBezelActivityView removeViewAnimated:YES];
    self.pullRefreshTableViewController.tableView.scrollEnabled = YES;

    if( [self.pullRefreshTableViewController respondsToSelector:@selector(stopLoading)] )
        [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
            
    // Clear out existing accounts on this list
    //[self.myRecords removeAllObjects];
    
    results = [SFVAsync ZKSObjectArrayToDictionaryArray:results];
    
    if( results && [results count] > 0 ) {           
        switch( orderingControl.selectedSegmentIndex ) {
            case OrderingName:
                self.myRecords = [NSMutableDictionary dictionaryWithDictionary:[SFVUtil dictionaryFromAccountArray:results]];
                break;
            default:
                if( orderingControl.selectedSegmentIndex == 1 && [[orderingControl titleForSegmentAtIndex:1] isEqualToString:NSLocalizedString(@"Created", @"Created")] )
                    self.myRecords = [NSMutableDictionary dictionaryWithDictionary:[SFVUtil dictionaryFromRecordsGroupedByDate:results dateField:@"CreatedDate"]];
                else
                    self.myRecords = [NSMutableDictionary dictionaryWithDictionary:[SFVUtil dictionaryFromRecordsGroupedByDate:results dateField:@"LastModifiedDate"]];
                break;
        }
        
        storedSize = [results count];
        orderingControl.enabled = YES;
        orderingControl.alpha = 1.0f;
        
        rowCountLabel.text = [NSString stringWithFormat:@"%i%@ %@",
                              storedSize,
                              ( queryLocator ? @"+" : @"" ),
                              ( storedSize != 1 ? NSLocalizedString(@"Records", @"Record plural") : NSLocalizedString(@"Record", @"Record singular") )];
        
        [self.pullRefreshTableViewController.tableView reloadData];
        [self.pullRefreshTableViewController.tableView setContentOffset:CGPointZero animated:NO];
        
        if( [self.detailViewController mostRecentlySelectedRecord] )
            [self selectAccountWithId:[[self.detailViewController mostRecentlySelectedRecord] objectForKey:@"Id"]];
    } else {
        storedSize = 0;
        orderingControl.enabled = NO;
        rowCountLabel.text = NSLocalizedString(@"No Records", @"No Records");
        
        [self.pullRefreshTableViewController.tableView reloadData];
        [self.pullRefreshTableViewController.tableView setContentOffset:CGPointZero animated:NO];
    }
}

- (void) queryMore {
    if( storedSize >= maxAccounts || !queryLocator )
        return;
    
    // If we are no longer visible, stop querying more
    if( ![[self.rootViewController currentSubNavViewController] isEqual:self] ) {
        [[SFVUtil sharedSFVUtil] endNetworkAction];
        return;
    }
    
    queryingMore = YES;
    orderingControl.enabled = NO;
    orderingControl.alpha = 0.3f;
    
    [SFVAsync performQueryMore:queryLocator
                     failBlock:^(NSException *e) {
                         if( ![self isViewLoaded] ) 
                             return;
                         
                         if( [self isEqual:[self.rootViewController currentSubNavViewController]] )
                             [DSBezelActivityView removeViewAnimated:YES];
                         
                         [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                         
                         [self setLoadingViewVisible:NO];
                         
                         orderingControl.enabled = YES;
                         orderingControl.alpha = 1.0f;
                         
                         return;
                     }
                 completeBlock:^(ZKQueryResult *qr) {
                     if( ![self isViewLoaded] ) 
                         return;
                     
                     queryingMore = NO;
                     [self setLoadingViewVisible:NO];
                     orderingControl.enabled = YES;
                     orderingControl.alpha = 1.0f;
                     NSMutableDictionary *toAdd = nil;
                     NSMutableIndexSet *sections = [NSMutableIndexSet indexSet];
                     
                     if( qr && [qr records] && [[qr records] count] > 0 ) {
                         switch( orderingControl.selectedSegmentIndex ) {
                             case OrderingName:
                                 self.myRecords = [NSMutableDictionary dictionaryWithDictionary:
                                                   [SFVUtil dictionaryByAddingAccounts:[qr records]
                                                                          toDictionary:self.myRecords]];
                                 break;
                             default:
                                 if( orderingControl.selectedSegmentIndex == 1 && [[orderingControl titleForSegmentAtIndex:1] isEqualToString:NSLocalizedString(@"Created", @"Created")] )
                                     toAdd = [NSMutableDictionary dictionaryWithDictionary:[SFVUtil dictionaryFromRecordsGroupedByDate:[qr records]
                                                                                                                             dateField:@"CreatedDate"]];
                                 else
                                     toAdd = [NSMutableDictionary dictionaryWithDictionary:[SFVUtil dictionaryFromRecordsGroupedByDate:[qr records]
                                                                                                                             dateField:@"LastModifiedDate"]];
                                 
                                 for( NSNumber *key in [toAdd allKeys] ) {
                                     [sections addIndex:[key intValue]];
                                     
                                     if( ![SFVUtil isEmpty:[self.myRecords objectForKey:key]] )
                                         [[self.myRecords objectForKey:key] addObjectsFromArray:[toAdd objectForKey:key]];
                                     else
                                         [self.myRecords setObject:[toAdd objectForKey:key] forKey:key];  
                                 }
                                 
                                 break;
                         }
                         
                         if( [qr queryLocator] ) {
                             if( queryLocator ) 
                                 SFRelease(queryLocator);
                             
                             queryLocator = [[qr queryLocator] copy];                    
                         } else
                             NSLog(@"no more to query");
                         
                         if( [sections count] > 0 )
                             [self.pullRefreshTableViewController.tableView reloadSections:sections
                                                                          withRowAnimation:UITableViewRowAnimationFade];
                         else
                             [self.pullRefreshTableViewController.tableView reloadData];
                         
                         if( [self.detailViewController mostRecentlySelectedRecord] )
                             [self selectAccountWithId:[[self.detailViewController mostRecentlySelectedRecord] objectForKey:@"Id"]];
                         
                         storedSize += [[qr records] count];
                         rowCountLabel.text = [NSString stringWithFormat:@"%i%@ %@",
                                               storedSize,
                                               ( queryLocator ? @"+" : @"" ),
                                               ( storedSize != 1 ? NSLocalizedString(@"Records", @"Records plural") : NSLocalizedString(@"Record", @"Record singular") )];
                         
                     }
                 }];
}

#pragma mark - scrolling delegate

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if( [self.pullRefreshTableViewController respondsToSelector:@selector(scrollViewDidEndDragging:willDecelerate:)] )
        [self.pullRefreshTableViewController scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if( [self.pullRefreshTableViewController respondsToSelector:@selector(scrollViewWillBeginDragging:)] )
        [self.pullRefreshTableViewController scrollViewWillBeginDragging:scrollView];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [searchBar resignFirstResponder];
    
    if( [self.pullRefreshTableViewController respondsToSelector:@selector(scrollViewDidScroll:)] )
        [self.pullRefreshTableViewController scrollViewDidScroll:scrollView];

    if( subNavTableType == SubNavListOfRemoteRecords && !queryingMore && queryLocator &&
        ([scrollView contentOffset].y + scrollView.frame.size.height) >= [scrollView contentSize].height ) {
        [self setLoadingViewVisible:YES];        
        [self queryMore];
    }
}

#pragma mark - searching table view

- (void) searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar {
    searching = [theSearchBar.text length] > 0;
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)text {
    if( [[textField.text stringByReplacingCharactersInRange:range withString:text] length] >= maxSearchLength )
        return NO;
    
    NSMutableCharacterSet *validChars = [NSMutableCharacterSet punctuationCharacterSet];
    [validChars formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
    [validChars formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    
    NSCharacterSet *unacceptedInput = [validChars invertedSet];
    
    text = [[text lowercaseString] decomposedStringWithCanonicalMapping];
    
    return [[text componentsSeparatedByCharactersInSet:unacceptedInput] count] == 1;
}

- (BOOL) textFieldShouldReturn:(UITextField *)textField {
    return YES;
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText {  
    if([searchText length] > 0) {
        searching = YES;
        
        // If this is a local search, fire it right away. Otherwise, wait for a delay
        if( subNavTableType == SubNavAllObjects )
            [self searchTableView];
        else {
            [NSObject cancelPreviousPerformRequestsWithTarget:self
                                                     selector:@selector(searchTableView)
                                                       object:nil];
            
            [self performSelector:@selector(searchTableView)
                       withObject:nil
                       afterDelay:searchDelay];
        }
    } else {
        [[SFVUtil sharedSFVUtil] endNetworkAction];
        searching = NO;
        isSearchPending = NO;
        
        if( subNavTableType == SubNavAllObjects ) {
            [self.pullRefreshTableViewController.tableView reloadData];
            rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                  [self.myRecords count],
                                  ( [self.myRecords count] != 1 ? 
                                   NSLocalizedString(@"Objects", @"sObject plural") :
                                   NSLocalizedString(@"Object", @"sObject") )];
        } else {
            [self.pullRefreshTableViewController.tableView reloadData];
            
            /*if( storedSize == 0 )
                rowCountLabel.text = NSLocalizedString(@"No Records", @"No Accounts");
            else
                rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                      storedSize,
                                      ( storedSize != 1 ? NSLocalizedString(@"Accounts", @"Account plural") : NSLocalizedString(@"Account", @"Account singular") )];
            */
        }
        
        [self updateTitleBar];
    }
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)theSearchBar {
    NSLog(@"clicked search");
    [searchBar resignFirstResponder];
    [theSearchBar resignFirstResponder];
    [self searchTableView];
}

- (void) cancelSearch {
    if( !searching )
        return;
    
    self.searchBar.text = @"";
    [self.searchBar resignFirstResponder];
    [self searchBar:self.searchBar textDidChange:@""];
}

- (void) searchTableView {    
    NSString *searchText = [NSString stringWithString:searchBar.text];
    
    searchText = [SFVUtil trimWhiteSpaceFromString:searchText];
    
    if( [searchText length] < 1 )
        return;
    
    switch( subNavTableType ) {
        case SubNavAllObjects:
            [self.searchResults removeAllObjects];
            
            for( NSString *name in [self.myRecords allKeys] )
                if( [[self.myRecords objectForKey:name] rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound )
                    [self.searchResults setObject:[self.myRecords objectForKey:name] forKey:name];
                   
            rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                  [searchResults count],
                                  ( [searchResults count] != 1 ? NSLocalizedString(@"Results", @"Results plural") : NSLocalizedString(@"Result", @"Result") )];
            
            [self.pullRefreshTableViewController.tableView reloadData];
            [self.searchBar becomeFirstResponder];
            break;
        case SubNavObjectListTypePicker:
            if( [searchText length] < 2 )
                return;
            
            [self updateTitleBar];
            
            NSString *sosl = [SFVAsync SOSLQueryWithSearchTerm:searchText
                                                    fieldScope:nil
                                                   objectScope:[NSDictionary dictionaryWithObject:[[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:sObjectType]
                                                                                                   componentsJoinedByString:@","]
                                                                                           forKey:sObjectType]];
            
            // Update to indicate we are searching
            [self.pullRefreshTableViewController.tableView reloadData];
            [self.pullRefreshTableViewController.tableView setContentOffset:CGPointZero animated:NO];
            isSearchPending = YES;
            
            [[SFRestAPI sharedInstance] performSOSLSearch:sosl
                                                failBlock:^(NSError *e) {
                                                    if( ![self isViewLoaded] ) 
                                                        return;
                                                    
                                                    isSearchPending = NO;
                                                                                                        
                                                    if( [self.pullRefreshTableViewController respondsToSelector:@selector(stopLoading)] )
                                                        [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                                                }
                                            completeBlock:^(NSArray *results) {
                                                if( ![self isViewLoaded] ) 
                                                    return;
                                                
                                                isSearchPending = NO;
                                                
                                                if( [self.pullRefreshTableViewController respondsToSelector:@selector(stopLoading)] )
                                                    [(PullRefreshTableViewController *)self.pullRefreshTableViewController stopLoading];
                                                
                                                [self.searchResults removeAllObjects];
                                                
                                                if( results && [results count] > 0 )
                                                    self.searchResults = [NSMutableDictionary dictionaryWithDictionary:
                                                                          [SFVUtil dictionaryFromAccountArray:
                                                                           [SFVAsync ZKSObjectArrayToDictionaryArray:results]]];
                                                
                                                rowCountLabel.text = [NSString stringWithFormat:@"%i %@",
                                                                      [results count],
                                                                      ( [results count] != 1 ? NSLocalizedString(@"Results", @"Results plural") : NSLocalizedString(@"Result", @"Result") )];
                                                
                                                [self.pullRefreshTableViewController.tableView reloadData];
                                                [self.pullRefreshTableViewController.tableView setContentOffset:CGPointZero animated:NO];
                                            }];
            break;
        default:
            break;
    }
}

- (void) toggleNoFavsView {
    CGRect r = CGRectMake( 0, 180, masterWidth, 500);
    
    UIView *v = [[UIView alloc] initWithFrame:r];
    v.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    v.backgroundColor = [UIColor clearColor];
    
    // label 1
    UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, v.frame.size.width, 30)];
    l1.text = NSLocalizedString(@"No Favorites", @"No favorites");
    l1.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:24];
    l1.textColor = [UIColor lightGrayColor];
    l1.textAlignment = UITextAlignmentCenter;
    l1.backgroundColor = [UIColor clearColor];
    l1.shadowColor = [UIColor blackColor];
    l1.shadowOffset = CGSizeMake( 0, 2 );
    
    [v addSubview:l1];
    [l1 release];
    
    // label 2
    UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectZero];
    l2.text = NSLocalizedString(@"Tap the ★ on any object to add a favorite.", @"Tap ★ on any object to add a favorite");
    l2.font = [UIFont boldSystemFontOfSize:16];
    l2.textColor = [UIColor darkGrayColor];
    l2.textAlignment = UITextAlignmentCenter;
    l2.backgroundColor = [UIColor clearColor];
    l2.numberOfLines = 0;
    
    CGSize s = [l2.text sizeWithFont:l2.font constrainedToSize:CGSizeMake( masterWidth - 20, 200 )];
    [l2 setFrame:CGRectMake( floorf( ( masterWidth - s.width ) / 2.0f ), 130, s.width, s.height )];
    
    [v addSubview:l2];
    [l2 release];
    
    [self.view addSubview:v];   
    [v release];
}

#pragma mark - follow actions

- (void) removeFollowedRecordWithId:(NSString *)recordId {
    if( self.subNavTableType != SubNavListOfRemoteRecords || self.subNavObjectListType != ObjectListRecordsIFollow || 
        [self.myRecords count] == 0 )
        return;
    
    if( ![self.sObjectType isEqualToString:[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:recordId]] )
        return;
    
    // TODO implement this for lists sorted by date
    if( orderingControl.selectedSegmentIndex != 0 ) {
        [self refresh];
        return;
    }
    
    NSDictionary *record = [NSDictionary dictionaryWithObject:recordId forKey:@"Id"];
    NSIndexPath *ip = [SFVUtil indexPathForAccountDictionary:record allAccountDictionary:self.myRecords];
    
    if( ip ) {
        // Update datasource
        NSString *key = [[SFVUtil sortArray:[self.myRecords allKeys]] objectAtIndex:ip.section];
        NSMutableArray *indexRecords = [NSMutableArray arrayWithArray:[self.myRecords objectForKey:key]];
        [indexRecords removeObjectAtIndex:ip.row];
        
        // Update tableview
        if( [indexRecords count] == 0 ) {
            [self.myRecords removeObjectForKey:key];
            [self.pullRefreshTableViewController.tableView deleteSections:[NSIndexSet indexSetWithIndex:ip.section]
                                                         withRowAnimation:UITableViewRowAnimationFade];
        } else {
            [self.myRecords setObject:indexRecords forKey:key];
            [self.pullRefreshTableViewController.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:ip]
                                                                 withRowAnimation:UITableViewRowAnimationFade];        
        }
    }
}

- (void) insertFollowedRecord:(NSDictionary *)record {
    if( self.subNavTableType != SubNavListOfRemoteRecords || self.subNavObjectListType != ObjectListRecordsIFollow )
        return;
    
    if( ![self.sObjectType isEqualToString:[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[record objectForKey:@"Id"]]] )
        return;
    
    // TODO implement this for lists sorted by date
    if( orderingControl.selectedSegmentIndex != 0 ) {
        [self refresh];
        return;
    }
    
    // Merge into our data source
    NSDictionary *newDictionary = [SFVUtil dictionaryByAddingAccounts:[NSArray arrayWithObject:record] toDictionary:self.myRecords];
    NSIndexPath *ip = [SFVUtil indexPathForAccountDictionary:record allAccountDictionary:newDictionary];
    
    if( ip ) {
        // Update data source
        self.myRecords = [NSMutableDictionary dictionaryWithDictionary:newDictionary];
        NSString *key = [[SFVUtil sortArray:[self.myRecords allKeys]] objectAtIndex:ip.section];
        
        // Update tableview
        if( [[self.myRecords objectForKey:key] count] == 1 )
            [self.pullRefreshTableViewController.tableView insertSections:[NSIndexSet indexSetWithIndex:ip.section]
                                                         withRowAnimation:UITableViewRowAnimationFade];
        else
            [self.pullRefreshTableViewController.tableView insertRowsAtIndexPaths:[NSArray arrayWithObject:ip]
                                                                 withRowAnimation:UITableViewRowAnimationFade];
        
        [self selectAccountWithId:[record objectForKey:@"Id"]];
    }
}

#pragma mark - grid view delegate

- (void)gridView:(AQGridView *)gv willDisplayCell:(AQGridViewCell *)cell forItemAtIndex:(NSUInteger)index {
    if( index == _emptyCellIndex )
        return;
    
    NSString *name = nil;
    NSArray *arr = nil;
    
    if( searching )
        name = [[self.searchResults allKeys] objectAtIndex:index];
    else {
        arr = [[NSUserDefaults standardUserDefaults] arrayForKey:( subNavTableType == SubNavAllObjects ? GlobalObjectOrderingKey : FavoriteObjectsKey )];
        name = ( arr && [arr count] > 0 ? [arr objectAtIndex:index] : 
                [[SFVUtil sortArray:[self.myRecords allKeys]] objectAtIndex:index] );
    }
    
    NSString *imgURL = [[SFVAppCache sharedSFVAppCache] logoURLForSObjectTab:name];
    
    if( imgURL )
        [[SFVUtil sharedSFVUtil] loadImageFromURL:imgURL
                                            cache:YES
                                     maxDimension:32.0f
                                    completeBlock:^(UIImage *img, BOOL wasLoadedFromCache) {
                                        if( ![self isViewLoaded] )
                                            return;
                                        
                                        if( !wasLoadedFromCache )
                                            [gv reloadItemsAtIndices:[NSIndexSet indexSetWithIndex:index]
                                                       withAnimation:AQGridViewItemAnimationFade];
                                        
                                    }];
}

- (AQGridViewCell *)gridView:(AQGridView *)gv cellForItemAtIndex:(NSUInteger)index {
    if( index == _emptyCellIndex ) {
        ObjectGridCell * hiddenCell = (ObjectGridCell *)[gridView dequeueReusableCellWithIdentifier:emptyCellIdentifier];
        if ( hiddenCell == nil )
            hiddenCell = [[[ObjectGridCell alloc] initWithCellIdentifier:emptyCellIdentifier] autorelease];
        
        hiddenCell.hidden = YES;
        return hiddenCell;
    }
    
    ObjectGridCell *cell = [ObjectGridCell cellForGridView:gv];
    
    NSString *label = nil, *name = nil;
    NSArray *arr = nil;
    
    if( searching ) {
        name = [[self.searchResults allKeys] objectAtIndex:index];
        label = [self.searchResults objectForKey:name];
    } else {
        arr = [[NSUserDefaults standardUserDefaults] arrayForKey:( subNavTableType == SubNavAllObjects ? GlobalObjectOrderingKey : FavoriteObjectsKey )];
        name = ( arr && [arr count] > 0 ? [arr objectAtIndex:index] : 
               [[SFVUtil sortArray:[self.myRecords allKeys]] objectAtIndex:index] );
        label = [self.myRecords objectForKey:name];
    }
        
    cell.gridLabel.text = label;
    
    NSString *imgURL = [[SFVAppCache sharedSFVAppCache] logoURLForSObjectTab:name];
    
    if( imgURL )
        [cell setGridImage:[[SFVUtil sharedSFVUtil] userPhotoFromCache:imgURL]];
    else if( [[SFVAppCache sharedSFVAppCache] imageForSObject:name] )
        [cell setGridImage:[[SFVAppCache sharedSFVAppCache] imageForSObject:name]];
    else
        [cell setGridImage:nil];
    
    [cell layoutCell];
        
    return cell;
}

- (CGSize)portraitGridCellSizeForGridView:(AQGridView *)gridView {
    return CGSizeMake( floorf( masterWidth / 2.0f ), floorf( masterWidth / 2.0f ) );
}

- (NSUInteger)numberOfItemsInGridView:(AQGridView *)gridView {
    return ( searching ? [self.searchResults count] : [self.myRecords count] );
}

- (void)gridView:(AQGridView *)gv didSelectItemAtIndex:(NSUInteger)index {
    NSString *name = nil;
    NSArray *arr = nil;
    
    if( searching ) {
        if( index >= [self.searchResults count] )
            return;
        
        name = [[self.searchResults allKeys] objectAtIndex:index];
    } else {        
        arr = [[NSUserDefaults standardUserDefaults] arrayForKey:( subNavTableType == SubNavAllObjects ? GlobalObjectOrderingKey : FavoriteObjectsKey )];
        name = ( arr && [arr count] > 0 ? [arr objectAtIndex:index] : 
                [[SFVUtil sortArray:[self.myRecords allKeys]] objectAtIndex:index] );
    }
    
    [DSBezelActivityView newActivityViewForView:self.view];
    
    [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:name
                                                    failBlock:nil
                                                completeBlock:^(NSDictionary *dict) {     
                                                    if( ![self isViewLoaded] ) 
                                                        return;
                                                    
                                                    [DSBezelActivityView removeViewAnimated:YES];
                                                    [self.rootViewController pushSubNavControllerForSObject:name];
                                                }];
}

#pragma mark - draggable gridview for favorites
// Adapted from AQGridView example

- (BOOL) gestureRecognizerShouldBegin: (UIGestureRecognizer *) gestureRecognizer {
    CGPoint location = [gestureRecognizer locationInView:gridView];
        
    return ( subNavTableType == SubNavFavoriteObjects && [gridView indexForItemAtPoint:location] < [self.myRecords count] );
}

- (void) moveActionGestureRecognizerStateChanged: (UIGestureRecognizer *) recognizer {
    switch ( recognizer.state ) {
        default:
        case UIGestureRecognizerStateFailed:
            NSLog(@"failed");
            // do nothing
            break;
            
        case UIGestureRecognizerStatePossible:
        case UIGestureRecognizerStateCancelled:
            NSLog(@"cancel");
            [gridView beginUpdates];
            
            if ( _emptyCellIndex != _dragOriginIndex )
                [gridView moveItemAtIndex:_emptyCellIndex toIndex:_dragOriginIndex withAnimation:AQGridViewItemAnimationFade];
            
            _emptyCellIndex = _dragOriginIndex;
            
            // move the cell back to its origin
            [UIView beginAnimations: @"SnapBack" context: NULL];
            [UIView setAnimationCurve: UIViewAnimationCurveEaseOut];
            [UIView setAnimationDuration: 0.5];
            [UIView setAnimationDelegate: self];
            [UIView setAnimationDidStopSelector: @selector(finishedSnap:finished:context:)];
            
            CGRect f = _draggingCell.frame;
            f.origin = _dragOriginCellOrigin;
            _draggingCell.frame = f;
            
            [UIView commitAnimations];
            
            [gridView endUpdates];
            [gridView reloadItemsAtIndices:[NSIndexSet indexSetWithIndex:_dragOriginIndex] withAnimation:AQGridViewItemAnimationNone];
            break;
        case UIGestureRecognizerStateEnded:
        {
            CGPoint p = [recognizer locationInView:gridView];
            NSUInteger index = [gridView indexForItemAtPoint: p];
			if ( index == NSNotFound )
			{
				// index is the last available location
				index = [self.myRecords count] - 1;
			}
            
            // update the data store
            NSMutableArray *favs = [NSMutableArray arrayWithArray:[[self class] loadFavoriteObjects]];
            NSString *obj = [[favs objectAtIndex:_dragOriginIndex] retain];
            NSLog(@"moving favorite '%@' to position %i", obj, index);
            [favs removeObjectAtIndex:_dragOriginIndex];
            [favs insertObject:obj atIndex:index];
            [obj release];
            [[NSUserDefaults standardUserDefaults] setObject:favs forKey:FavoriteObjectsKey];
            [[NSUserDefaults standardUserDefaults] synchronize];
            
            if ( index != _emptyCellIndex )
            {
                [gridView beginUpdates];
                [gridView moveItemAtIndex: _emptyCellIndex toIndex: index withAnimation: AQGridViewItemAnimationFade];
                _emptyCellIndex = index;
                [gridView endUpdates];
            }
            
            // move the real cell into place
            [UIView beginAnimations: @"SnapToPlace" context: NULL];
            [UIView setAnimationCurve: UIViewAnimationCurveEaseOut];
            [UIView setAnimationDuration: 0.5];
            [UIView setAnimationDelegate: self];
            [UIView setAnimationDidStopSelector: @selector(finishedSnap:finished:context:)];
            
            CGRect r = [gridView rectForItemAtIndex: _emptyCellIndex];
            CGRect f = _draggingCell.frame;
            f.origin.x = r.origin.x + floorf((r.size.width - f.size.width) * 0.5) + 1;
            f.origin.y = r.origin.y + fabs(floorf((r.size.height - f.size.height) * 0.5)) - 22 - gridView.contentOffset.y;
            _draggingCell.frame = f;
            
            _draggingCell.transform = CGAffineTransformIdentity;
            _draggingCell.alpha = 1.0;
            
            [UIView commitAnimations];
            break;
        }
            
        case UIGestureRecognizerStateBegan:
        {
            NSUInteger index = [gridView indexForItemAtPoint:[recognizer locationInView:gridView]];
            _emptyCellIndex = index;    // we'll put an empty cell here now
            
            // find the cell at the current point and copy it into our main view, applying some transforms
            ObjectGridCell * sourceCell = (ObjectGridCell *)[gridView cellForItemAtIndex: index];
            CGRect frame = [self.view convertRect: sourceCell.frame fromView: gridView];
            _draggingCell = [[ObjectGridCell alloc] initWithCellIdentifier:draggingCellIdentifier];
            _draggingCell.gridLabel.text = sourceCell.gridLabel.text;
            NSString *name = [[[NSUserDefaults standardUserDefaults] arrayForKey:FavoriteObjectsKey] objectAtIndex:index];
            [_draggingCell setGridImage:[[SFVAppCache sharedSFVAppCache] imageForSObjectFromCache:name]];
            [_draggingCell layoutCell];
            [_draggingCell setFrame:frame];
            [self.view addSubview: _draggingCell];
                        
            // grab some info about the origin of this cell
            _dragOriginCellOrigin = frame.origin;
            _dragOriginIndex = index;
            
            [UIView beginAnimations: @"" context: NULL];
            [UIView setAnimationDuration: 0.2];
            [UIView setAnimationCurve: UIViewAnimationCurveEaseOut];
            
            // transformation-- larger, slightly transparent
            _draggingCell.transform = CGAffineTransformMakeScale( 1.2, 1.2 );
            _draggingCell.alpha = 0.7;
            
            // also make it center on the touch point
            _draggingCell.center = [recognizer locationInView: self.view];
            
            [UIView commitAnimations];
            
            // reload the grid underneath to get the empty cell in place
            [gridView reloadItemsAtIndices:[NSIndexSet indexSetWithIndex:index]
                             withAnimation:AQGridViewItemAnimationNone];
            
            break;
        }
            
        case UIGestureRecognizerStateChanged:
        {
            // update draging cell location
            _draggingCell.center = [recognizer locationInView: self.view];
            
            // don't do anything with content if grid view is in the middle of an animation block
            if ( gridView.isAnimatingUpdates )
                break;
            
            // update empty cell to follow, if necessary
            NSUInteger index = [gridView indexForItemAtPoint:[recognizer locationInView:gridView]];
			
			// don't do anything if it's over an unused grid cell
			if ( index == NSNotFound )
			{
				// snap back to the last possible index
				index = [self.myRecords count] - 1;
			}
			
            if ( index != _emptyCellIndex )
            {
                NSLog( @"Moving empty cell from %u to %u", _emptyCellIndex, index );
                
                // batch the movements
                [gridView beginUpdates];
                
                // move everything else out of the way
                if ( index < _emptyCellIndex )
                {
                    for ( NSUInteger i = index; i < _emptyCellIndex; i++ )
                    {
                        [gridView moveItemAtIndex: i toIndex: i+1 withAnimation: AQGridViewItemAnimationFade];
                    }
                }
                else
                {
                    for ( NSUInteger i = index; i > _emptyCellIndex; i-- )
                    {
                        [gridView moveItemAtIndex: i toIndex: i-1 withAnimation: AQGridViewItemAnimationFade];
                    }
                }
                
                [gridView moveItemAtIndex: _emptyCellIndex toIndex: index withAnimation: AQGridViewItemAnimationFade];
                _emptyCellIndex = index;
                
                [gridView endUpdates];
            }
            
            break;
        }
    }
}

- (void) finishedSnap: (NSString *) animationID finished: (NSNumber *) finished context: (void *) context {
    NSIndexSet * indices = [[NSIndexSet alloc] initWithIndex: _emptyCellIndex];
    _emptyCellIndex = NSNotFound;
    
    // load the moved cell into the grid view
    [gridView reloadItemsAtIndices:indices withAnimation:AQGridViewItemAnimationNone];
    
    // dismiss our copy of the cell
    [_draggingCell removeFromSuperview];
    [_draggingCell release];
    _draggingCell = nil;
    
    [indices release];
}

#pragma mark - table view operations

- (void) setLoadingViewVisible:(BOOL)visible {
    if( !visible && loadingView ) {
        [loadingView removeFromSuperview];
        SFRelease(loadingView);
    } else if( visible && !loadingView ) {
        loadingView = [[UIView alloc] initWithFrame:CGRectMake( 0, self.view.frame.size.height - kFooterHeight - 25, masterWidth, 25 )];
        loadingView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.3f];
        loadingView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        loadingView.userInteractionEnabled = NO;
        
        UILabel *loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake( 5, 2, 100, 20 )];
        loadingLabel.backgroundColor = [UIColor clearColor];
        loadingLabel.text = NSLocalizedString(@"Loading More...", @"Loading More...");
        loadingLabel.font = [UIFont boldSystemFontOfSize:16];
        loadingLabel.textColor = [UIColor whiteColor];
        [loadingView addSubview:loadingLabel];
        [loadingLabel release];
        
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [spinner startAnimating];
        [spinner setFrame:CGRectMake( masterWidth - 30, 2, 20, 20 )];
        [loadingView addSubview:spinner];
        [spinner release];
        
        [self.view addSubview:loadingView];
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    /*if( subNavTableType == SubNavAppPicker ) {
        CGFloat f = 5.0f;
        
        NSString *appLabel = [[[SFVAppCache sharedSFVAppCache] listAllAppLabels] objectAtIndex:indexPath.row];
        
        UIImage *img = [[SFVUtil sharedSFVUtil] userPhotoFromCache:[[SFVAppCache sharedSFVAppCache] logoURLForAppLogoImage:appLabel]];
        
        if( img )
            f += img.size.height;
        
        f += 5 + [appLabel sizeWithFont:[UIFont boldSystemFontOfSize:17] constrainedToSize:CGSizeMake( masterWidth - 45, 999)].height;
        
        return MAX( f, 44.0f );
    }*/
    
    return tableView.rowHeight;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if( subNavTableType == SubNavListOfRemoteRecords ||
        subNavTableType == SubNavObjectListTypePicker ||
        ( subNavTableType == SubNavAppTabPicker && [self.title length] >= kMaxTitleLength ) )
        return [UIImage imageNamed:@"sectionheader.png"].size.height;
    
    return 0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if( subNavTableType == SubNavListOfRemoteRecords ||
        subNavTableType == SubNavObjectListTypePicker || subNavTableType == SubNavAppTabPicker ) {
        UIImageView *sectionView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sectionheader.png"]];
        
        UILabel *customLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, -1, sectionView.frame.size.width, sectionView.frame.size.height )];
        customLabel.textColor = AppSecondaryColor;
        
        if( searching && isSearchPending )
            customLabel.text = NSLocalizedString(@"Searching...", @"Searching...");
        else if( searching && !isSearchPending && [searchResults count] == 0 )
            customLabel.text = NSLocalizedString(@"No Results", @"No Results");
        else if( subNavTableType == SubNavAppTabPicker )
            customLabel.text = [[[SFVAppCache sharedSFVAppCache] listAllAppLabels] objectAtIndex:self.appIndex];
        else if( ( subNavTableType == SubNavObjectListTypePicker && searching ) ||
            ( subNavTableType == SubNavListOfRemoteRecords && orderingControl.selectedSegmentIndex <= 0 ) )
            customLabel.text = [[SFVUtil sortArray:( searching ? [searchResults allKeys] : [myRecords allKeys] )] objectAtIndex:section];
        else if( subNavTableType != SubNavObjectListTypePicker )
            customLabel.text = [DateGroupsArray objectAtIndex:section];
        else
            customLabel.text = [[SFVAppCache sharedSFVAppCache] labelForSObject:sObjectType usePlural:YES];
        
        customLabel.font = [UIFont boldSystemFontOfSize:16];
        customLabel.backgroundColor = [UIColor clearColor];
        [sectionView addSubview:customLabel];
        [customLabel release];
        
        return [sectionView autorelease];
    }
    
    return nil;
}

- (void) selectAccountWithId:(NSString *)accountId {
    if( subNavTableType != SubNavListOfRemoteRecords &&
       !( subNavTableType == SubNavObjectListTypePicker && searching ) ) {
        [self.pullRefreshTableViewController.tableView deselectRowAtIndexPath:[self.pullRefreshTableViewController.tableView indexPathForSelectedRow]
                                                                     animated:YES];
        return;
    }
    
    if( accountId ) {        
        NSDictionary *d = [NSDictionary dictionaryWithObjectsAndKeys:accountId, @"Id", nil];
        NSIndexPath *path = [SFVUtil indexPathForAccountDictionary:d
                                                  allAccountDictionary:( searching ? self.searchResults : self.myRecords )];
                
        if( path )
            [self.pullRefreshTableViewController.tableView selectRowAtIndexPath:path animated:NO scrollPosition:UITableViewScrollPositionNone];
        else
            [self.pullRefreshTableViewController.tableView deselectRowAtIndexPath:[self.pullRefreshTableViewController.tableView indexPathForSelectedRow]
                                                                         animated:YES];
    } else 
        [self.pullRefreshTableViewController.tableView deselectRowAtIndexPath:[self.pullRefreshTableViewController.tableView indexPathForSelectedRow]
                                                                     animated:YES];
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView {  
    NSMutableArray *ret = [NSMutableArray array];
        
    if( subNavTableType == SubNavAllObjects || subNavTableType == SubNavAppPicker || subNavTableType == SubNavAppTabPicker )
        return nil;
    
    if( ( subNavTableType == SubNavObjectListTypePicker && searching ) ||
       ( subNavTableType == SubNavListOfRemoteRecords && orderingControl.selectedSegmentIndex <= 0 ) )
        for( int x = 0; x < [indexAlphabet length]; x++ )
            [ret addObject:[indexAlphabet substringWithRange:NSMakeRange(x, 1)]];
    else if( subNavTableType != SubNavObjectListTypePicker )
        return DateGroupsArray;
            
    return ( [ret count] > 0 ? ret : nil );
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index {           
    if( orderingControl.selectedSegmentIndex <= 0 ) {
        NSArray *sortedKeys = [SFVUtil sortArray:( searching ? [searchResults allKeys] : [myRecords allKeys] )];
        int ret = 0;
        
        for( int x = 0; x < [sortedKeys count]; x++ )        
            if( [[sortedKeys objectAtIndex:x] compare:title options:NSCaseInsensitiveSearch] != NSOrderedDescending )
                ret = x;
                
        return ret;
    }
    
    for( int x = 0; x < [DateGroupsArray count]; x++ )
        if( [title isEqualToString:[DateGroupsArray objectAtIndex:x]] )
            return x;
    
    return 0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if( searching && [searchResults count] == 0 )
        return 1;
    
    if( subNavTableType == SubNavListOfRemoteRecords ||
        ( subNavTableType == SubNavObjectListTypePicker && searching ) )
        return ( searching ? [[searchResults allKeys] count] : [[myRecords allKeys] count] );
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    NSArray *sortedKeys = nil;
    
    switch( subNavTableType ) {
        case SubNavAppTabPicker:
            return [[[SFVAppCache sharedSFVAppCache] listTabsForAppAtIndex:self.appIndex] count];
        case SubNavAppPicker:
            return [[[SFVAppCache sharedSFVAppCache] listAllAppLabels] count];
        case SubNavAllObjects:
            return ( searching ? [self.searchResults count] : [self.myRecords count] );
        case SubNavObjectListTypePicker:
            if( searching ) {
                if( [searchResults count] == 0 )
                    return 0;
                
                sortedKeys = [SFVUtil sortArray:[searchResults allKeys]];
                return [[searchResults objectForKey:[sortedKeys objectAtIndex:section]] count];
            }                
            
            return [[self listsForObject] count];            
        case SubNavListOfRemoteRecords:
            if( searching ) {
                sortedKeys = [SFVUtil sortArray:[searchResults allKeys]];
                return [[searchResults objectForKey:[sortedKeys objectAtIndex:section]] count];
            }
            
            sortedKeys = [SFVUtil sortArray:[myRecords allKeys]];
            return [[myRecords objectForKey:[sortedKeys objectAtIndex:section]] count];
        default:
            return 0;
    }
    
    return 0;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *imgUrl = nil;
    
    switch( subNavTableType ) {
        case SubNavAppTabPicker: {
            ZKDescribeTab *tab = [[[SFVAppCache sharedSFVAppCache] listTabsForAppAtIndex:self.appIndex] objectAtIndex:indexPath.row];
            
            if( [tab iconUrl] )                
                imgUrl = [tab iconUrl];
            
            break;
        }    
        case SubNavAllObjects: {
            NSArray *keys = nil;
            
            if( searching ) {
                keys = [[SFVUtil sharedSFVUtil] sortGlobalObjectArray:[self.searchResults allKeys]];
            } else {                
                keys = [[NSUserDefaults standardUserDefaults] arrayForKey:GlobalObjectOrderingKey];
                
                if( !keys || [keys count] == 0 )
                    keys = [SFVUtil sortArray:[self.myRecords allKeys]];
            }
            
            NSString *str = [keys objectAtIndex:indexPath.row];
            imgUrl = [[SFVAppCache sharedSFVAppCache] logoURLForSObjectTab:str];
            
            break;
        }
            
        default: break;
    }
    
    if( imgUrl )
        [[SFVUtil sharedSFVUtil] loadImageFromURL:imgUrl
                                            cache:YES
                                     maxDimension:32
                                    completeBlock:^(UIImage *img, BOOL wasLoadedFromCache) {   
                                        if( ![self isViewLoaded] || ![self.rootViewController isLoggedIn] )
                                            return;
                                        
                                        if( [tableView numberOfSections] < indexPath.section || [tableView numberOfRowsInSection:indexPath.section] < indexPath.row )
                                            return;
                                        
                                        if( !wasLoadedFromCache )
                                            [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                                             withRowAnimation:UITableViewRowAnimationFade];
                                    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
    PRPSmartTableViewCell *cell = nil;
    NSDictionary *record = nil;
    NSString *str = nil;
    NSArray *arr = nil;
    
    cell = [PRPSmartTableViewCell cellForTableView:tableView];

    cell.textLabel.adjustsFontSizeToFitWidth = NO;
    cell.textLabel.textColor = UIColorFromRGB(0xbababa);
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    cell.accessoryView = nil;
    cell.imageView.image = nil;
    cell.detailTextLabel.text = nil;
    
    cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
    
    switch( subNavTableType ) {
        case SubNavAppTabPicker: {
            ZKDescribeTab *tab = [[[SFVAppCache sharedSFVAppCache] listTabsForAppAtIndex:self.appIndex] objectAtIndex:indexPath.row];
            
            cell.textLabel.text = [tab label];
            cell.textLabel.numberOfLines = 2;
                        
            if( [[self class] canDrillIntoTab:tab] ) {
                DTCustomColoredAccessory *accessory = [DTCustomColoredAccessory accessoryWithColor:cell.textLabel.textColor];
                accessory.highlightedColor = [UIColor whiteColor];
                cell.accessoryView = accessory;
            }
            
            if( [tab iconUrl] )                
                cell.imageView.image = [[SFVUtil sharedSFVUtil] userPhotoFromCache:[tab iconUrl]];
            
            break;
        }
        case SubNavAppPicker: {
            arr = [[SFVAppCache sharedSFVAppCache] listAllAppLabels];
            
            DTCustomColoredAccessory *accessory = [DTCustomColoredAccessory accessoryWithColor:cell.textLabel.textColor];
            accessory.highlightedColor = [UIColor whiteColor];
            cell.accessoryView = accessory;
            
            cell.textLabel.text = [arr objectAtIndex:indexPath.row];
            cell.imageView.image = nil;
            cell.textLabel.numberOfLines = 2;
            
            break;
        }
        case SubNavAllObjects: {  
            NSArray *keys = nil;
            
            if( searching ) {
                keys = [[SFVUtil sharedSFVUtil] sortGlobalObjectArray:[self.searchResults allKeys]];
            } else {                
                keys = [[NSUserDefaults standardUserDefaults] arrayForKey:GlobalObjectOrderingKey];
                
                if( !keys || [keys count] == 0 )
                    keys = [SFVUtil sortArray:[self.myRecords allKeys]];
            }
            
            str = [keys objectAtIndex:indexPath.row];
            
            cell.textLabel.text = [[SFVAppCache sharedSFVAppCache] labelForSObject:str usePlural:YES];   
            cell.imageView.image = [[SFVAppCache sharedSFVAppCache] imageForSObjectFromCache:str];            
            cell.textLabel.numberOfLines = 2;
            
            DTCustomColoredAccessory *accessory = [DTCustomColoredAccessory accessoryWithColor:cell.textLabel.textColor];
            accessory.highlightedColor = [UIColor whiteColor];
            cell.accessoryView = accessory;
            
            [cell setNeedsLayout];
            
            break;
        }
        case SubNavObjectListTypePicker:
        case SubNavListOfRemoteRecords:
            if( searching )
                record = [SFVUtil accountFromIndexPath:indexPath accountDictionary:searchResults];
            else if( subNavTableType == SubNavObjectListTypePicker ) {
                DTCustomColoredAccessory *accessory = [DTCustomColoredAccessory accessoryWithColor:cell.textLabel.textColor];
                accessory.highlightedColor = [UIColor whiteColor];
                cell.accessoryView = accessory;
                cell.textLabel.numberOfLines = 2;
                
                if( indexPath.row < [[self listsForObject] count] )
                    switch( [((NSNumber *)[[self listsForObject] objectAtIndex:indexPath.row]) intValue] ) {
                        case ObjectListRecentRecords: {
                            NSArray *recents = [[SFVUtil sharedSFVUtil] recentRecordsForSObject:sObjectType];
                            int count = ( recents && [recents count] > 0 ? [recents count] : 0 );
                            
                            cell.textLabel.text = [NSString stringWithFormat:@"%@ (%i)",
                                                   NSLocalizedString(@"Recent Records", @"Recent Records"),
                                                   count];                        
                            break;
                        }
                        case ObjectListRecordsIOwn:
                            cell.textLabel.text = [NSString stringWithFormat:@"%@ %@",
                                                   NSLocalizedString(@"Records", @"Records"),
                                                   NSLocalizedString(@"I Own", @"I Own")];
                            break;
                        case ObjectListRecordsICreated:
                            cell.textLabel.text = [NSString stringWithFormat:@"%@ %@",
                                                   NSLocalizedString(@"Records", @"Records"),
                                                   NSLocalizedString(@"I Created", @"I Created")];
                            break;
                        case ObjectListMyUnreadLeads:
                            cell.textLabel.text = NSLocalizedString(@"My Unread Leads", @"My Unread Leads");
                            break;
                        case ObjectListAllRecentlyModified:
                            cell.textLabel.text = NSLocalizedString(@"All Recently Modified", @"All recently modified");
                            break;
                        case ObjectListRecordsIRecentlyModified:
                            cell.textLabel.text = [NSString stringWithFormat:@"%@ %@",
                                                   NSLocalizedString(@"Records", @"Records"),
                                                   NSLocalizedString(@"I Modified", @"I modified")];
                            break;
                        case ObjectListRecordsIFollow:
                            cell.textLabel.text = [NSString stringWithFormat:@"%@ %@",
                                                   NSLocalizedString(@"Records", @"Records"),
                                                   NSLocalizedString(@"I Follow", @"I follow")];
                            break;
                        case ObjectListAllRecentlyCreated:
                            cell.textLabel.text = NSLocalizedString(@"All Recently Created", @"All recently created");
                            break;
                        case ObjectListMyOpenTasks:
                            cell.textLabel.text = NSLocalizedString(@"My Open Tasks", @"My Open Tasks");
                            break;
                        case ObjectListMyOpenCases:
                            cell.textLabel.text = NSLocalizedString(@"My Open Cases", @"My Open Cases");
                            break;
                        case ObjectListMyUpcomingEvents:
                            cell.textLabel.text = NSLocalizedString(@"My Upcoming Events", @"My Upcoming Events");
                            break;
                        case ObjectListMyPastEvents:
                            cell.textLabel.text = NSLocalizedString(@"My Past Events", @"My Past Events");
                            break;
                        case ObjectListMyUpcomingOpportunities:
                            cell.textLabel.text = NSLocalizedString(@"My Upcoming Open Opportunities", @"My Upcoming Open Opportunities");
                            break;
                        case ObjectListMyClosedOpportunities:
                            cell.textLabel.text = NSLocalizedString(@"My Closed Opportunities", @"My Closed Opportunities");
                            break;
                        case ObjectListViewOnTheWeb:
                            cell.textLabel.text = NSLocalizedString(@"View on the Web", @"View on the Web");
                            cell.accessoryView = nil;
                            break;
                        default:
                            break;
                    }
                
                return cell;
            } else
                record = [SFVUtil accountFromIndexPath:indexPath accountDictionary:myRecords];
            
            cell.textLabel.text = [[SFVAppCache sharedSFVAppCache] nameForSObject:record];  
            cell.imageView.image = nil;
            cell.accessoryType = UITableViewCellAccessoryNone;
            
            if( subNavTableType == SubNavListOfRemoteRecords ) {
                if( orderingControl.selectedSegmentIndex <= 0 )
                    cell.detailTextLabel.text = [[SFVAppCache sharedSFVAppCache] descriptionValueForRecord:record];
                else if( orderingControl.selectedSegmentIndex == 1 &&
                            [[orderingControl titleForSegmentAtIndex:1] isEqualToString:NSLocalizedString(@"Created", @"Created")] )
                    cell.detailTextLabel.text = [SFVUtil relativeTime:[SFVUtil dateFromSOQLDatetime:[record objectForKey:@"CreatedDate"]]];
                else
                    cell.detailTextLabel.text = [SFVUtil relativeTime:[SFVUtil dateFromSOQLDatetime:[record objectForKey:@"LastModifiedDate"]]];                        
            } else
                cell.detailTextLabel.text = [[SFVAppCache sharedSFVAppCache] descriptionValueForRecord:record];
            
            cell.textLabel.numberOfLines = 1 + ( [SFVUtil isEmpty:cell.detailTextLabel.text] ? 1 : 0 );
            
            break;
        default:
            break;
    }
    
    return cell;
}

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {   
    NSArray *arr = nil;
    NSDictionary *record = nil;
    
    [searchBar resignFirstResponder];
    
    switch( subNavTableType ) {
        case SubNavAppTabPicker: {
            ZKDescribeTab *tab = [[[SFVAppCache sharedSFVAppCache] listTabsForAppAtIndex:self.appIndex] objectAtIndex:indexPath.row];
            
            if( [[self class] canDrillIntoTab:tab] )
                [self.rootViewController pushSubNavControllerForSObject:[[self class] sObjectNameForTab:tab]];
            else if( [tab url] ) {                
                [self.rootViewController.popoverController dismissPopoverAnimated:YES];
                [self.detailViewController addFlyingWindow:FlyingWindowWebView 
                                                   withArg:[[SFVAppCache sharedSFVAppCache] webURLForURL:[tab url]]];
            }
            
            break;
        }
        case SubNavAppPicker:
            [self.rootViewController pushSubNavControllerForAppAtIndex:indexPath.row];
            
            break;
        case SubNavAllObjects: {
            NSString *name = nil;
            
            if( searching ) {
                if( indexPath.row >= [self.searchResults count] )
                    return;
                
                name = [[[SFVUtil sharedSFVUtil] sortGlobalObjectArray:[self.searchResults allKeys]] objectAtIndex:indexPath.row];
            } else {        
                arr = [[NSUserDefaults standardUserDefaults] arrayForKey:GlobalObjectOrderingKey];
                name = ( arr && [arr count] > 0 ? [arr objectAtIndex:indexPath.row] : 
                        [[SFVUtil sortArray:[self.myRecords allKeys]] objectAtIndex:indexPath.row] );
            }
            
            [self.rootViewController pushSubNavControllerForSObject:name];
            
            break;
        }
        case SubNavListOfRemoteRecords:
        case SubNavObjectListTypePicker:              
            if( searching )
                record = [SFVUtil accountFromIndexPath:indexPath accountDictionary:self.searchResults];
            else if( subNavTableType == SubNavObjectListTypePicker ) {
                self.title = NSLocalizedString(@"Lists", nil);
                
                int whichList = [[[self listsForObject] objectAtIndex:indexPath.row] intValue];
                
                if( whichList == ObjectListViewOnTheWeb ) {
                    NSDictionary *ob = [[SFVAppCache sharedSFVAppCache] describeGlobalsObject:sObjectType];
                    
                    if( ![SFVUtil isEmpty:[ob objectForKey:@"keyPrefix"]] )
                        [self.detailViewController addFlyingWindow:FlyingWindowWebView
                                                           withArg:[[SFVAppCache sharedSFVAppCache] webURLForURL:[@"/" stringByAppendingString:[ob objectForKey:@"keyPrefix"]]]];
                } else
                    [self.rootViewController pushSubNavControllerWithObjectListType:whichList
                                                                            sObject:sObjectType];
                
                return;
            } else
                record = [SFVUtil accountFromIndexPath:indexPath accountDictionary:self.myRecords];
            
            if( !record ) {
                [self.pullRefreshTableViewController.tableView deselectRowAtIndexPath:[self.pullRefreshTableViewController.tableView indexPathForSelectedRow] animated:YES];
                return;
            }
            
            NSMutableDictionary *recordWithType = [NSMutableDictionary dictionaryWithDictionary:record];
            
            if( subNavTableType == SubNavListOfRemoteRecords )
                [recordWithType setObject:sObjectType forKey:kObjectTypeKey];
            
            if( subNavTableType != SubNavObjectListTypePicker )
                [self.rootViewController.popoverController dismissPopoverAnimated:YES];
            
            [self.detailViewController didSelectAccount:recordWithType];            
            break;
        default:
            break;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void) handleInterfaceRotation:(BOOL)isPortrait {
    if( sheet ) {
        [sheet dismissWithClickedButtonIndex:-1 animated:NO];
        SFRelease(sheet);
    }
    
    if( isPortrait )        
        [self.searchBar resignFirstResponder];
}

+ (BOOL)canDrillIntoTab:(ZKDescribeTab *)tab {
    if( [tab sobjectName] && [[SFVAppCache sharedSFVAppCache] doesGlobalObject:[tab sobjectName] 
                                                                  haveProperty:GlobalObjectIsLayoutable] )
        return YES;
    
    // special reports/dashboards check
    // we cannot check via sobjectname, so is a janky hack by using the URL
    if( [[tab url] hasSuffix:@"00O/o"] || [[tab url] hasSuffix:@"01Z/o"] )
        return YES;
    
    return NO;
}

+ (NSString *)sObjectNameForTab:(ZKDescribeTab *)tab {
    if( [tab sobjectName] )
        return [tab sobjectName];
    
    if( [[tab url] hasSuffix:@"00O/o"] )
        return @"Report";
    
    if( [[tab url] hasSuffix:@"01Z/o"] )
        return @"Dashboard";
    
    return nil;
}

#pragma mark - app icon, header, navbar actions

- (void) resignResponder {
    [searchBar resignFirstResponder];
}

- (IBAction) refreshGlobalObjects:(id)sender {
    [self cancelSearch];
    [[SFVUtil sharedSFVUtil] emptyCaches:YES];  
    [[SFVAppCache sharedSFVAppCache] emptyCaches];
    refreshButton.enabled = NO;
    [DSBezelActivityView newActivityViewForView:self.view];
    [self.myRecords removeAllObjects];
    [self.pullRefreshTableViewController.tableView reloadData];
    
    if( [self.rootViewController.popoverController isPopoverVisible] )
        [self.rootViewController.popoverController dismissPopoverAnimated:YES];
    
    [[SFRestAPI sharedInstance] SFVperformDescribeGlobalWithFailBlock:nil
                                                     completeBlock:^(NSDictionary *describe) {       
                                                         if( ![self isViewLoaded] ) 
                                                             return;
                                                         
                                                         [SFVAsync describeTabsWithFailBlock:nil
                                                                               completeBlock:^(NSArray *tabSets) {
                                                                                   if( ![self isViewLoaded] ) 
                                                                                       return;
                                                                                   
                                                                                   [[SFVAppCache sharedSFVAppCache] cacheTabSetResults:tabSets];
                                                                                   [DSBezelActivityView removeViewAnimated:YES];
                                                                                   refreshButton.enabled = YES;
                                                                                   [self refresh];
                                                                                   [self.detailViewController eventLogInOrOut];
                                                                               }];
                                                     }];
}

- (IBAction) showSettings:(id)sender {
    [self cancelSearch];
    
    [self.rootViewController showSettings:sender];
}

- (IBAction) tappedLogo:(id)sender {
    if( self.rootViewController.popoverController )
        [self.rootViewController.popoverController dismissPopoverAnimated:YES];
    
    [self cancelSearch];
    
    [self.rootViewController popToHome];
    
    [self.rootViewController subNavSelectAccountWithId:nil];
    [self.detailViewController eventLogInOrOut];
}

- (IBAction) showFavorites:(id)sender {
    [self.rootViewController pushSubNavControllerWithType:SubNavFavoriteObjects animated:YES];
}

- (void) updateTitleBar {
    NSString *title = nil;
    UIView *titleView = nil;
    
    if( searching )
        title = NSLocalizedString(@"Searching...", @"Searching...");
    else switch( subNavTableType ) {
        case SubNavAppTabPicker: {
            ZKDescribeTabSetResult *result = [[[SFVAppCache sharedSFVAppCache] listAllApps] objectAtIndex:self.appIndex];
            
            title = [result label];
            break;
        }
        case SubNavAppPicker:
            title = NSLocalizedString(@"Apps", @"Apps");
            break;
        case SubNavAllObjects:
            title = NSLocalizedString(@"All Objects", @"All sObjects");
            break;
        case SubNavObjectListTypePicker:
        case SubNavListOfRemoteRecords:
            titleView = [[[UIImageView alloc] initWithImage:[[SFVAppCache sharedSFVAppCache] imageForSObjectFromCache:sObjectType]] autorelease];
            break;
        case SubNavFavoriteObjects:
            title = NSLocalizedString(@"Favorites", @"Favorites");
            break;
        default:
            title = @"Unknown List";
            break;
    }
    
    if( title )
        [self setTitle:title];
    else if( titleView )
        [self.navigationItem setTitleView:titleView];
}

#pragma mark - favorites

+ (NSArray *) loadFavoriteObjects {
    return [[SFVUtil sharedSFVUtil] filterGlobalObjectArray:[[NSUserDefaults standardUserDefaults] arrayForKey:FavoriteObjectsKey]];
}

- (BOOL) currentObjectIsFavorite {
    NSArray *arr = [[self class] loadFavoriteObjects];
    
    return arr && [arr count] > 0 && [arr containsObject:sObjectType];
}

- (UIBarButtonItem *) favoriteBarButtonItem {
    return [[[UIBarButtonItem alloc] initWithImage:( [self currentObjectIsFavorite] ?
                                                    [UIImage imageNamed:@"favorite_on.png"] :
                                                    [UIImage imageNamed:@"favorite_off.png"] )
                                             style:UIBarButtonItemStyleBordered
                                            target:self
                                            action:@selector(toggleObjectIsFavorite:)] autorelease];
}

- (void) toggleObjectIsFavorite:(id)sender {
    NSMutableArray *favs = [NSMutableArray arrayWithArray:[[self class] loadFavoriteObjects]];
        
    if( [favs containsObject:sObjectType] )
        [favs removeObject:sObjectType];
    else {
        [favs addObject:sObjectType];
        
        [[SFAnalytics sharedInstance] tagEventOfType:SFVUserAddedFavoriteObject
                                          attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                     sObjectType, @"Object",
                                                                     [SFAnalytics bucketStringForNumber:[NSNumber numberWithInt:[favs count]]
                                                                                             bucketSize:3], @"Favorite Count",
                                                                     nil]];
    }
    
    [[NSUserDefaults standardUserDefaults] setObject:favs forKey:FavoriteObjectsKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [self.navigationItem setRightBarButtonItem:[self favoriteBarButtonItem]
                                      animated:YES];
    
    // Refresh the favorites view if it's in the current window stack
    for( SubNavViewController *snvc in [self.rootViewController viewControllers] )
        if( snvc.subNavTableType == SubNavFavoriteObjects ) {
            NSLog(@"REFRESH FAVS");
            [snvc refresh];
        }
}

@end

#pragma mark - transparent navigation bar

@implementation TransparentNavigationBar

// Override draw rect to avoid
// background coloring
- (void)drawRect:(CGRect)rect {
    // do nothing in here
}


- (void) applyTranslucentBackground {
    self.backgroundColor = [UIColor clearColor];
}

// Override init.
- (id) init {
    self = [super init];
    [self applyTranslucentBackground];
    return self;
}

// Override initWithFrame.
- (id) initWithFrame:(CGRect) frame {
    self = [super initWithFrame:frame];
    [self applyTranslucentBackground];
    return self;
}

@end

#pragma mark - transparent toolbar

@implementation TransparentToolBar

// Override draw rect to avoid
// background coloring
- (void)drawRect:(CGRect)rect {
    // do nothing in here
}


- (void) applyTranslucentBackground {
    self.backgroundColor = [UIColor clearColor];
}

// Override init.
- (id) init {
    self = [super init];
    [self applyTranslucentBackground];
    return self;
}

// Override initWithFrame.
- (id) initWithFrame:(CGRect) frame {
    self = [super initWithFrame:frame];
    [self applyTranslucentBackground];
    return self;
}

@end
