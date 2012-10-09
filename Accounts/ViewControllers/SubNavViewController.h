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
#import "AQGridView.h"

@class DetailViewController;
@class RootViewController;
@class ObjectGridCell;

#define GlobalObjectOrderingKey     @"globalObjectOrderingKey"
#define FavoriteObjectsKey          @"favoriteObjectsKey"

@interface SubNavViewController : UIViewController 
                <UISearchBarDelegate, UITextFieldDelegate, UITableViewDataSource, 
                UITableViewDelegate, UIActionSheetDelegate, AQGridViewDelegate, AQGridViewDataSource, UIGestureRecognizerDelegate> {
    BOOL searching, isSearchPending;
    BOOL queryingMore;
    int storedSize;
                    
    // Draggable gridview
    BOOL isGridviewDraggable;
    NSUInteger _emptyCellIndex;
    NSUInteger _dragOriginIndex;
    CGPoint _dragOriginCellOrigin;
    ObjectGridCell * _draggingCell;
    AQGridView *gridView;
                    
    UIView *loadingView;
    UILabel *rowCountLabel;
    UIToolbar *bottomBar;
    UIView *tableHeader;
    UIBarButtonItem *refreshButton;
    UISegmentedControl *orderingControl;
    NSString *queryLocator;
    UIActionSheet *sheet;
}

// The top-level type of this subnav
typedef enum SubNavTableType {
    SubNavAllObjects = 0,
    SubNavObjectListTypePicker,
    SubNavListOfRemoteRecords,
    SubNavFavoriteObjects,
    SubNavAppPicker,
    SubNavAppTabPicker,
    SubNavDummyController,
    SubNavTableNumTypes
} SubNavTableType;

// The table rows displayed when we choose a particular sObject
typedef enum SubNavObjectListType {
    ObjectListRecentRecords = 0,
    ObjectListMyOpenTasks,
    ObjectListMyOpenCases,
    ObjectListMyUpcomingOpportunities,
    ObjectListMyClosedOpportunities,
    ObjectListMyUnreadLeads,
    ObjectListMyUpcomingEvents,
    ObjectListMyPastEvents,
    ObjectListRecordsIOwn,
    ObjectListRecordsIFollow,
    ObjectListRecordsICreated,
    ObjectListRecordsIRecentlyModified,
    ObjectListAllRecentlyCreated,
    ObjectListAllRecentlyModified,
    ObjectListViewOnTheWeb,
    ObjectListNumTypes
} SubNavObjectListType;

// Different ways to order lists of records
typedef enum SubNavOrderingType {
    OrderingName = 0,
    OrderingCreated,
    OrderingModified,
    OrderingNumTypes
} SubNavOrderingType;

@property (nonatomic) SubNavOrderingType subNavOrderingType;
@property (nonatomic) SubNavTableType subNavTableType;
@property (nonatomic) SubNavObjectListType subNavObjectListType;
@property (nonatomic) NSUInteger appIndex;

@property (nonatomic, retain) UITableViewController *pullRefreshTableViewController;
@property (nonatomic, retain) UISearchBar *searchBar;
@property (nonatomic, retain) NSMutableDictionary *searchResults;
@property (nonatomic, retain) NSMutableDictionary *myRecords;
@property (nonatomic, retain) NSString *sObjectType;

@property (nonatomic, assign) DetailViewController *detailViewController;
@property (nonatomic, assign) RootViewController *rootViewController;

- (id) initWithTableType:(SubNavTableType) tableType;
- (SubNavTableType) subNavTableType;

- (void) toggleNoFavsView;

- (void) resignResponder;

- (void) clearRecords;
- (void) refresh;
- (void) refreshResult:(NSArray *)results;
- (void) queryMore;
- (void) tappedHeader:(id)sender;
- (void) pushTitle:(NSString *)title leftItem:(UIBarButtonItem *)leftItem rightItem:(UIBarButtonItem *)rightItem animated:(BOOL)animated;
- (NSString *) queryForRecords;

- (void) cancelSearch;
- (void) searchTableView;
- (void) handleInterfaceRotation:(BOOL) isPortrait;

- (void) insertFollowedRecord:(NSDictionary *)record;
- (void) removeFollowedRecordWithId:(NSString *)recordId;

- (void) selectAccountWithId:(NSString *)accountId;
- (void) updateTitleBar;
- (void) setLoadingViewVisible:(BOOL)visible;

- (IBAction) showSettings:(id)sender;
- (IBAction) tappedLogo:(id)sender;
- (IBAction) showFavorites:(id)sender;
- (IBAction) refreshGlobalObjects:(id)sender;

- (UIViewAnimationTransition) animationTransitionForPush;
- (UIViewAnimationTransition) animationTransitionForPop;
- (NSArray *) listsForObject;

// Favorites
+ (NSArray *) loadFavoriteObjects;
- (BOOL) currentObjectIsFavorite;
- (IBAction) toggleObjectIsFavorite:(id)sender;
- (UIBarButtonItem *) favoriteBarButtonItem;

@end

// http://stackoverflow.com/questions/2315862/iphone-sdk-make-uinavigationbar-transparent
@interface TransparentNavigationBar : UINavigationBar
@end

@interface TransparentToolBar : UIToolbar
@end
