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
#import "RecentRecordsController.h"
#import "SFVUtil.h"
#import "PRPSmartTableViewCell.h"
#import "DetailViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "SFVAppCache.h"
#import "SFVAsync.h"
#import "SFRestAPI+SFVAdditions.h"
#import "RootViewController.h"

@implementation RecentRecordsController

static int const kMaxSearchLength = 35;
static NSString *kLastSelectedIndexKey = @"LastSelectedRecentOrdering";

- (id) initWithFrame:(CGRect)frame {
    if(( self = [super initWithFrame:frame] )) {
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.gif"]];

        searching = NO;
        
        recordDictionary = [[NSMutableDictionary alloc] init];
        searchResults = [[NSMutableArray alloc] init];
        
        float curY = CGRectGetHeight( self.navBar.frame );
        
        recordSearchBar = [[UISearchBar alloc] initWithFrame:CGRectMake(5, curY, CGRectGetWidth(frame) - 10, 44 )];
        recordSearchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        recordSearchBar.placeholder = NSLocalizedString(@"Recent Records", @"Recent Records");
        recordSearchBar.delegate = self;
        recordSearchBar.alpha = 0.0f;
        
        [[recordSearchBar.subviews objectAtIndex:0] removeFromSuperview];
        
        for (UIView *view in recordSearchBar.subviews)
            if ([view isKindOfClass: [UITextField class]]) {
                UITextField *tf = (UITextField *)view;
                tf.delegate = self;
                break;
            }
        
        UIView *searchBarBG = [[UIView alloc] initWithFrame:CGRectMake(0, curY, CGRectGetWidth(frame), 44 )];
        searchBarBG.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"tableBG.png"]];
        searchBarBG.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        
        [self.view addSubview:searchBarBG];
        [searchBarBG release];
        
        [self.view addSubview:recordSearchBar];
        
        curY += CGRectGetHeight(recordSearchBar.frame);
        
        recordOrderingControl = [[UISegmentedControl alloc] initWithFrame:CGRectMake( floorf( ( CGRectGetWidth(frame) - 100 ) / 2.0f ), curY,
                                                                                     85, 30 )];
        
        [recordOrderingControl insertSegmentWithImage:[UIImage imageNamed:@"sort_time.png"]
                                              atIndex:0
                                             animated:NO];
        
        [recordOrderingControl insertSegmentWithImage:[UIImage imageNamed:@"sort_type.png"]
                                              atIndex:1
                                             animated:NO];
        
        [recordOrderingControl setSegmentedControlStyle:UISegmentedControlStyleBar];
        [recordOrderingControl setSelectedSegmentIndex:0];
        [recordOrderingControl addTarget:self
                                  action:@selector(orderingControlChanged)
                        forControlEvents:UIControlEventValueChanged];
        
        actionButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction
                                                                     target:self
                                                                     action:@selector(recentRecordsAction:)];
                                 
        recordTable = [[UITableView alloc] initWithFrame:CGRectMake(0, curY, 
                                                                    CGRectGetWidth(frame), CGRectGetHeight(frame) - curY) 
                                                   style:UITableViewStylePlain];
        recordTable.delegate = self;
        recordTable.dataSource = self;
        recordTable.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.gif"]];
        recordTable.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        
        // Table Footer            
        UIImage *i = [UIImage imageNamed:@"tilde.png"];
        UIImageView *iv = [[[UIImageView alloc] initWithImage:i] autorelease];
        iv.alpha = 0.25f;
        iv.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        CGPoint origin = CGPointCenteredOriginPointForRects(recordTable.frame, CGRectMake(0, 0, i.size.width, i.size.height));
        
        [iv setFrame:CGRectMake( origin.x, 5, i.size.width, i.size.height )];
                
        UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(self.view.frame), 70 )] autorelease];
        [footerView addSubview:iv];
        
        recordTable.tableFooterView = footerView;
        
        [self.view addSubview:recordTable];
        [self.view sendSubviewToBack:recordTable];
    }
    
    return self;
}

- (void) dealloc {
    SFRelease(sheet);
    SFRelease(recordTable);
    SFRelease(recordDictionary);
    SFRelease(recentObjects);
    SFRelease(recordSearchBar);
    SFRelease(recordOrderingControl);
    SFRelease(searchResults);
    SFRelease(actionButton);
    [super dealloc];
}

- (void) showNoRecentView {
    [recordTable removeFromSuperview];
    
    CGRect r = CGRectMake( 0, 200, CGRectGetWidth(self.view.frame), 100);
    
    UIView *v = [[UIView alloc] initWithFrame:r];
    v.autoresizingMask = UIViewAutoresizingFlexibleHeight;
    v.backgroundColor = [UIColor clearColor];
    
    // label 1
    UILabel *l1 = [[UILabel alloc] initWithFrame:CGRectMake(0, 100, v.frame.size.width, 30)];
    l1.text = NSLocalizedString(@"No Recent Records", @"No recent records");
    l1.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:24];
    l1.textColor = [UIColor darkGrayColor];
    l1.textAlignment = UITextAlignmentCenter;
    l1.backgroundColor = [UIColor clearColor];
    l1.shadowColor = [UIColor lightGrayColor];
    l1.shadowOffset = CGSizeMake( 0, 1 );
    
    [v addSubview:l1];
    [l1 release];
    
    // label 2
    UILabel *l2 = [[UILabel alloc] initWithFrame:CGRectZero];
    l2.text = NSLocalizedString(@"NORECENT_SUBTITLE", @"Records you view in SFiPad will appear here.");
    l2.font = [UIFont boldSystemFontOfSize:16];
    l2.textColor = [UIColor lightGrayColor];
    l2.textAlignment = UITextAlignmentCenter;
    l2.backgroundColor = [UIColor clearColor];
    l2.numberOfLines = 0;
    
    CGSize s = [l2.text sizeWithFont:l2.font constrainedToSize:CGSizeMake( r.size.width - 20, 200 )];
    [l2 setFrame:CGRectMake( floorf( ( r.size.width - s.width ) / 2.0f ), 130, s.width, s.height )];
    
    [v addSubview:l2];
    [l2 release];
    
    [self.view addSubview:v];   
    [v release];
}

- (void) orderingControlChanged {
    [[NSUserDefaults standardUserDefaults] setObject:[NSNumber numberWithInt:recordOrderingControl.selectedSegmentIndex]
                                              forKey:kLastSelectedIndexKey];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    [recordSearchBar resignFirstResponder];
    [recordTable reloadData];
    [recordTable setContentOffset:CGPointZero animated:YES];
}

#pragma mark - loading

- (void) updateNavBar {
    [recordOrderingControl setSelectedSegmentIndex:[[NSUserDefaults standardUserDefaults] integerForKey:kLastSelectedIndexKey]];
    [self orderingControlChanged];
    
    if( [recordTable isEditing] ) {
        self.navBar.topItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
                                                                                                target:self 
                                                                                                action:@selector(recentRecordsAction:)] autorelease];
    } else {
        [UIView animateWithDuration:0.5
                         animations:^(void) {
                             recordSearchBar.alpha = 1.0f;
                         }];
        
        UIToolbar *rightBar = [[UIToolbar alloc] initWithFrame:CGRectMake( 0, 0, 135, CGRectGetHeight(self.navBar.frame))];
        rightBar.tintColor = self.navBar.tintColor;
        [rightBar setItems:[NSArray arrayWithObjects:
                            [[[UIBarButtonItem alloc] initWithCustomView:recordOrderingControl] autorelease],
                            [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                           target:nil action:nil] autorelease],
                            actionButton,
                            nil]
                  animated:NO];
        
        [self pushNavigationBarWithTitle:NSLocalizedString(@"Recent Records", @"Recent Records")
                                leftItem:( [RootViewController isPortrait]
                                           ? self.detailViewController.browseButton
                                           : nil )
                               rightItem:[[[UIBarButtonItem alloc] initWithCustomView:rightBar] autorelease]
                                animated:NO];
        [rightBar release];
    }
}

- (void) selectAccount:(NSDictionary *)acc {
    [super selectAccount:acc];
    
    [self pushNavigationBarWithTitle:NSLocalizedString(@"Loading...", @"Loading...") animated:NO];
    [self performSelector:@selector(loadRecentRecords) withObject:nil afterDelay:0.5];
}

- (void) loadRecentRecords {
    NSArray *records = [[SFVUtil sharedSFVUtil] loadRecentRecords];
    
    if( !records || [records count] == 0 ) {
        [self pushNavigationBarWithTitle:NSLocalizedString(@"Recent Records", @"Recent Records")
                                leftItem:( [RootViewController isPortrait]
                                           ? self.detailViewController.browseButton
                                           : nil )
                               rightItem:nil];
        
        [UIView animateWithDuration:0.5
                         animations:^(void) {
                             recordSearchBar.alpha = 0.0f;
                         }];
        
        [self showNoRecentView];
        return;
    }    
    
    // Group our recent records by object
    recentObjects = [[NSMutableDictionary alloc] init];
    
    for( NSString *recordId in records ) {
        NSString *obName = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:recordId];
        
        if( !obName )
            continue;
        
        if( [recentObjects objectForKey:obName] )
            [[recentObjects objectForKey:obName] addObject:recordId];
        else
            [recentObjects setObject:[NSMutableArray arrayWithObject:recordId] forKey:obName];
    }
    
    objectsQueried = 0;
    
    if( [recentObjects count] > 0 ) {
        objectsToQuery = [recentObjects count];

        for( NSString *sObject in [recentObjects allKeys] )
            [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:sObject
                                                            failBlock:nil
                                                        completeBlock:^(NSDictionary *desc) {
                                                            if( ![self isViewLoaded] ) 
                                                                return;
                                                            
                                                            [self describeCompleteForObject:sObject];
                                                        }];
        
        
    } else {
        [[SFVUtil sharedSFVUtil] clearRecentRecords];
        [self loadRecentRecords];
    }
}

- (void) describeCompleteForObject:(NSString *)sObject { 
    // Ensure we have cached the image for this sobject
    NSString *imgUrl = [[SFVAppCache sharedSFVAppCache] logoURLForSObjectTab:sObject];
        
    if( imgUrl )
        [[SFVUtil sharedSFVUtil] loadImageFromURL:imgUrl
                                            cache:YES
                                     maxDimension:recordTable.rowHeight
                                    completeBlock:^(UIImage *img, BOOL wasLoadedFromCache) {
                                        if( ![self isViewLoaded] )
                                            return;
                                        
                                        [self performQueryForObject:sObject];
                                    }];
    else
        [self performQueryForObject:sObject];
}

- (void) performQueryForObject:(NSString *)sObject {
    [SFVAsync performRetrieveWithFields:[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:sObject]
                                 sObject:sObject
                                     ids:[recentObjects objectForKey:sObject]
                               failBlock:^(NSException *e) {
                                   [self objectQueryCompletedWithRecords:sObject records:nil];
                               }
                           completeBlock:^(NSDictionary *results) {
                               if( ![self isViewLoaded] ) 
                                   return;
                               
                               if( results && [[results allValues] count] > 0 )
                                   [self objectQueryCompletedWithRecords:sObject records:[results allValues]];
                               else
                                   [self objectQueryCompletedWithRecords:sObject records:nil];
                           }];
}

- (void) objectQueryCompletedWithRecords:(NSString *)sObject records:(NSArray *)records {    
    objectsQueried++;
        
    if( records && [records count] > 0 ) {
        NSMutableSet *receivedObjectIds = [NSMutableSet setWithCapacity:[records count]];
        NSArray *targetObjectIds = [[SFVUtil sharedSFVUtil] recentRecordsForSObject:sObject];
        
        for( NSDictionary *record in [SFVAsync ZKSObjectArrayToDictionaryArray:records] ) {
            [recordDictionary setObject:record forKey:[record objectForKey:@"Id"]];
            [receivedObjectIds addObject:[record objectForKey:@"Id"]];
        }
        
        // Remove any recent records that no longer exist
        for( NSString *recordId in targetObjectIds )
            if( ![receivedObjectIds containsObject:recordId] ) {
                [[recentObjects objectForKey:sObject] removeObject:recordId];
                [[SFVUtil sharedSFVUtil] removeRecentRecordWithId:recordId];
            }
        
        [recordTable beginUpdates];
        
        for( NSString *recordId in receivedObjectIds )
            [recordTable insertRowsAtIndexPaths:[NSArray arrayWithObject:[self indexPathFromRecordId:recordId]] 
                               withRowAnimation:UITableViewRowAnimationFade];
        
        [recordTable endUpdates];
    }

    if( objectsQueried == objectsToQuery )
        [self updateNavBar];
}

#pragma mark - util

- (void) recentRecordsAction:(id)sender {
    if( [recordTable isEditing] ) {
        [recordTable setEditing:NO animated:YES];
        [self updateNavBar];
        recordSearchBar.text = @"";
        [recordSearchBar resignFirstResponder];
        
        [UIView animateWithDuration:0.25f
                         animations:^(void) {
                             recordSearchBar.alpha = 1.0f;
                         }];
        return;
    }
    
    if( sheet ) {
        [sheet dismissWithClickedButtonIndex:-1 animated:YES];
        SFRelease(sheet);
        return;
    }
    
    sheet = [[UIActionSheet alloc] init];
    sheet.title = nil;
    [sheet addButtonWithTitle:NSLocalizedString(@"Edit", @"Edit") ];
    sheet.destructiveButtonIndex = [sheet addButtonWithTitle:NSLocalizedString(@"Clear Recent Records", @"Clear Recent Records")];
    sheet.delegate = self;
    
    [sheet showFromBarButtonItem:sender animated:YES];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    [recordSearchBar resignFirstResponder];
    
    if( buttonIndex == actionSheet.destructiveButtonIndex ) {
        [[SFVUtil sharedSFVUtil] clearRecentRecords];
        [self loadRecentRecords];
    } else if( buttonIndex == 0 ) {
        [recordTable setEditing:YES animated:YES];
        [self updateNavBar];
        
        [UIView animateWithDuration:0.25f
                         animations:^(void) {
                             recordSearchBar.alpha = 0.2f;
                         }];
    }
    
    SFRelease(sheet);
}

- (NSString *)recordIdFromIndexPath:(NSIndexPath *)path {   
    if( searching )
        return [searchResults objectAtIndex:path.row];
    
    if( recordOrderingControl.selectedSegmentIndex == 0 ) { 
        int counter = 0;
        
        for( NSString *record in  [[SFVUtil sharedSFVUtil] loadRecentRecords] )
            if( [recordDictionary objectForKey:record] ) {
                if( path.row == counter )
                    return record;
                
                counter++;
            }
    } else
        return [[recentObjects objectForKey:[[self sectionTitles] objectAtIndex:path.section]] objectAtIndex:path.row];
        
    return nil;
}

- (NSIndexPath *) indexPathFromRecordId:(NSString *)recordId {
    NSArray *records = [[SFVUtil sharedSFVUtil] loadRecentRecords];
    int counter = 0;
    
    for( NSString *record in records ) {
        if( [recordDictionary objectForKey:record] ) {            
            if( [record isEqualToString:recordId] )
                return [NSIndexPath indexPathForRow:counter inSection:0];
            
            counter++;
        }
    }
    
    return nil;
}

#pragma mark - tableview delegate

- (NSArray *) sectionTitles {
    return [[SFVUtil sharedSFVUtil] sortGlobalObjectArray:[recentObjects allKeys]];
}

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return YES;
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if( editingStyle == UITableViewCellEditingStyleDelete ) {
        NSString *record = [self recordIdFromIndexPath:indexPath];
        
        if( !record )
            return;
        
        // Wipe from local
        [recordDictionary removeObjectForKey:record];
        [searchResults removeObject:record];
    
        NSString *sObject = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:record];
        
        [[recentObjects objectForKey:sObject] removeObject:record];
        
        if( [[recentObjects objectForKey:sObject] count] == 0 )
            [recentObjects removeObjectForKey:sObject];
                        
        // Wipe from storage
        [[SFVUtil sharedSFVUtil] removeRecentRecordWithId:record];
        
        // Update table
        if( [recordDictionary count] == 0 )
            [self loadRecentRecords];
        else if( recordOrderingControl.selectedSegmentIndex == 1 && ![recentObjects objectForKey:sObject] )
            [recordTable deleteSections:[NSIndexSet indexSetWithIndex:indexPath.section]
                       withRowAnimation:UITableViewRowAnimationFade];
        else
            [recordTable deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                             withRowAnimation:UITableViewRowAnimationFade];
    }
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return ( recordOrderingControl.selectedSegmentIndex == 0 ? 0 : [UIImage imageNamed:@"sectionheader.png"].size.height );
} 

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIImageView *sectionView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sectionheader.png"]];
    
    UILabel *customLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, -1, sectionView.frame.size.width, sectionView.frame.size.height )];
    customLabel.textColor = [UIColor whiteColor];
    customLabel.text = [self tableView:tableView titleForHeaderInSection:section];    
    customLabel.font = [UIFont boldSystemFontOfSize:16];
    customLabel.backgroundColor = [UIColor clearColor];
    [sectionView addSubview:customLabel];
    [customLabel release];
    
    return [sectionView autorelease];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if( searching || recordOrderingControl.selectedSegmentIndex == 0 )
        return nil;
    
    return [[SFVAppCache sharedSFVAppCache] labelForSObject:[[self sectionTitles] objectAtIndex:section] usePlural:YES];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return ( recordOrderingControl.selectedSegmentIndex == 0 ? 1 : [[recentObjects allKeys] count] );
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if( searching )
        return [searchResults count];
    
    if( recordOrderingControl.selectedSegmentIndex == 0 )
        return [recordDictionary count];
    
    NSString *object = [[self sectionTitles] objectAtIndex:section];
    
    return [[recentObjects objectForKey:object] count];
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PRPSmartTableViewCell *cell = [PRPSmartTableViewCell cellForTableView:tableView];
    
    cell.textLabel.textColor = AppLinkColor;
    cell.textLabel.numberOfLines = 2;
    cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
    cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
    
    NSString *recordId = nil;
    NSDictionary *record = nil;
    
    if( searching )
        recordId = [searchResults objectAtIndex:indexPath.row];
    else if( recordOrderingControl.selectedSegmentIndex == 0 )
        recordId = [self recordIdFromIndexPath:indexPath];
    else {
        NSString *object = [[self sectionTitles] objectAtIndex:indexPath.section];
        recordId = [[recentObjects objectForKey:object] objectAtIndex:indexPath.row];
    }
    
    record = [recordDictionary objectForKey:recordId];     
            
    if( !record )
        cell.textLabel.text = @"Error";
    else {
        cell.textLabel.text = [[SFVAppCache sharedSFVAppCache] nameForSObject:record];
        cell.imageView.image = [[SFVAppCache sharedSFVAppCache] imageForSObjectFromCache:[record objectForKey:kObjectTypeKey]];
        
        if( [[SFVAppCache sharedSFVAppCache] descriptionFieldForObject:[record objectForKey:kObjectTypeKey]] ) {
            cell.detailTextLabel.text = [[SFVUtil sharedSFVUtil] textValueForField:[[SFVAppCache sharedSFVAppCache] 
                                                                                    descriptionFieldForObject:[record objectForKey:kObjectTypeKey]]
                                                                    withDictionary:record];
            cell.textLabel.numberOfLines = 1;
        } else
            cell.detailTextLabel.text = @"";
    }
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *recordId = nil;
    
    if( searching )
        recordId = [searchResults objectAtIndex:indexPath.row];
    else if( recordOrderingControl.selectedSegmentIndex == 0 )
        recordId = [self recordIdFromIndexPath:indexPath];
    else {
        NSString *object = [[self sectionTitles] objectAtIndex:indexPath.section];
        recordId = [[recentObjects objectForKey:object] objectAtIndex:indexPath.row];
    }
    
    NSDictionary *record = [recordDictionary objectForKey:recordId];
    
    [recordSearchBar resignFirstResponder];
    
    [self.detailViewController didSelectAccount:record];
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    [recordSearchBar resignFirstResponder];
}

#pragma mark - searching

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    searchText = [SFVUtil trimWhiteSpaceFromString:searchText];
    
    if( !searchText || [searchText length] == 0 ) {
        searching = NO;
        
        [UIView animateWithDuration:0.5 
                         animations:^(void) {
                             recordOrderingControl.alpha = 1.0f;
                             recordOrderingControl.enabled = YES;
                             actionButton.enabled = YES;
                         }];
        
        recordTable.hidden = NO;
        [recordTable reloadData];
    } else {
        searching = YES;
        [recordSearchBar becomeFirstResponder];
        
        [UIView animateWithDuration:0.5
                         animations:^(void) {
                             recordOrderingControl.selectedSegmentIndex = 0;        
                             recordOrderingControl.alpha = 0.3f;
                             recordOrderingControl.enabled = NO;
                             actionButton.enabled = NO;
                         }];
        
        [searchResults removeAllObjects];
        
        for( NSDictionary *object in [recordDictionary allValues] )
            for( id value in [object allValues] ) {
                if( [value isKindOfClass:[NSString class]] &&
                   [value rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound &&
                   ![searchResults containsObject:[object objectForKey:@"Id"]] )
                    [searchResults addObject:[object objectForKey:@"Id"]];
                else if( [value isKindOfClass:[NSDictionary class]] )
                    for( NSString *field in [value allKeys] ) {
                        if( [field isEqualToString:@"Id"] )
                            continue;
                        
                        if( [[(NSDictionary *)value objectForKey:field] rangeOfString:searchText options:NSCaseInsensitiveSearch].location != NSNotFound &&
                            ![searchResults containsObject:[object objectForKey:@"Id"]] )
                            [searchResults addObject:[object objectForKey:@"Id"]];
                    }
            }
        
        [recordTable reloadData];
    }
}

#pragma mark - textfield delegate

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    return ![recordTable isEditing];
}

- (BOOL)textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {
    NSString *t = [textField.text stringByReplacingCharactersInRange:range withString:string];
    return [t length] <= kMaxSearchLength;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return YES;
}

@end
