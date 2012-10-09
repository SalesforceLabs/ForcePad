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

#import "ChatterPostController.h"
#import "SFVUtil.h"
#import "DSActivityView.h"
#import "SFVAsync.h"
#import "SlideInView.h"
#import "SFRestAPI+Blocks.h"
#import "SFVAppCache.h"

@implementation ChatterPostController

@synthesize postButton, postTable, postDictionary, searchPopover, delegate;

static CGFloat kSuccessTimer = 1.5f;

#pragma mark - setup

- (id) initWithPostDictionary:(NSDictionary *)dict {
    if(( self = [super init] )) {
        self.title = NSLocalizedString(@"Share on Chatter", @"Share on Chatter");
        self.contentSizeForViewInPopover = CGSizeMake( 420, 44 * ( PostTableNumRows + 2 ) );
        self.view.backgroundColor = [UIColor whiteColor];
        
        self.postDictionary = [[[NSMutableDictionary alloc] initWithDictionary:dict] autorelease];
        
        // default to ourselves if no explicit parent specified
        if( [SFVUtil isEmpty:[postDictionary objectForKey:kParentField]] ) {
            [postDictionary setObject:@"User" forKey:kParentType];
            [postDictionary setObject:[[SFVUtil sharedSFVUtil] currentUserId] forKey:kParentField];
            [postDictionary setObject:[[SFVUtil sharedSFVUtil] currentUserName] forKey:kParentName];
        }
        
        self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                                               target:self
                                                                                               action:@selector(cancel)] autorelease];
        
        self.postButton = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Post", @"Posting to chatter")
                                                                style:UIBarButtonItemStyleDone
                                                               target:self 
                                                               action:@selector(submitPost)] autorelease];
        
        self.navigationItem.rightBarButtonItem = self.postButton;
        
        self.postButton.enabled = [self canSubmitPost];
        
        self.postTable = [[[UITableView alloc] initWithFrame:CGRectMake( 0, 0, self.contentSizeForViewInPopover.width, self.contentSizeForViewInPopover.height )
                                                       style:UITableViewStylePlain] autorelease];
        self.postTable.dataSource = self;
        self.postTable.delegate = self;
                
        [self.view addSubview:self.postTable];
    }
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(rotationEvent)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
    
    return self;
}

- (void) updatePostDictionary:(NSDictionary *)dict {
    NSMutableArray *indexesToUpdate = [NSMutableArray array];
    
    for( NSString *key in [dict allKeys] ) {
        if( [key isEqualToString:kLinkField] )
            [indexesToUpdate addObject:[NSIndexPath indexPathForRow:PostLink inSection:0]];
        else if( [key isEqualToString:kTitleField] )
            [indexesToUpdate addObject:[NSIndexPath indexPathForRow:PostTitle inSection:0]];
        
        [self.postDictionary setObject:[dict objectForKey:key] forKey:key];
    }
    
    if( [indexesToUpdate count] > 0 )
        [self.postTable reloadRowsAtIndexPaths:indexesToUpdate withRowAnimation:UITableViewRowAnimationFade];
    
    self.postButton.enabled = [self canSubmitPost];
}

- (BOOL) canSubmitPost {    
    return !( [SFVUtil isEmpty:[postDictionary objectForKey:kLinkField]] && [SFVUtil isEmpty:[postDictionary objectForKey:kBodyField]] );
}

- (BOOL) isDirty {
    return [self canSubmitPost];
}

- (void)dealloc {
    self.postTable = nil;
    self.postButton = nil;
    self.postDictionary = nil;
    self.searchPopover = nil;
    self.delegate = nil;
    
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    
    [super dealloc];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    if( searchPopover && [searchPopover isPopoverVisible] )
        [searchPopover dismissPopoverAnimated:animated];
    
    self.delegate = nil;
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    [DSBezelActivityView removeViewAnimated:NO];
    
    if( self.searchPopover ) {
        [self.searchPopover dismissPopoverAnimated:NO];
        self.searchPopover = nil;
    }
}

#pragma mark - text cell response

- (void) textCellValueChanged:(TextCell *)cell {    
    int i = cell.tag;
    
    if( i == PostTitle && [postTable numberOfRowsInSection:0] == PostTableNumRows - 1 )
        i++;
    
    switch( i ) {
        case PostTitle:
            [postDictionary setObject:[cell getCellText] forKey:kTitleField];
            break;
        case PostBody:
            [postDictionary setObject:[cell getCellText] forKey:kBodyField];
            break;
        case PostLink: {
            [postDictionary setObject:[cell getCellText] forKey:kLinkField];
            
            // Insert/remove our title field as appropriate
            if( ![SFVUtil isEmpty:[postDictionary objectForKey:kLinkField]] && 
               [self.postTable numberOfRowsInSection:0] == PostTableNumRows - 1 )
                [postTable insertRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:PostTitle
                                                                                              inSection:0]]
                                 withRowAnimation:UITableViewRowAnimationFade];
            else if( [SFVUtil isEmpty:[postDictionary objectForKey:kLinkField]] &&
                      [postTable numberOfRowsInSection:0] == PostTableNumRows )
                [postTable deleteRowsAtIndexPaths:[NSArray arrayWithObject:[NSIndexPath indexPathForRow:PostTitle
                                                                                              inSection:0]]
                                 withRowAnimation:UITableViewRowAnimationFade];
            
            break;
        }
        default: break;
    }
    
    self.postButton.enabled = [self canSubmitPost];
}

#pragma mark - table view setup

- (NSInteger) tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    // Show the title field only if there's something in the link field
    BOOL hasLink = ![SFVUtil isEmpty:[postDictionary objectForKey:kLinkField]];
    
    return PostTableNumRows - ( hasLink ? 0 : 1 );
}

- (NSInteger) numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (UITableViewCell *) tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TextCell *cell = [TextCell cellForTableView:tableView];
    cell.delegate = self;
    cell.tag = indexPath.row;
    [cell setMaxLabelWidth:90.0f];
    cell.textLabel.textColor = AppSecondaryColor;
    [cell setPlaceholder:nil];
    cell.allowTextViewCarriageReturns = NO;
    
    int row = indexPath.row;
    
    // Janky title check
    if( row == PostTitle && [postTable numberOfRowsInSection:0] == PostTableNumRows - 1 )
        row++;
    
    switch( row ) {
        case PostParent:
            [cell setTextCellType:TextFieldCell];
            cell.textLabel.text = NSLocalizedString(@"Post to", @"Chatter post destination");
            cell.textField.placeholder = NSLocalizedString(@"User, Group, or Account name", @"User, Group, or Account name");
            [cell setCellText:[NSString stringWithFormat:@"%@ (%@)",
                                   [postDictionary objectForKey:kParentName],
                                   [postDictionary objectForKey:kParentType]]];
            cell.textField.enabled = NO;
            cell.textField.textColor = AppTextCellColor;
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            break;
        case PostLink:
            [cell setTextCellType:TextFieldCell];
            cell.textLabel.text = NSLocalizedString(@"Link", @"Link URL");
            [cell setPlaceholder:NSLocalizedString(@"Optional", @"Optional")];
            [cell setCellText:[postDictionary objectForKey:kLinkField]];
            [cell setValidationType:ValidateURL];
            [cell setKeyboardType:UIKeyboardTypeURL];
            [cell setMaxLength:255];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        case PostTitle:
            [cell setTextCellType:TextFieldCell];
            cell.textField.enabled = YES;
            cell.textField.textColor = AppTextCellColor;
            cell.textLabel.text = NSLocalizedString(@"Title", @"Link Title");
            [cell setPlaceholder:NSLocalizedString(@"Optional", @"Optional")];
            [cell setCellText:[postDictionary objectForKey:kTitleField]];
            cell.validationType = ValidateAlphaNumeric;
            [cell setMaxLength:255];
            [cell setKeyboardType:UIKeyboardTypeDefault];
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            break;
        case PostBody:
            [cell setTextCellType:TextViewCell];
            cell.textView.textColor = AppTextCellColor;
            cell.validationType = ValidateAlphaNumeric;
            cell.textLabel.text = NSLocalizedString(@"Body", @"Post Body");
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            [cell setKeyboardType:UIKeyboardTypeDefault];
            [cell setCellText:[postDictionary objectForKey:kBodyField]];
            [cell setPlaceholder:NSLocalizedString(@"Required", @"Required")];
            
            CGRect r = cell.textView.frame;
            r.size.height = [self tableView:tableView heightForRowAtIndexPath:indexPath];
            [cell.textView setFrame:r];
            [cell.contentView setFrame:cell.textLabel.frame];
            [cell setMaxLength:1000];
            [cell setReturnKeyType:UIReturnKeyDefault];
            cell.allowTextViewCarriageReturns = YES;
            break;
        default: break;
    }
        
    return cell;
}

- (void) tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {    
    if( indexPath.row == PostParent ) {
        if( self.searchPopover ) {
            [self.searchPopover dismissPopoverAnimated:YES];
            self.searchPopover = nil;
        }
            
        ObjectLookupController *olc = [[ObjectLookupController alloc] initWithSearchScope:nil];        
        olc.delegate = self;
        olc.onlyShowChatterEnabledObjects = YES;
        
        self.searchPopover = [[[UIPopoverController alloc] initWithContentViewController:olc] autorelease];
        self.searchPopover.delegate = self;
        
        [self.searchPopover presentPopoverFromRect:[self.postTable rectForRowAtIndexPath:indexPath]
                                            inView:self.view.superview
                          permittedArrowDirections:UIPopoverArrowDirectionRight | UIPopoverArrowDirectionLeft
                                          animated:YES];
        [olc.searchBar becomeFirstResponder];
        [olc release];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    // Show the title field only if there's something in the link field
    BOOL hasLink = ![SFVUtil isEmpty:[postDictionary objectForKey:kLinkField]];
    
    if( indexPath.row == PostTableNumRows - 1 - ( hasLink ? 0 : 1 ) )
        return ( hasLink ? tableView.rowHeight * 3 : tableView.rowHeight * 4 );
    
    return tableView.rowHeight;
}

#pragma mark - popover delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    [self.postTable deselectRowAtIndexPath:[self.postTable indexPathForSelectedRow] animated:YES];
}

- (void) actualRotationEvent {
    if( self.searchPopover && [self.searchPopover isPopoverVisible] )
        [self.searchPopover presentPopoverFromRect:[self.postTable rectForRowAtIndexPath:[NSIndexPath indexPathForRow:PostParent inSection:0]]
                                            inView:self.view.superview
                          permittedArrowDirections:UIPopoverArrowDirectionRight | UIPopoverArrowDirectionLeft
                                          animated:YES];
}

- (void)rotationEvent {
    // This is a slanderous, lecherous hack because flying windows can take their time to
    // relocate after the orientation event.
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(actualOrientationEvent) object:nil];
    [self performSelector:@selector(actualRotationEvent) withObject:nil afterDelay:0.4f];
}

#pragma mark - lookup delegate

- (void) objectLookupDidSelectRecord:(ObjectLookupController *)objectLookupController record:(NSDictionary *)record {    
    [self.searchPopover dismissPopoverAnimated:YES];
    self.searchPopover = nil;
        
    [postDictionary setObject:[record objectForKey:@"Id"] forKey:kParentField];
    [postDictionary setObject:[[SFVAppCache sharedSFVAppCache] nameForSObject:record] forKey:kParentName];
    
    NSString *type = nil;
    
    if( [record valueForKeyPath:@"attributes.type"] )
        type = [record valueForKeyPath:@"attributes.type"];
    else if( [record objectForKey:kObjectTypeKey] )
        type = [record objectForKey:kObjectTypeKey];
    else
        type = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[record objectForKey:@"Id"]];
    
    if( type )
        [postDictionary setObject:[[SFVAppCache sharedSFVAppCache] labelForSObject:type usePlural:NO] 
                           forKey:kParentType];
    
    [self.postTable reloadRowsAtIndexPaths:[NSArray arrayWithObjects:[NSIndexPath indexPathForRow:PostParent inSection:0], nil]
                          withRowAnimation:UITableViewRowAnimationRight];
}

#pragma mark - post and cancel

- (void) cancel {
    if( [self.delegate respondsToSelector:@selector(chatterPostDidDismiss:)] )
        [self.delegate chatterPostDidDismiss:self];
}

- (void) delayNotifyDelegateOfSuccess {
    if( [self.delegate respondsToSelector:@selector(chatterPostDidPost:)] )
        [self.delegate chatterPostDidPost:self];
}

- (void) submitPost {         
    for( TextCell *cell in [self.postTable visibleCells] )
        [cell resignFirstResponder];
    
    if( ![self canSubmitPost] )
        return;
    
    // Apply some defaults if our fields are empty
    if( [SFVUtil isEmpty:[postDictionary objectForKey:kParentField]] )
        [postDictionary setObject:[[SFVUtil sharedSFVUtil] currentUserId] forKey:kParentField];
    
    if( [SFVUtil isEmpty:[postDictionary objectForKey:kBodyField]] )
        [postDictionary setObject:NSLocalizedString(@"shared a link.", @"user shared a link.") forKey:kBodyField];
        
    [DSBezelActivityView newActivityViewForView:self.view withLabel:NSLocalizedString(@"Posting...",@"Posting...")];
    self.postButton.enabled = NO;
    
    [[SFAnalytics sharedInstance] tagEventOfType:SFVUserPostedToChatter
                                      attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                  [postDictionary objectForKey:kParentType], @"Parent Type",
                                                  [SFAnalytics bucketStringForNumber:[NSNumber numberWithInt:[[postDictionary objectForKey:kBodyField] length]]
                                                                          bucketSize:kBucketDefaultSize], @"Post Length",
                                                  nil]];
    
    NSMutableDictionary *post = [NSMutableDictionary dictionaryWithDictionary:postDictionary];
    [post removeObjectForKey:kParentName];
    [post removeObjectForKey:kParentType];    
    
    if( [postTable numberOfRowsInSection:0] == PostTableNumRows - 1 )
        [post removeObjectForKey:kTitleField];
        
    [[SFRestAPI sharedInstance] performCreateWithObjectType:@"FeedItem"
                                                     fields:post
                                                  failBlock:^(NSError *e) {
                                                      [DSBezelActivityView removeViewAnimated:YES];
                                                      
                                                      if( ![self isViewLoaded] ) 
                                                          return;
                                                      
                                                      [self.postTable reloadData];
                                                      self.postButton.enabled = [self canSubmitPost];
                                                                                                            
                                                      if( [self.delegate respondsToSelector:@selector(chatterPostDidFailWithError:error:)] )
                                                          [self.delegate chatterPostDidFailWithError:self error:e];
                                                  }
                                              completeBlock:^(NSDictionary *postResults) {
                                                  [DSBezelActivityView removeViewAnimated:YES];
                                                  
                                                  if( ![self isViewLoaded] ) 
                                                      return;
                                                                                                    
                                                  if( postResults && [[postResults objectForKey:@"success"] boolValue] ) {
                                                      SlideInView *checkView = [SlideInView viewWithImage:[UIImage imageNamed:@"postSuccess.png"]];
                                                      
                                                      [checkView showWithTimer:kSuccessTimer 
                                                                        inView:self.view
                                                                          from:SlideInViewTop
                                                                        bounce:NO];
                                                      
                                                      [self performSelector:@selector(delayNotifyDelegateOfSuccess) withObject:nil afterDelay:( kSuccessTimer + 0.1f )];
                                                  } else if( [self.delegate respondsToSelector:@selector(chatterPostDidFailWithError:error:)] ) {                                                      
                                                          [self.delegate chatterPostDidFailWithError:self error:[NSError errorWithDomain:@"Post Fail" code:42 userInfo:nil]];
                                                      
                                                      self.postButton.enabled = YES;
                                                  }

                                              }];
}

@end
