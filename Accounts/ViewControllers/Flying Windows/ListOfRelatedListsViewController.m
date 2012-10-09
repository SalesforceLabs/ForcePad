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

#import "ListOfRelatedListsViewController.h"
#import "PRPSmartTableViewCell.h"
#import "RelatedListGridView.h"
#import "DetailViewController.h"
#import "SFVUtil.h"
#import "zkSforce.h"
#import "SFVAsync.h"
#import "SFVAppCache.h"
#import "SFRestAPI+Blocks.h"

@implementation ListOfRelatedListsViewController

@synthesize relatedLists, tableView, listRecordCounts;

static float rowHeight = 50.0f;

// Maximum number of child relationships we can subquery at once
static int maxRelationshipsInSingleQuery = 20;

int totalRelationshipQueriesExecuted;

- (id) initWithFrame:(CGRect)frame {
    if(( self = [super initWithFrame:frame] )) {
        float curY = self.navBar.frame.size.height;
                
        self.listRecordCounts = [NSMutableDictionary dictionary];
        totalRelationshipQueriesExecuted = 0;
                
        // table view
        self.tableView = [[[UITableView alloc] initWithFrame:CGRectMake( 0, curY, 
                                                                        frame.size.width, 
                                                                        frame.size.height - curY )
                                                       style:UITableViewStylePlain] autorelease];
        self.tableView.delegate = self;
        self.tableView.dataSource = self;
        self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.gif"]];
        self.tableView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        
        // Table Footer            
        UIImage *i = [UIImage imageNamed:@"tilde.png"];
        UIImageView *iv = [[[UIImageView alloc] initWithImage:i] autorelease];
        iv.alpha = 0.25f;
        [iv setFrame:CGRectMake( lroundf( ( self.tableView.frame.size.width - i.size.width ) / 2.0f ), 10, i.size.width, i.size.height )];
        
        UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, self.tableView.frame.size.width, 70 )] autorelease];
        [footerView addSubview:iv];
        self.tableView.tableFooterView = footerView;
        
        [self.view addSubview:self.tableView];
    }
        
    return self;
}

- (NSString *) nameForList:(ZKRelatedList *)list {
    if( [[self.account objectForKey:kObjectTypeKey] isEqualToString:@"Account"] 
        && [[list name] isEqualToString:@"CampaignMembers"] ) 
        return @"PersonCampaignMembers";
    
    return [list name];
}

- (void) selectAccount:(NSDictionary *)acc {
    [super selectAccount:acc];
    
    ZKDescribeLayout *layout = [[SFVUtil sharedSFVUtil] layoutForRecord:acc];
    
    self.relatedLists = [NSArray array];
    [self.listRecordCounts removeAllObjects];
    totalRelationshipQueriesExecuted = 0;
    
    [self pushNavigationBarWithTitle:NSLocalizedString(@"Related Lists", @"Related Lists")
                            animated:NO];
    
    // Apply a manual related list filter. Certain related lists are tied to sObjects that cannot be queried,
    // so we won't render them in the list.
    for( ZKRelatedList *list in [layout relatedLists] ) {
        NSDictionary *sObject = [[SFVAppCache sharedSFVAppCache] describeGlobalsObject:[list sobject]];
        
        if( !sObject )
            continue;
        
        if( [SFVUtil isEmpty:[list field]] ) {
            NSLog(@"no field for related object %@", [list sobject]);
            continue;
        }
        
        if( [[list sobject] isEqualToString:@"Attachment"] )
            continue;
        
        if( ( [[sObject objectForKey:@"queryable"] boolValue] ) ||
            ( [[NSArray arrayWithObjects:@"ActivityHistory", @"OpenActivity", nil] containsObject:[list sobject]] ) )
            self.relatedLists = [self.relatedLists arrayByAddingObject:list];
        else
            NSLog(@"Unqueryable Related List %@, not displaying in table.", [list sobject]);        
    }    
    
    [self.tableView reloadData];
    [self performSelector:@selector(loadListCounts) withObject:nil afterDelay:0.6f];
}

- (void) loadListCounts {
    if( !self.relatedLists || [self.relatedLists count] == 0 )
        return;
    
    int count = 0;
    NSMutableArray *fields = [NSMutableArray arrayWithObject:@"id"];
    
    for( int x = totalRelationshipQueriesExecuted; x < [self.relatedLists count]; x++ ) {
        if( count >= maxRelationshipsInSingleQuery )
            break;
        
        ZKRelatedList *list = [self.relatedLists objectAtIndex:x];
        
        if( [[list sobject] isEqualToString:@"ActivityHistory"] )
            [fields addObject:[NSString stringWithFormat:@"(%@)",
                               [SFVAsync SOQLQueryWithFields:[NSArray arrayWithObjects:@"id", @"createddate", nil]
                                                    sObject:@"ActivityHistories"
                                                      where:nil
                                                    groupBy:nil
                                                     having:nil
                                                    orderBy:[NSArray arrayWithObjects:@"activitydate desc", @"lastmodifieddate desc", nil]
                                                      limit:500]]];
        else if( [[list sobject] isEqualToString:@"OpenActivity"] )
            [fields addObject:[NSString stringWithFormat:@"(%@)",
                               [SFVAsync SOQLQueryWithFields:[NSArray arrayWithObjects:@"id", @"createddate", nil]
                                                    sObject:@"OpenActivities"
                                                      where:nil
                                                    groupBy:nil
                                                     having:nil
                                                    orderBy:[NSArray arrayWithObjects:@"activitydate asc", @"lastmodifieddate desc", nil]
                                                      limit:500]]];
        else 
            [fields addObject:[NSString stringWithFormat:@"(%@)",
                                 [SFVAsync SOQLQueryWithFields:[NSArray arrayWithObject:@"id"]
                                                        sObject:[self nameForList:list]
                                                          where:nil
                                                          limit:kMaxSOQLSubQueryLimit]]];
        count++;
    }
    
    totalRelationshipQueriesExecuted += count;
    
    NSString *soql = [SFVAsync SOQLQueryWithFields:fields
                                           sObject:[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[self.account objectForKey:@"Id"]]
                                             where:[NSString stringWithFormat:@"id='%@'", [self.account objectForKey:@"Id"]]
                                             limit:1];
    
    [[SFRestAPI sharedInstance] performSOQLQuery:soql
                                       failBlock:^(NSError *e) {
                                           [self.tableView reloadData];
                                           
                                           // More lists to query?
                                           if( totalRelationshipQueriesExecuted < [self.relatedLists count] )
                                               [self loadListCounts];
                                       }
                                   completeBlock:^(NSDictionary *results) {
                                       if( ![self isViewLoaded] )
                                           return;
                                       
                                       if( [[results objectForKey:@"records"] count] > 0 ) {
                                           NSDictionary *accResult = [[results objectForKey:@"records"] objectAtIndex:0];
                                           
                                           for( NSString *relationship in [accResult allKeys] ) {
                                               if( [relationship isEqualToString:@"Id"] )
                                                   continue;
                                               
                                               if( ![SFVUtil isEmpty:[accResult objectForKey:relationship]] ) {
                                                   NSArray *relatedRecords = [[accResult objectForKey:relationship] objectForKey:@"records"];
                                                   
                                                   if( relatedRecords && [relatedRecords count] > 0 ) {                                                       
                                                       if( [relationship isEqualToString:@"ActivityHistories"] || [relationship isEqualToString:@"OpenActivities"] )
                                                           relatedRecords = [SFVUtil filterRecords:relatedRecords 
                                                                                         dateField:@"CreatedDate" 
                                                                                          withDate:[NSDate dateWithTimeIntervalSinceNow:-(60 * 60 * 24 * 365)] 
                                                                                      createdAfter:YES];
                                                       
                                                       int num = [relatedRecords count];
                                                       
                                                       BOOL mightHaveMore = [relationship isEqualToString:@"OpenActivities"] || [relationship isEqualToString:@"ActivityHistories"] 
                                                                                ? num >= 500 
                                                                                : num >= 200;
                                                       
                                                       if( num > 0 )
                                                           [self.listRecordCounts setObject:[NSString stringWithFormat:@"%i%@%@*", 
                                                                                              num,
                                                                                              ( mightHaveMore ? @"+ " : @" " ),
                                                                                              ( num > 1 ? NSLocalizedString(@"Records", nil) : NSLocalizedString(@"Record", nil) )]
                                                                                     forKey:relationship];
                                                       else
                                                           [self.listRecordCounts setObject:NSLocalizedString(@"No Records", @"No Records") forKey:relationship];
                                                   }
                                               } else
                                                   [self.listRecordCounts setObject:NSLocalizedString(@"No Records", @"No Records") forKey:relationship];
                                           }
                                       }
                                        
                                       [self.tableView reloadData];
                                                                              
                                       // More lists to query?
                                       if( totalRelationshipQueriesExecuted < [self.relatedLists count] )
                                           [self loadListCounts];
                                   }];
}

- (void)dealloc {
    self.tableView = nil;
    self.relatedLists = nil;
    self.listRecordCounts = nil;
    [super dealloc];
}

#pragma mark - table view delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.relatedLists count];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return rowHeight;
}

- (void)tableView:(UITableView *)tv willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    ZKRelatedList *list = [self.relatedLists objectAtIndex:indexPath.row];
    
    NSString *imgUrl = [[SFVAppCache sharedSFVAppCache] logoURLForSObjectTab:[list sobject]];
    
    if( imgUrl )
        [[SFVUtil sharedSFVUtil] loadImageFromURL:imgUrl
                                            cache:YES
                                     maxDimension:tv.rowHeight
                                    completeBlock:^(UIImage *img, BOOL wasLoadedFromCache) {
                                        if( ![self isViewLoaded] )
                                            return;
                                        
                                        if( !wasLoadedFromCache )
                                            [tv reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                                      withRowAnimation:UITableViewRowAnimationFade];
                                    }];
}

- (UITableViewCell *)tableView:(UITableView *)tv cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PRPSmartTableViewCell *cell = [PRPSmartTableViewCell cellForTableView:tv];
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    
    ZKRelatedList *list = [self.relatedLists objectAtIndex:indexPath.row];
    
    cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    cell.textLabel.text = [list label]; 
    cell.textLabel.textColor = AppLinkColor;
    cell.detailTextLabel.font = [UIFont systemFontOfSize:14];
    cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
    cell.imageView.image = nil;

    if( [self.listRecordCounts objectForKey:[self nameForList:list]] ) {
        NSString *str = [self.listRecordCounts objectForKey:[self nameForList:list]];
        
        if( [str hasSuffix:@"*"] ) {
            cell.detailTextLabel.font = [UIFont boldSystemFontOfSize:14];
            cell.detailTextLabel.text = [str substringWithRange:NSMakeRange(0, [str length] - 1)];
        } else        
            cell.detailTextLabel.text = str;
    } else
        cell.detailTextLabel.text = NSLocalizedString(@"Loading...", nil);
        
    cell.imageView.image = [[SFVAppCache sharedSFVAppCache] imageForSObjectFromCache:[list sobject]];
    
    return cell;
}

- (void)tableView:(UITableView *)tv didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    ZKRelatedList *list = [self.relatedLists objectAtIndex:indexPath.row];
        
    [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:NO];
    
    // Array, where object 0 is this record and object 1 is the name of the related list to show.
    [self.detailViewController addFlyingWindow:FlyingWindowRelatedListGrid 
                                       withArg:[NSArray arrayWithObjects:self.account, [list sobject], nil]];
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [self flyingWindowDidTap:nil];
}

#pragma mark - View lifecycle

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
	return YES;
}

@end
