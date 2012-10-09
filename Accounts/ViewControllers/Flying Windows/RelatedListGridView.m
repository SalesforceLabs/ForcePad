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

#import "RelatedListGridView.h"
#import "AccountGridCell.h"
#import "DSActivityView.h"
#import "SFVUtil.h"
#import "DetailViewController.h"
#import "SFVAsync.h"
#import "SFVAppCache.h"
#import "SFRestAPI+SFVAdditions.h"
#import "CreateRecordButton.h"

@interface RelatedListGridView (Private)
- (NSUInteger) numberOfColumns;
- (ZKRelatedListColumn *) columnAtIndex:(NSInteger)index;
- (BOOL) isFieldValidForList:(NSString *)field;
- (NSString *) sObjectNameForRelatedList:(enum sObjectNames)nameType;
- (NSUInteger) limitAmountForRelatedList;
- (NSString *) relatedFieldForRelatedList;
- (NSArray *) fieldsToQuery;
- (NSArray *) orderingClauseForRelatedList;

+ (NSDictionary *) relatedRecordOnRecord:(NSDictionary *)record field:(NSString *)field;

- (NSString *) fieldForColumn:(ZKRelatedListColumn *)column;
@end

@implementation RelatedListGridView

@synthesize relatedList, gridView, records, noResultsLabel, sortColumn, sortAscending;

static float cellHeight = 65.0f;
BOOL canViewRecordDetail = NO;
BOOL canSortGridColumns = NO;

- (id) initWithRelatedList:(ZKRelatedList *)list inFrame:(CGRect)frame {
    if(( self = [super initWithFrame:frame] )) {                
        self.relatedList = list;        
        self.records = [NSMutableArray array];
        
        canViewRecordDetail = [[SFVAppCache sharedSFVAppCache] doesGlobalObject:[self sObjectNameForRelatedList:sObjectForDescribe]
                                                                   haveProperty:GlobalObjectIsLayoutable];
        canSortGridColumns = ![[self sObjectNameForRelatedList:sObjectForDescribe] isEqualToString:@"Task"];
        
        self.gridView = [[[AQGridView alloc] initWithFrame:CGRectMake( 0, self.navBar.frame.size.height, 
                                                                      frame.size.width, 
                                                                      frame.size.height - self.navBar.frame.size.height )] autorelease];
        self.gridView.delegate = self;
        self.gridView.dataSource = self;
        self.gridView.separatorStyle = AQGridViewCellSeparatorStyleSingleLine;
        self.gridView.separatorColor = [UIColor lightGrayColor];
        self.gridView.scrollEnabled = YES;
        self.gridView.resizesCellWidthToFit = NO;
        //self.gridView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleHeight;
        self.gridView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.gif"]];
        
        [self.view addSubview:self.gridView];
                
        self.noResultsLabel = [[[UILabel alloc] initWithFrame:CGRectMake( 0, lroundf( ( frame.size.height - self.navBar.frame.size.height - 30 ) / 2.0f), 
                                                                         frame.size.width, 30 )] autorelease];
        noResultsLabel.text = NSLocalizedString(@"No Results", @"No Results");
        noResultsLabel.font = [UIFont boldSystemFontOfSize:20];
        noResultsLabel.textColor = [UIColor lightGrayColor];
        noResultsLabel.textAlignment = UITextAlignmentCenter;
        noResultsLabel.backgroundColor = [UIColor clearColor];
        noResultsLabel.hidden = YES;
        
        [self.view addSubview:self.noResultsLabel];        
    }
    
    return self;
}

- (void)dealloc {
    gridView.delegate = nil;
    gridView.dataSource = nil;
    
    [records release];
    [relatedList release];
    [gridView release];
    [noResultsLabel release];
    [sortColumn release];
    [super dealloc];
}

- (void) setFrame:(CGRect)frame {
    [super setFrame:frame];
    
    [self.gridView setFrame:CGRectMake(0, CGRectGetMaxY(self.navBar.frame), CGRectGetWidth(frame), CGRectGetHeight(frame) - CGRectGetMaxY(self.navBar.frame))];
            
    [self.gridView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated {
    [DSBezelActivityView removeViewAnimated:animated];
    [super viewWillDisappear:animated];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    self.gridView = nil;
    self.noResultsLabel = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark - loading records
- (void) selectAccount:(NSDictionary *)acc {
    [super selectAccount:acc];
    
    // Describe our related object and load records when complete
    [DSBezelActivityView newActivityViewForView:self.view];

    [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:[self sObjectNameForRelatedList:sObjectForDescribe]
                                                    failBlock:nil
                                                completeBlock:^(NSDictionary *dict) {
                                                    if( ![self isViewLoaded] ) 
                                                        return;
                                                    
                                                    // Just do events too
                                                    if( [[self sObjectNameForRelatedList:sObjectForDescribe] isEqualToString:@"Task"] )
                                                        [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:@"Event"
                                                                                                           failBlock:nil
                                                                                                       completeBlock:^(NSDictionary *dict) {
                                                                                                           [self loadRecords];
                                                                                                       }];
                                                    else
                                                        [self performSelector:@selector(loadRecords) withObject:nil afterDelay:0.8f];
                                                }];
}

// Given an array of dictionary results, process all the text values and formatting for every field
// so we don't have to do this at cell construction time
- (void) processRecords:(NSArray *)arr {
    [[SFAnalytics sharedInstance] tagEventOfType:SFVUserViewedRelatedList
                                      attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [self sObjectNameForRelatedList:sObjectForDescribe], @"Object",
                                                  [SFAnalytics bucketStringForNumber:[NSNumber numberWithInt:[arr count]]
                                                                          bucketSize:kBucketDefaultSize], @"Record Count",
                                                  nil]];    
    
    NSMutableArray *newRecords = [NSMutableArray arrayWithCapacity:[arr count]];
    
    for( NSDictionary *record in arr ) {
        NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:record];
        
        for( ZKRelatedListColumn *col in [self.relatedList columns] ) {
            NSString *fieldKeyPath = [self fieldForColumn:col];
            
            if( [fieldKeyPath rangeOfString:@"."].location != NSNotFound ) {
                NSArray *bits = [fieldKeyPath componentsSeparatedByString:@"."];
                
                if( ![SFVUtil isEmpty:[dict objectForKey:[bits objectAtIndex:0]]] )
                    [[dict objectForKey:[bits objectAtIndex:0]] setObject:[[SFVUtil sharedSFVUtil] textValueForField:fieldKeyPath
                                                                                                      withDictionary:record]
                                                                   forKey:[bits objectAtIndex:1]];
            } else
                [dict setObject:[[SFVUtil sharedSFVUtil] textValueForField:fieldKeyPath
                                                            withDictionary:record]
                         forKey:fieldKeyPath];
            
        }
        
        [newRecords addObject:dict];
    }
    
    [DSBezelActivityView removeViewAnimated:YES];
    [self.records addObjectsFromArray:newRecords];
    [self.gridView reloadData];
    self.gridView.hidden = NO;
}

- (void) loadRecords {  
    NSString *query = [SFVAsync SOQLQueryWithFields:[self fieldsToQuery] 
                                            sObject:[self sObjectNameForRelatedList:sObjectForQuery]
                                              where:[NSString stringWithFormat:@"%@ = '%@'",
                                                        [self relatedFieldForRelatedList],
                                                         ( ![SFVUtil isEmpty:[self.account objectForKey:@"PersonContactId"]] && [[self sObjectNameForRelatedList:sObjectForQuery] isEqualToString:@"CampaignMember"] ? 
                                                          [self.account objectForKey:@"PersonContactId"] : [self.account objectForKey:@"Id"] )]
                                            groupBy:nil
                                             having:nil
                                            orderBy:[self orderingClauseForRelatedList]
                                              limit:[self limitAmountForRelatedList]];    
        
    [self.records removeAllObjects];
    
    self.gridView.hidden = YES;
    self.noResultsLabel.hidden = YES;
    
    [self pushNavigationBarWithTitle:[NSString stringWithFormat:@"%@ %@...",
                                                NSLocalizedString(@"Loading",nil),
                                                [self.relatedList label]]
                            animated:NO];
    
    [[SFRestAPI sharedInstance] performSOQLQuery:query
                                       failBlock:^(NSError *e) {
                                           [DSBezelActivityView removeViewAnimated:NO];
                                           
                                           if( ![self isViewLoaded] ) 
                                               return;
                                           
                                           [self pushNavigationBarWithTitle:[NSString stringWithFormat:@"%@ (0) — %@",
                                                                             [self.relatedList label],
                                                                             [[SFVAppCache sharedSFVAppCache] nameForSObject:self.account]]
                                                                   animated:NO];
                                           
                                           self.noResultsLabel.hidden = NO;
                                           
                                       }
                                   completeBlock:^(NSDictionary *results) {
                                       if( ![self isViewLoaded] ) 
                                           return;
                                       
                                       // First, we add the proper new buttons to the toolbar
                                       
                                       // Nested dictionary with the related object's name field and name value
                                       NSDictionary *thisRecord = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                   [[SFVAppCache sharedSFVAppCache] nameForSObject:self.account], [[SFVAppCache sharedSFVAppCache] nameFieldForsObject:[self.account objectForKey:kObjectTypeKey]],
                                                                   [self.account objectForKey:@"Id"], @"Id",
                                                                   nil];
                                       
                                       // Dictionary for this user
                                       NSDictionary *thisUser = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [[SFVUtil sharedSFVUtil] currentUserName], @"Name",
                                                                 [[SFVUtil sharedSFVUtil] currentUserId], @"Id",
                                                                 nil];
                                       
                                       UIToolbar *rightToolbar = [[UIToolbar alloc] initWithFrame:CGRectZero];                                       
                                       rightToolbar.tintColor = self.navBar.tintColor;
                                       rightToolbar.opaque = YES;
                                       
                                       UIBarButtonItem *spacer = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                                                                target:nil
                                                                                                                action:nil] autorelease];
                                       
                                       NSString *relatedField = ( [[NSArray arrayWithObjects:@"Lead", @"Contact", nil] containsObject:
                                                                   [self.account objectForKey:kObjectTypeKey]]
                                                                 ? @"Who"
                                                                 : @"What" );
                                       
                                       // New Task, New Event buttons
                                       if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ) {
                                           NSMutableArray *items = [NSMutableArray arrayWithObject:spacer];
                                           
                                           // New task
                                           NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [self.account objectForKey:@"Id"], [relatedField stringByAppendingString:@"Id"],
                                                                 thisRecord, relatedField,
                                                                 thisUser, @"Owner",
                                                                 [[SFVUtil sharedSFVUtil] currentUserId], @"OwnerId",
                                                                 nil];
                                           
                                           CreateRecordButton *button = [CreateRecordButton buttonForObject:@"Task"
                                                                                                       text:NSLocalizedString(@"New Task", @"New Task")
                                                                                                     fields:dict];
                                           button.detailViewController = self.detailViewController;
                                           
                                           [items addObject:button];
                                           
                                           // New Event
                                           dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [self.account objectForKey:@"Id"], [relatedField stringByAppendingString:@"Id"],
                                                                 thisRecord, relatedField,
                                                                 nil];
                                           
                                           button = [CreateRecordButton buttonForObject:@"Event"
                                                                                   text:NSLocalizedString(@"New Event", @"New Event")
                                                                                 fields:dict];
                                           button.detailViewController = self.detailViewController;
                                           
                                           if( [items count] > 1 )
                                               [items addObject:spacer];
                                           
                                           [items addObject:button];
                                                                                      
                                           [rightToolbar setItems:items animated:NO];
                                           [rightToolbar setFrame:CGRectMake( 0, 0, 200, CGRectGetHeight(self.navBar.frame) )];
                                       } else if( [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] ) {
                                           // Log a call
                                           NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [self.account objectForKey:@"Id"], [relatedField stringByAppendingString:@"Id"],
                                                                 thisRecord, relatedField,
                                                                 thisUser, @"Owner",
                                                                 [[SFVUtil sharedSFVUtil] currentUserId], @"OwnerId",
                                                                 nil];
                                           CreateRecordButton *button = [CreateRecordButton buttonForObject:@"Task"
                                                                                                       text:NSLocalizedString(@"Log a Call", @"Log a Call")
                                                                                                     fields:dict];
                                           button.detailViewController = self.detailViewController;
                                           
                                           [rightToolbar setItems:[NSArray arrayWithObjects:spacer, button, nil] animated:NO];
                                           [rightToolbar setFrame:CGRectMake(0, 0, 120, CGRectGetHeight(self.navBar.frame))];
                                       } else if( [CreateRecordButton objectCanBeCreated:[self.relatedList sobject]] ) {
                                           NSDictionary *dict = [NSDictionary dictionaryWithObjectsAndKeys:
                                                                 [self.account objectForKey:@"Id"], [self.relatedList field],
                                                                 thisRecord, [[SFVAppCache sharedSFVAppCache] field:[self.relatedList field]
                                                                                                           onObject:[self.relatedList sobject]
                                                                                                     stringProperty:FieldRelationshipName],
                                                                 nil];
                                           CreateRecordButton *button = [CreateRecordButton buttonForObject:[self.relatedList sobject]
                                                                                                       text:nil
                                                                                                     fields:dict];
                                           button.detailViewController = self.detailViewController;
                                           
                                           [rightToolbar setItems:[NSArray arrayWithObjects:spacer, button, nil] animated:NO];
                                           [rightToolbar setFrame:CGRectMake(0, 0, 120, CGRectGetHeight(self.navBar.frame))];
                                       }
                                       
                                       UIBarButtonItem *rightItem = [[[UIBarButtonItem alloc] initWithCustomView:rightToolbar] autorelease];
                                       [rightToolbar release];
                                       
                                       NSArray *sObjects = nil;
                                       if( results && [[results objectForKey:@"records"] count] > 0 ) {
                                           if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
                                              [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] ) {
                                               NSDictionary *ob = [[results objectForKey:@"records"] objectAtIndex:0];
                                               
                                               if( ob && ![SFVUtil isEmpty:[ob objectForKey:[self sObjectNameForRelatedList:sObjectNormal]]] )
                                                   sObjects = [ob valueForKeyPath:[NSString stringWithFormat:@"%@.records", [self sObjectNameForRelatedList:sObjectNormal]]];
                                                   
                                               if( sObjects && [sObjects count] > 0 )
                                                   sObjects = [SFVUtil filterRecords:sObjects
                                                                           dateField:@"CreatedDate"
                                                                            withDate:[NSDate dateWithTimeIntervalSinceNow:-( 60 * 60 * 24 * 365 )]
                                                                        createdAfter:YES];
                                           } else
                                               sObjects = [results objectForKey:@"records"];
                                           
                                           if( sObjects && [sObjects count] > 0 ) {                                               
                                               for( ZKRelatedListColumn *col in [self.relatedList columns] ) {
                                                   NSString *field = [self fieldForColumn:col];
                                               
                                                   if( [field rangeOfString:@"."].location != NSNotFound ) {
                                                       NSArray *bits = [field componentsSeparatedByString:@"."];
                                                                                                          
                                                       if( [[SFVAppCache sharedSFVAppCache] doesGlobalObject:[bits objectAtIndex:0] 
                                                                                                haveProperty:GlobalObjectIsLayoutable] ) {
                                                           canViewRecordDetail = YES;
                                                           
                                                           [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:[bits objectAtIndex:0]
                                                                                                           failBlock:nil
                                                                                                       completeBlock:^(NSDictionary *response) {
                                                                                                           if( ![self isViewLoaded] )
                                                                                                               return;
                                                                                                           
                                                                                                           [self pushNavigationBarWithTitle:[NSString stringWithFormat:@"%@ (%i) — %@",
                                                                                                                                             [self.relatedList label],
                                                                                                                                             [sObjects count],
                                                                                                                                             [[SFVAppCache sharedSFVAppCache] nameForSObject:self.account]]
                                                                                                                                   leftItem:nil
                                                                                                                                  rightItem:rightItem
                                                                                                                                   animated:NO];
                                                                                                           
                                                                                                           [self processRecords:sObjects]; 
                                                                                                       }];
                                                           
                                                           return;
                                                       }
                                                   }
                                               }
                                               
                                               [self processRecords:sObjects];
                                           } else {
                                               [DSBezelActivityView removeViewAnimated:YES];
                                               self.noResultsLabel.hidden = NO;
                                           }
                                       } else {
                                           [DSBezelActivityView removeViewAnimated:YES];
                                           self.noResultsLabel.hidden = NO;
                                           
                                           [[SFAnalytics sharedInstance] tagEventOfType:SFVUserViewedRelatedList
                                                                             attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                                         [self sObjectNameForRelatedList:sObjectForDescribe], @"Object",
                                                                                         [NSNumber numberWithInt:0], @"Record Count",
                                                                                         nil]];
                                       }
                                       
                                       [self pushNavigationBarWithTitle:[NSString stringWithFormat:@"%@ (%i) — %@",
                                                                         [self.relatedList label],
                                                                         [sObjects count],
                                                                         [[SFVAppCache sharedSFVAppCache] nameForSObject:self.account]]
                                                               leftItem:nil
                                                              rightItem:rightItem
                                                               animated:NO];
                                   }];
}
#pragma mark - grid view delegate

- (NSUInteger) numberOfItemsInGridView:(AQGridView *) aGridView {
    return ( 1 + [self.records count] ) * [self numberOfColumns];
}

- (CGSize) portraitGridCellSizeForGridView:(AQGridView *) aGridView {
    return CGSizeMake( floorf( self.gridView.frame.size.width / [self numberOfColumns] ) - 1,
                      cellHeight );
}

- (AQGridViewCell *) gridView:(AQGridView *)aGridView cellForItemAtIndex:(NSUInteger)index {    
    AccountGridCell *cell = [AccountGridCell cellForGridView:aGridView];
    
    cell.selectionStyle = AQGridViewCellSelectionStyleNone;
    cell.gridLabel.numberOfLines = 3;
    cell.gridLabel.text = @"";
    
    NSUInteger colCount = [self numberOfColumns];
    
    int recordRow = index / colCount;
    int recordCol = index % colCount;
        
    ZKRelatedListColumn *col = [self columnAtIndex:recordCol];
    
    // header row
    if( recordRow == 0 ) {
        NSString *gridText = [col label];
        
        // Is this column being sorted? Indicate with an arrow.
        if( self.sortColumn && [self.sortColumn isEqualToString:[self fieldForColumn:col]] )
            gridText = [gridText stringByAppendingString:( self.sortAscending ? UpArrowCharacter : DownArrowCharacter )];
        
        cell.gridLabel.text = gridText;
        cell.gridLabel.textColor = ( canSortGridColumns ? AppLinkColor : [UIColor darkTextColor] );
        cell.gridLabel.textAlignment = UITextAlignmentCenter;
        [cell.gridLabel setFont:[UIFont boldSystemFontOfSize:15]];
        cell.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"gridGradient.png"]];
    } else {
        NSDictionary *record = [self.records objectAtIndex:( recordRow - 1 )];
        NSString *field = [self fieldForColumn:col];
        
        if( [field rangeOfString:@"."].location != NSNotFound ) {
            // Use the relationship name for the bit before the field
            NSArray *bits = [field componentsSeparatedByString:@"."];
            NSString *relationshipName = [[SFVAppCache sharedSFVAppCache] field:[bits objectAtIndex:0]
                                                                       onObject:[self sObjectNameForRelatedList:sObjectNormal]
                                                                 stringProperty:FieldRelationshipName];
            
            if( [SFVUtil isEmpty:relationshipName] )
                relationshipName = [bits objectAtIndex:0];
            
            NSString *relationshipPath = [NSString stringWithFormat:@"%@.%@", 
                                          relationshipName, 
                                          [bits objectAtIndex:1]];
            
            cell.gridLabel.text = [[SFVUtil sharedSFVUtil] textValueForField:relationshipPath withDictionary:record];
        } else if( ![SFVUtil isEmpty:[record objectForKey:field]] )
            cell.gridLabel.text = [record objectForKey:field];
                
        if( [field isEqualToString:@"CreatedBy.Name"] )
            cell.gridLabel.text = [cell.gridLabel.text stringByAppendingFormat:@"\n%@",
                                     [[SFVUtil sharedSFVUtil] textValueForField:@"CreatedDate" withDictionary:record]];
        
        if( [field isEqualToString:@"LastModifiedBy.Name"] )
            cell.gridLabel.text = [cell.gridLabel.text stringByAppendingFormat:@"\n%@",
                                     [[SFVUtil sharedSFVUtil] textValueForField:@"LastModifiedDate" withDictionary:record]];
                        
        if( canViewRecordDetail && recordCol == 0 ) {
            cell.gridLabel.textColor = AppLinkColor;
            [cell.gridLabel setFont:[UIFont boldSystemFontOfSize:15]];
        } else {
            cell.gridLabel.textColor = [UIColor darkGrayColor];
            [cell.gridLabel setFont:[UIFont systemFontOfSize:14]];
        }
        
        cell.gridLabel.textAlignment = UITextAlignmentCenter;
        cell.backgroundColor = [UIColor clearColor];
    }
    
    CGSize s = [self portraitGridCellSizeForGridView:aGridView];
    [cell setFrame:CGRectMake(0, 0, s.width, s.height)];
    
    [cell.gridLabel setFrame:CGRectMake( 3, 3, s.width - 6, s.height - 6 )];
        
    return cell;
}

- (void) gridView:(AQGridView *)gv didSelectItemAtIndex:(NSUInteger)index {  
    NSUInteger colCount = [self numberOfColumns];
    
    int recordRow = index / colCount;
    int recordCol = index % colCount;
    
    [gv deselectItemAtIndex:index animated:NO];
    
    ZKRelatedListColumn *col = [self columnAtIndex:recordCol];
    
    if( recordRow > [self.records count] )
        return;
    
    if( recordRow == 0 ) {     
        // Activity History and Open Activities can't be sorted
        if( !canSortGridColumns )
            return;
        
        // Did we select a new column? default to descending
        if( ![self.sortColumn isEqualToString:[self fieldForColumn:col]] ) {
            self.sortColumn = [self fieldForColumn:col];
            self.sortAscending = NO;
        } else
            self.sortAscending = !self.sortAscending;
                
        [DSBezelActivityView newActivityViewForView:self.view];
        [self loadRecords];
    } else if( recordCol == 0 ) {
        NSDictionary *record = [self.records objectAtIndex:( recordRow - 1 )];
        NSDictionary *related = [[self class] relatedRecordOnRecord:record field:[self fieldForColumn:col]];
                
        if( canViewRecordDetail ) {
            NSString *type = [related valueForKeyPath:@"attributes.type"];
                        
            [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:NO];
            [self.detailViewController addFlyingWindow:FlyingWindowRecordOverview 
                                               withArg:( [[SFVAppCache sharedSFVAppCache] doesGlobalObject:type 
                                                                                              haveProperty:GlobalObjectIsLayoutable] ? related : record)];  
        } else
            NSLog(@"invalid sObject for layout/query: %@", [self sObjectNameForRelatedList:sObjectNormal]);
    }
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [self flyingWindowDidTap:nil];
}

#pragma mark - sobject/soql helpers

- (NSString *) sObjectNameForRelatedList:(enum sObjectNames)nameType {
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ) {
        if( nameType == sObjectForQuery )
            return [self.account objectForKey:kObjectTypeKey];
        else if( nameType == sObjectForDescribe )
            return @"Task";
        else
            return @"OpenActivities";
    } else if( [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] ) {
        if( nameType == sObjectForQuery )
            return [self.account objectForKey:kObjectTypeKey];
        else if( nameType == sObjectForDescribe )
            return @"Task";
        else
            return @"ActivityHistories";
    }
    
    return [self.relatedList sobject];
}

- (NSArray *) orderingClauseForRelatedList {    
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
       [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        return nil;
    
    NSMutableArray *ret = [NSMutableArray array];
    
    // If there's a user-selected sort, use that one first
    if( self.sortColumn )
        return [NSArray arrayWithObject:[NSString stringWithFormat:@"%@ %@",
                self.sortColumn,
                ( self.sortAscending ? @"asc" : @"desc" )]];
    
    if( ![self.relatedList sort] || [[self.relatedList sort] count] == 0 )
        return nil;
    
    for( int x = 0; x < [[self.relatedList sort] count]; x++ ) {
        ZKRelatedListSort *sort = [[self.relatedList sort] objectAtIndex:x];
        
        if( x == 0 ) {
            self.sortColumn = [sort column];// [[self class] fieldForColumn:[sort column]];
            self.sortAscending = [sort ascending];
        }
        
        [ret addObject:[NSString stringWithFormat:@"%@ %@",
         [sort column],
         ( [sort ascending] ? @"asc" : @"desc" )]];
    }
    
    return ret;
}

- (NSUInteger) limitAmountForRelatedList {
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
       [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        return 1;
    
    return 999;
}

- (NSArray *) fieldsToQuery {
    NSMutableSet *fields = [NSMutableSet set];
    
    for( int i = 0; i < [self numberOfColumns]; i++ ) {
        NSString *colName = [self fieldForColumn:[self columnAtIndex:i]];

        if( ![self isFieldValidForList:colName] )
            continue;
        
        if( [colName isEqualToString:@"Milestone.MilestoneType.Name"] ) {
            [fields addObject:@"MilestoneType.Name"];
            continue;
        }
        
        if( [[[SFVAppCache sharedSFVAppCache] field:colName
                                          onObject:[self sObjectNameForRelatedList:sObjectNormal]
                                    stringProperty:FieldType] isEqualToString:@"currency"]
            && [[SFVAppCache sharedSFVAppCache] isMultiCurrencyEnabled] ) {
            [fields addObject:@"CurrencyIsoCode"];
        }
                
        if( [colName rangeOfString:@"."].location != NSNotFound ) {
            // Use the relationship name for the bit before the field
            NSArray *bits = [colName componentsSeparatedByString:@"."];
            NSString *relationshipName = [[SFVAppCache sharedSFVAppCache] field:[bits objectAtIndex:0]
                                                                       onObject:[self sObjectNameForRelatedList:sObjectNormal]
                                                                 stringProperty:FieldRelationshipName];
            
            if( [SFVUtil isEmpty:relationshipName] )
                relationshipName = [bits objectAtIndex:0];
                                    
            // silly hack to fix for contact/lead related lists
            if( [[NSArray arrayWithObjects:@"Contact", @"Lead", nil] containsObject:[self.account objectForKey:kObjectTypeKey]] )
                relationshipName = @"Who";
            else {
                [fields addObject:[NSString stringWithFormat:@"%@.Id",
                                   relationshipName]];
                
                [fields addObject:[NSString stringWithFormat:@"%@.%@",
                                   relationshipName,
                                   [[bits objectsAtIndexes:
                                     [NSIndexSet indexSetWithIndexesInRange:NSMakeRange(1, [bits count] - 1)]] 
                                    componentsJoinedByString:@"."]]];
            }
            
            continue;
        }
        
        [fields addObject:colName];
    }   
    
    [fields addObject:@"Id"];
    [fields addObject:@"CreatedDate"];
    
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
       [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        [fields addObject:@"IsTask"];
    
    if( [fields containsObject:@"LastModifiedBy.Name"] )
        [fields addObject:@"LastModifiedDate"];
    
    if( [[SFVAppCache sharedSFVAppCache] doesObject:[self sObjectNameForRelatedList:sObjectNormal] 
                                       haveProperty:ObjectIsRecordTypeEnabled] )
        [fields addObject:kRecordTypeIdField];
    
    // Special handling for openactivity and activityhistory, which require a subquery
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] )
        return [NSArray arrayWithObject:[NSString stringWithFormat:@"(%@)",
                                         [SFVAsync SOQLQueryWithFields:[fields allObjects]
                                                               sObject:@"OpenActivities"
                                                                 where:nil
                                                               groupBy:nil
                                                                having:nil
                                                               orderBy:[NSArray arrayWithObjects:@"activitydate asc", @"lastmodifieddate desc", nil]
                                                                 limit:500]]];
    else if( [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        return [NSArray arrayWithObject:[NSString stringWithFormat:@"(%@)",
                                         [SFVAsync SOQLQueryWithFields:[fields allObjects]
                                                               sObject:@"ActivityHistories"
                                                                 where:nil
                                                               groupBy:nil
                                                                having:nil
                                                               orderBy:[NSArray arrayWithObjects:@"activitydate desc", @"lastmodifieddate desc", nil]
                                                                 limit:500]]];
    
    return [fields allObjects];
}

- (NSString *) relatedFieldForRelatedList {
    if( [[self.relatedList sobject] isEqualToString:@"OpenActivity"] ||
       [[self.relatedList sobject] isEqualToString:@"ActivityHistory"] )
        return @"Id";
    
    if( [[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[self.account objectForKey:@"Id"]] isEqualToString:@"Account"] &&
       [[self.relatedList name] isEqualToString:@"CampaignMembers"] )
        return @"ContactId";
    
    return [self.relatedList field];
}

+ (NSDictionary *) relatedRecordOnRecord:(NSDictionary *)record field:(NSString *)field {    
    if( !field )
        return record;
    
    if( [field rangeOfString:@"."].location != NSNotFound ) {
        NSArray *bits = [field componentsSeparatedByString:@"."];
        
        id related = [record objectForKey:[bits objectAtIndex:0]];
                
        if( related && [related isKindOfClass:[NSDictionary class]] )
            return related;
    }
    
    return record;
}

- (BOOL)isFieldValidForList:(NSString *)field {
    // I remain unsure why certain S2S fields appear unqueryable, or
    // why some fields reported by ZKRelatedListColumn do not exist
    if( [field isEqualToString:@"ConnectionName"] )
        return NO;
    
    // Special handling for AccountPartner and its curious custom field situation
    if( [[self sObjectNameForRelatedList:sObjectNormal] isEqualToString:@"AccountPartner"] && [field hasSuffix:@"__c"] )
        return NO;
    
    return YES;
}

- (NSUInteger)numberOfColumns {
    NSUInteger res = 0;
    
    for( ZKRelatedListColumn *col in [self.relatedList columns] )
        if( [self isFieldValidForList:[self fieldForColumn:col]] )
            res++;
    
    return res;
}

- (ZKRelatedListColumn *)columnAtIndex:(NSInteger)index {
    for( ZKRelatedListColumn *col in [self.relatedList columns] ) {
        if( [self isFieldValidForList:[self fieldForColumn:col]] )
            index--;
        
        if( index < 0 )
            return col;
    }
    
    return nil;
}

- (NSString *) fieldForColumn:(ZKRelatedListColumn *)col {   
    if( [[col name] hasPrefix:@"toLabel("] ) {
        NSArray *bits = [[col field] componentsSeparatedByString:@"."];
        
        if( [bits count] > 1 &&
            ( [[bits objectAtIndex:0] isEqualToString:[self sObjectNameForRelatedList:sObjectForQuery]] ||
              [[bits objectAtIndex:0] isEqualToString:@"ActivityHistory"] ||
              [[bits objectAtIndex:0] isEqualToString:@"OpenActivity"] ||
              [[bits objectAtIndex:0] isEqualToString:@"Partner"] ) )
            return [bits objectAtIndex:1];
        
        return [col field];
    }
    
    if( [[col field] isEqualToString:@"Milestone.MilestoneType.Name"] )
        return @"MilestoneType.Name";
    
    return [col name];
}

@end
