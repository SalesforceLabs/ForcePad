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

#import "ObjectLookupController.h"
#import "PRPSmartTableViewCell.h"
#import "PRPConnection.h"
#import "SimpleKeychain.h"
#import "RootViewController.h"
#import "SFVAsync.h"
#import "SFVUtil.h"
#import "SFVAppCache.h"
#import "SFRestAPI+SFVAdditions.h"

@implementation ObjectLookupController

@synthesize searchBar, delegate, onlyShowChatterEnabledObjects;

static CGFloat const searchDelay = 0.4f;

// Used to indicate an object type that cannot be searched with SOSL
static NSString *kSOQLSearchScope = @"SOQLOnly";

- (id) initWithSearchScope:(NSDictionary *)scope {
    if(( self = [super init] )) {
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
        self.contentSizeForViewInPopover = CGSizeMake( 350, 44 * 6 );
        
        searching = NO;
        onlyShowChatterEnabledObjects = NO;
        objectsChecked = objectsToCheck = 0;
        searchScope = [[NSMutableDictionary alloc] init];
        searchResults = [[NSMutableDictionary alloc] init];
                
        // searchscope
        if( [scope count] > 0 ) {
            // fill in any missing scopes
            for( NSString *object in [scope allKeys] ) {
                if( ![[SFVAppCache sharedSFVAppCache] doesGlobalObject:object
                                                          haveProperty:GlobalObjectIsSearchable] )
                    [searchScope setObject:kSOQLSearchScope
                                    forKey:object];
                else if( [[scope objectForKey:object] isEqualToString:@""] )
                    [searchScope setObject:[[self class] searchScopeForObject:object]
                                    forKey:object];
                else
                    [searchScope setObject:[scope objectForKey:object]
                                    forKey:object];
            }
        }
                            
        // search bar
        self.searchBar = [[[UISearchBar alloc] initWithFrame:CGRectMake( 0, 0, self.contentSizeForViewInPopover.width, 44 )] autorelease];
        
        // Removes background
        [[self.searchBar.subviews objectAtIndex:0] removeFromSuperview];
        
        self.searchBar.delegate = self;
        [self.view addSubview:self.searchBar];
        
        // result label
        resultLabel = [[UILabel alloc] initWithFrame:CGRectMake( 0, 
                                                                    self.searchBar.frame.size.height + lroundf( ( self.contentSizeForViewInPopover.height - self.searchBar.frame.size.height - 30 ) / 2.0f ), 
                                                                    self.contentSizeForViewInPopover.width, 30 )];
        [resultLabel setFont:[UIFont boldSystemFontOfSize:20]];
        resultLabel.textColor = [UIColor lightGrayColor];
        resultLabel.backgroundColor = [UIColor clearColor];
        resultLabel.textAlignment = UITextAlignmentCenter;
        resultLabel.numberOfLines = 0;
        [self.view addSubview:resultLabel];
        
        CGPoint origin;
        
        // search icon
        UIImage *icon = [UIImage imageNamed:@"searchicon.png"];
        searchIcon = [[UIImageView alloc] initWithImage:icon];
        
        origin = CGPointCenteredOriginPointForRects(CGRectMake(0, CGRectGetHeight(self.searchBar.frame), self.contentSizeForViewInPopover.width, 
                                                               self.contentSizeForViewInPopover.height - CGRectGetHeight(self.searchBar.frame)), 
                                                    CGRectMake(0, 0, icon.size.width, icon.size.height));
        
        [searchIcon setFrame:CGRectMake( origin.x, origin.y, 
                                             icon.size.width, icon.size.height )];
        [self.view addSubview:searchIcon];
        
        // result table
        resultTable = [[UITableView alloc] initWithFrame:CGRectMake( 0, self.searchBar.frame.size.height, 
                                                                          self.contentSizeForViewInPopover.width, 
                                                                          self.contentSizeForViewInPopover.height - self.searchBar.frame.size.height )
                                                         style:UITableViewStylePlain];
        resultTable.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
        resultTable.separatorColor = [UIColor darkGrayColor];
        resultTable.delegate = self;
        resultTable.dataSource = self;
        resultTable.hidden = YES;
        resultTable.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        [self.view addSubview:resultTable];
        
        // Table Footer            
        UIImage *i = [UIImage imageNamed:@"tilde.png"];
        UIImageView *iv = [[[UIImageView alloc] initWithImage:i] autorelease];
        iv.alpha = 0.25f;
        
        CGPoint center = CGPointCenteredOriginPointForRects(resultTable.frame, CGRectMake(0, 0, i.size.width, i.size.height));
        
        [iv setFrame:CGRectMake( center.x, 0, i.size.width, i.size.height )];
        
        UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(resultTable.frame), 45 )] autorelease];
        [footerView addSubview:iv];
        
        resultTable.tableFooterView = footerView;
    }
    
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    if( searchScope && [searchScope count] > 0 ) {
        NSArray *names = [[SFVUtil sharedSFVUtil] sortGlobalObjectArray:[searchScope allKeys]];
        NSMutableArray *labels = [NSMutableArray arrayWithCapacity:[names count]];
        
        for( NSString *name in names )
            [labels addObject:[[SFVAppCache sharedSFVAppCache] labelForSObject:name usePlural:YES]];
        
        searchBar.placeholder = [labels componentsJoinedByString:@", "];
    } else if( onlyShowChatterEnabledObjects )
        searchBar.placeholder = NSLocalizedString(@"ALLFEEDRECORDS", @"All feed-enabled Records");
    else        
        searchBar.placeholder = NSLocalizedString(@"ALLRECORDS", @"All Records");
    
    [self loadRecentRecordsFromMetadata];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    self.delegate = nil;
}

- (void)dealloc {
    self.searchBar = nil;

    SFRelease(searchResults);
    SFRelease(resultTable);
    SFRelease(resultLabel);
    SFRelease(searchIcon);
    SFRelease(searchScope);
    self.delegate = nil;
    
    [super dealloc];
}

#pragma mark - table view

- (NSString *) sObjectForSection:(NSInteger)section {
    return [[[SFVUtil sharedSFVUtil] sortGlobalObjectArray:[searchResults allKeys]] objectAtIndex:section];
}

- (NSArray *) searchResultsForSection:(NSInteger)section {
    return [searchResults objectForKey:[self sObjectForSection:section]];
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return [UIImage imageNamed:@"sectionheader.png"].size.height;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UIImageView *sectionView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sectionheader.png"]];
    
    UILabel *customLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, -1, sectionView.frame.size.width, sectionView.frame.size.height )];
    customLabel.textColor = AppSecondaryColor;
    customLabel.text = [self tableView:tableView titleForHeaderInSection:section];
    customLabel.font = [UIFont boldSystemFontOfSize:16];
    customLabel.backgroundColor = [UIColor clearColor];
    [sectionView addSubview:customLabel];
    [customLabel release];
    
    return [sectionView autorelease];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    return [[self searchResultsForSection:section] count];
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return [searchResults count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [NSString stringWithFormat:@"%@%@ (%i)",
            ( [tableView numberOfSections] == 1 && !searching ? @"Recent " : @"" ),
            [[SFVAppCache sharedSFVAppCache] labelForSObject:[self sObjectForSection:section]
                                                   usePlural:YES],
            [self tableView:tableView numberOfRowsInSection:section]];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *sectionRecords = [self searchResultsForSection:indexPath.section];
    
    if( !sectionRecords || [sectionRecords count] == 0 )
        return;
    
    NSDictionary *result = [sectionRecords objectAtIndex:indexPath.row];
    
    NSString *imgURL = [result objectForKey:@"SmallPhotoUrl"];
    
    if( [imgURL hasPrefix:@"/"] )
        imgURL = [NSString stringWithFormat:@"%@%@",
                  [SimpleKeychain load:instanceURLKey],
                  imgURL]; 
    
    if( imgURL )
        [[SFVUtil sharedSFVUtil] loadImageFromURL:[SFVUtil stringByAppendingSessionIdToURLString:imgURL
                                                                                       sessionId:[[SFVUtil sharedSFVUtil] sessionId]]
                                            cache:YES
                                     maxDimension:resultTable.rowHeight
                                    completeBlock:^(UIImage *img, BOOL wasLoadedFromCache) {
                                        if( ![self isViewLoaded] )
                                            return;
                                        
                                        if( [tableView numberOfSections] < indexPath.section || [tableView numberOfRowsInSection:indexPath.section] < indexPath.row )
                                            return;
                                        
                                        if( !wasLoadedFromCache )
                                            [resultTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                                               withRowAnimation:UITableViewRowAnimationFade];
                                    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PRPSmartTableViewCell *cell = [PRPSmartTableViewCell cellForTableView:tableView];
    NSArray *sectionRecords = [self searchResultsForSection:indexPath.section];
    
    if( !sectionRecords || [sectionRecords count] == 0 )
        return cell;
    
    NSDictionary *result = [sectionRecords objectAtIndex:indexPath.row];
    NSString *type = [result objectForKey:kObjectTypeKey];
    
    cell.textLabel.text = [[SFVAppCache sharedSFVAppCache] nameForSObject:result];
    cell.textLabel.textColor = [UIColor lightGrayColor];
    cell.textLabel.font = [UIFont boldSystemFontOfSize:15];
    cell.detailTextLabel.textColor = [UIColor lightGrayColor];
    cell.imageView.image = nil;
    cell.detailTextLabel.text = nil;
    cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
    
    NSString *descField = [[SFVAppCache sharedSFVAppCache] descriptionFieldForObject:type];
        
    if( [type isEqualToString:@"CollaborationGroup"] )
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@, %@ Member%@",
                                     [result objectForKey:@"CollaborationType"],
                                     [result objectForKey:@"MemberCount"],
                                     ( [[result objectForKey:@"MemberCount"] intValue] != 1 ? @"s" : @"" )];
    else if( descField && ![SFVUtil isEmpty:[result valueForKeyPath:descField]] )        
        cell.detailTextLabel.text = [result valueForKeyPath:descField];
    
    cell.textLabel.numberOfLines = 1 + ( [SFVUtil isEmpty:cell.detailTextLabel.text] ? 1 : 0 );
    
    NSString *imgURL = [result objectForKey:@"SmallPhotoUrl"];
    
    if( [imgURL hasPrefix:@"/"] )
        imgURL = [NSString stringWithFormat:@"%@%@",
                    [SimpleKeychain load:instanceURLKey],
                    imgURL]; 

    if( imgURL )
        cell.imageView.image = [[SFVUtil sharedSFVUtil] userPhotoFromCache:
                                [SFVUtil stringByAppendingSessionIdToURLString:imgURL
                                                                     sessionId:[[SFVUtil sharedSFVUtil] sessionId]]];
        
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSArray *sectionRecords = [self searchResultsForSection:indexPath.section];
    
    if( !sectionRecords || [sectionRecords count] == 0 )
        return;
    
    NSDictionary *result = [sectionRecords objectAtIndex:indexPath.row];
    
    if( [self.delegate respondsToSelector:@selector(objectLookupDidSelectRecord:record:)] )
        [self.delegate objectLookupDidSelectRecord:self record:result];
}

#pragma mark - metadata describes for default results

- (void)loadRecentRecordsFromMetadata {
    if( !searchScope || [searchScope count] == 0 )
        return;

    objectsToCheck = 1;
    
    [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:[[searchScope allKeys] objectAtIndex:0]
                                                       failBlock:nil
                                                   completeBlock:^(NSDictionary *dict) {
                                                       if( ![self isViewLoaded] )
                                                           return;
                                                       
                                                       [[SFRestAPI sharedInstance] performMetadataWithObjectType:[[searchScope allKeys] objectAtIndex:0]
                                                                                                       failBlock:nil
                                                                                                   completeBlock:^(NSDictionary *dict) {
                                                                                                       if( !dict || ![self isViewLoaded] || searching )
                                                                                                           return;
                                                                                                       
                                                                                                       NSArray *bits = [dict objectForKey:@"recentItems"];
                                                                                                       
                                                                                                       if( bits && [bits count] > 0 )
                                                                                                           [self receivedObjectResponse:[dict objectForKey:@"recentItems"]];
                                                                                                   }];
                                                   }];
}

#pragma mark - search bar delegate

- (void) searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if( !searchText || [searchText length] == 0 ) {
        searching = NO;
        
        if( searchResults ) {
            [searchResults removeAllObjects];
            [resultTable reloadData];
        }
        
        resultTable.hidden = YES;
        resultLabel.hidden = YES;
        searchIcon.hidden = NO;
        return;
    }
    
    NSString *text = [searchText stringByReplacingOccurrencesOfString:@"*" withString:@""];
    
    if( [text length] < 2 ) {
        searching = NO;
        
        if( searchResults ) {
            [searchResults removeAllObjects];
            [resultTable reloadData];
        }
        
        resultTable.hidden = YES;
        resultLabel.hidden = YES;
        searchIcon.hidden = NO;
        return;
    }
    
    resultLabel.hidden = YES;
    [NSObject cancelPreviousPerformRequestsWithTarget:self
                                             selector:@selector(search)
                                               object:nil];
    [self performSelector:@selector(search)
               withObject:nil
               afterDelay:searchDelay];
}

- (BOOL)searchBar:(UISearchBar *)sb shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if( [[sb.text stringByReplacingCharactersInRange:range withString:text] length] >= 35 )
        return NO;
    
    NSMutableCharacterSet *validChars = [NSMutableCharacterSet punctuationCharacterSet];
    [validChars formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
    [validChars formUnionWithCharacterSet:[NSCharacterSet whitespaceCharacterSet]];
    
    NSCharacterSet *unacceptedInput = [validChars invertedSet];
    
    text = [[text lowercaseString] decomposedStringWithCanonicalMapping];
    
    return [[text componentsSeparatedByCharactersInSet:unacceptedInput] count] == 1;
}

- (void) searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [self search];
}

#pragma mark - searching SFDC

- (void)receivedObjectResponse:(NSArray *)records {
    objectsChecked++;
    
    if( objectsChecked == objectsToCheck ) {
        searching = NO;
        
        if( !searchResults || [searchResults count] == 0 ) {
            resultLabel.text = NSLocalizedString(@"No Results", @"No Results");
            resultLabel.hidden = NO;
            resultTable.hidden = YES;
        } else {
            resultLabel.hidden = YES;
            resultTable.hidden = NO;
        }
    }
    
    if( !records || [records count] == 0 )
        return;
    
    records = [SFVAsync ZKSObjectArrayToDictionaryArray:records];    
    NSString *type = [[records objectAtIndex:0] objectForKey:kObjectTypeKey];
        
    if( [SFVUtil isEmpty:type] )
        return;
    
    [searchResults setObject:records forKey:type];
        
    resultTable.hidden = NO;
    [self.view bringSubviewToFront:resultTable];
        
    [resultTable reloadData];
}

- (void)loadNamesForRecords:(NSArray *)records {
    if( !records || [records count] == 0 )
        return;
    
    NSString *type = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[records objectAtIndex:0]];
    
    if( onlyShowChatterEnabledObjects && ![[SFVAppCache sharedSFVAppCache] doesGlobalObject:type haveProperty:GlobalObjectIsFeedEnabled] ) {
        objectsChecked++;
        return;
    }
    
    // Special handling for users and groups
    if( [type isEqualToString:@"User"] ) {
        NSString *ids = [NSString stringWithFormat:@"('%@')",
                         [records componentsJoinedByString:@"','"]];
        
        NSString *query = [SFVAsync SOQLQueryWithFields:[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:type]
                                                sObject:type
                                                  where:[NSString stringWithFormat:@"isactive=true and ( usertype='Standard' or usertype = 'CSNOnly' )"
                                                            " and id in %@", ids]
                                                groupBy:nil 
                                                 having:nil 
                                                orderBy:[NSArray arrayWithObject:@"lastname asc"]
                                                  limit:[records count]];
        
        [[SFRestAPI sharedInstance] performSOQLQuery:query
                                           failBlock:^(NSError *e) {
                                               if( [self isViewLoaded] )
                                                   [self receivedObjectResponse:nil];
                                           }
                                       completeBlock:^(NSDictionary *results) {
                                           if( [self isViewLoaded] )
                                               [self receivedObjectResponse:[results objectForKey:@"records"]];
                                       }];
    } else if( [type isEqualToString:@"CollaborationGroup"] ) {
        // we can only post to groups of which we are a member, even as a sysadmin.
        NSString *query = [SFVAsync SOQLQueryWithFields:[NSArray arrayWithObjects:@"id", @"collaborationgroupid", @"collaborationgroup.name", 
                                                         @"collaborationgroup.membercount", @"collaborationgroup.collaborationtype", 
                                                         @"collaborationgroup.smallphotourl", nil]
                                                sObject:@"CollaborationGroupMember"
                                                  where:[NSString stringWithFormat:@"memberid='%@'",
                                                         [[SFVUtil sharedSFVUtil] currentUserId]]
                                                  limit:2000];
        
        [[SFRestAPI sharedInstance] performSOQLQuery:query
                                           failBlock:^(NSError *e) {
                                               if( [self isViewLoaded] )
                                                   [self receivedObjectResponse:nil];
                                           }
                                       completeBlock:^(NSDictionary *results) {
                                           if( ![self isViewLoaded] ) 
                                               return;
                                           
                                           if( results && [[results objectForKey:@"totalSize"] intValue] > 0 ) {
                                               NSMutableArray *groups = [NSMutableArray arrayWithCapacity:[[results objectForKey:@"totalSize"] intValue]];
                                               
                                               for( NSDictionary *membership in [results objectForKey:@"records"] ) {
                                                   NSString *groupId = [membership objectForKey:@"CollaborationGroupId"];
                                                   
                                                   if( [records containsObject:groupId] ) {
                                                       NSMutableDictionary *group = [NSMutableDictionary dictionaryWithDictionary:[membership objectForKey:@"CollaborationGroup"]];
                                                       [group setObject:groupId forKey:@"Id"];
                                                                                                              
                                                       [groups addObject:group];
                                                   }
                                               }
                                               
                                               [self receivedObjectResponse:groups];
                                           } else
                                               [self receivedObjectResponse:nil];
                                       }];
    } else {
        // verify we have a describe for this object on file
        [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:type
                                                        failBlock:nil
                                                    completeBlock:^(NSDictionary *desc) {     
                                                        if( ![self isViewLoaded] ) 
                                                            return;
                                                        
                                                        [SFVAsync performRetrieveWithFields:[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:type]
                                                                                    sObject:type
                                                                                        ids:records
                                                                                  failBlock:^(NSException *e) {
                                                                                      [self receivedObjectResponse:nil];
                                                                                  }
                                                                              completeBlock:^(NSDictionary *results) {
                                                                                  [self receivedObjectResponse:[results allValues]];
                                                                              }];
                                                    }];
    }
}

+ (NSString *)searchScopeForObject:(NSString *)object {
    if( [object isEqualToString:@"User"] )
        return [NSString stringWithFormat:@"%@ WHERE isactive=true and "
             "( usertype = 'Standard' or usertype = 'CSNOnly' ) ORDER BY lastname asc limit 5",
                [[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:object] componentsJoinedByString:@","]];
    else
        return [[[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:object] 
                                     componentsJoinedByString:@","] 
                                    stringByAppendingFormat:@" %@ limit 5",
                                       ( [[SFVAppCache sharedSFVAppCache] nameFieldForsObject:object] 
                                        ? [NSString stringWithFormat:@"ORDER BY %@", [[SFVAppCache sharedSFVAppCache] nameFieldForsObject:object]]
                                        : @"" )];
}

- (void) search {    
    NSString *text = [NSString stringWithString:self.searchBar.text];
    
    if( [text length] < 2 )
        return;
    
    if( searching )
        return;
    
    if( ( !searchScope || [searchScope count] == 0 ) && onlyShowChatterEnabledObjects ) {
        // Make sure to add user and group
        [searchScope setObject:[[self class] searchScopeForObject:@"User"]
                        forKey:@"User"];
        [searchScope setObject:[[self class] searchScopeForObject:@"CollaborationGroup"]
                        forKey:@"CollaborationGroup"];
        
        for( NSString *ob in [[SFVAppCache sharedSFVAppCache] allFeedEnabledSObjects] )
            if( [[SFVAppCache sharedSFVAppCache] doesGlobalObject:ob 
                                                     haveProperty:GlobalObjectIsSearchable] )
                [searchScope setObject:[[self class] searchScopeForObject:ob]
                                forKey:ob];
    }

    resultLabel.text = NSLocalizedString(@"Searching...", @"Searching...");
    searching = YES;
    resultLabel.hidden = NO;
    searchIcon.hidden = YES;
    resultTable.hidden = YES;
    objectsChecked = objectsToCheck = 0;
    
    if( searchResults )
        [searchResults removeAllObjects];
    
    [resultTable reloadData];    
    
    // Response block to be called once we have results
    SFRestArrayResponseBlock searchResultsBlock = ^(NSArray *results) {
        if( ![self isViewLoaded] ) 
            return;
        
        // Notify delegate
        if( [self.delegate respondsToSelector:@selector(objectLookupDidSearch:search:)] )
            [self.delegate objectLookupDidSearch:self search:text];
        
        // The user may have wiped or changed the search field during this search
        if( [self.searchBar.text length] == 0 ) {
            searching = NO;
            searchIcon.hidden = NO;
            resultTable.hidden = YES;
            resultLabel.hidden = YES;
            
            [resultTable reloadData];
            return;
        }
        
        // The user changed the text of the search while it was ongoing. re-search
        if( [self.searchBar.text length] >= 2 && ![self.searchBar.text isEqualToString:text] ) {
            searching = NO;
            [self search];
            return;
        }
        
        if( !results || [results count] == 0 ) {
            resultLabel.text = NSLocalizedString(@"No Results", @"No Results");
            searching = NO;
            resultLabel.hidden = NO;
        } else {
            NSMutableDictionary *tmpRecords = [NSMutableDictionary dictionary];
            NSArray *records = [SFVAsync ZKSObjectArrayToDictionaryArray:results];
            
            for( NSDictionary *ob in records ) {
                NSString *type = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[ob objectForKey:@"Id"]];
                
                if( ![tmpRecords objectForKey:type] )
                    [tmpRecords setObject:[NSMutableArray arrayWithObject:ob] forKey:type];
                else
                    [[tmpRecords objectForKey:type] addObject:ob];
            }
            
            objectsToCheck = [tmpRecords count];
            
            if( objectsToCheck > 0 ) {
                for( NSArray *records in [tmpRecords allValues] ) {
                    // If this was a global search, generally only the id is returned.
                    // So if we have more than one (plus the attribute field, so two) fields here, assume that we have the whole thing 
                    // as a custom SOSL scope must have been specified for this search
                    
                    if( [[[records objectAtIndex:0] allKeys] count] > 2 && 
                       ![[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[[records objectAtIndex:0] objectForKey:@"Id"]] isEqualToString:@"CollaborationGroup"] )
                        [self receivedObjectResponse:records];
                    else {
                        NSMutableArray *ids = [NSMutableArray arrayWithCapacity:[records count]];
                        
                        for( NSDictionary *ob in records )
                            [ids addObject:[ob objectForKey:@"Id"]];
                        
                        [self loadNamesForRecords:ids];
                    }
                }
            } else {
                resultLabel.text = NSLocalizedString(@"No Results", @"No Results");
                resultLabel.hidden = NO;
                searching = NO;
            }
        }
    };
    
    SFRestFailBlock failBlock = ^(NSError *e) {
        if( ![self isViewLoaded] )
            return;
        
        searching = NO;
        resultLabel.text = NSLocalizedString(@"No Results", @"No Results");
        resultLabel.hidden = NO;
    };
    
    // Do the SOQLs and SOSLs separately
    NSMutableDictionary *soslScopes = [NSMutableDictionary dictionary];
    
    for( NSString *object in [searchScope allKeys] )
        if( [[searchScope objectForKey:object] isEqualToString:kSOQLSearchScope] )
            [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:object
                                                               failBlock:failBlock
                                                           completeBlock:^(NSDictionary *dict) {
                                                               if( ![self isViewLoaded] ) 
                                                                   return;
                                                               
                                                               NSString *soql = [SFVAsync SOQLQueryWithFields:[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:object]
                                                                                                      sObject:object
                                                                                                        where:[NSString stringWithFormat:@"%@ LIKE '%%%@%%'",
                                                                                                               [[SFVAppCache sharedSFVAppCache] nameFieldForsObject:object],
                                                                                                               text]
                                                                                                        limit:10];
                                                               
                                                               [[SFRestAPI sharedInstance] performSOQLQuery:soql
                                                                                                  failBlock:failBlock
                                                                                              completeBlock:^(NSDictionary *results) {
                                                                                                  if( results && [results objectForKey:@"records"] )
                                                                                                      searchResultsBlock( [results objectForKey:@"records"] );
                                                                                              }];
                                                           }];
        else
            [soslScopes setObject:[searchScope objectForKey:object]
                           forKey:object];
    
    if( [soslScopes count] > 0 ) {
        if( [soslScopes count] == 1 )
            [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:[[soslScopes allKeys] objectAtIndex:0]
                                                               failBlock:failBlock
                                                           completeBlock:^(NSDictionary *dict) {
                                                               if( ![self isViewLoaded] ) 
                                                                   return;
                                                               
                                                               NSString *sosl = [SFVAsync SOSLQueryWithSearchTerm:text
                                                                                                       fieldScope:nil
                                                                                                      objectScope:[NSDictionary dictionaryWithObject:[[soslScopes allValues] objectAtIndex:0]
                                                                                                                                              forKey:[[soslScopes allKeys] objectAtIndex:0]]];
                                                               
                                                               [[SFRestAPI sharedInstance] performSOSLSearch:sosl
                                                                                                   failBlock:failBlock
                                                                                               completeBlock:searchResultsBlock];
                                                           }];
                                                               
        else {
            NSString *sosl = [SFVAsync SOSLQueryWithSearchTerm:text
                                                    fieldScope:nil
                                                   objectScope:soslScopes];
            
            [[SFRestAPI sharedInstance] performSOSLSearch:sosl
                                                failBlock:failBlock
                                            completeBlock:searchResultsBlock];
        }
    }
}

#pragma mark - View lifecycle

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
