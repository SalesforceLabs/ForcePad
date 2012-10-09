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

#import "OAuthCustomHostCreator.h"
#import "OAuthLoginHostPicker.h"
#import "SFVUtil.h"

@implementation OAuthCustomHostCreator

@synthesize delegate;

- (id)initWithStyle:(UITableViewStyle)style {
    if(( self = [super initWithStyle:style] )) {
        self.title = NSLocalizedString(@"New Custom Host", @"New Custom Host");
        
        newHost = [[NSMutableArray alloc] initWithCapacity:CustomHostNumFields];
        
        for( int x = 0; x < CustomHostNumFields; x++ )
            [newHost addObject:@""];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardToggle)
                                                     name:UIKeyboardDidChangeFrameNotification
                                                   object:nil];
    }
    
    [self.tableView reloadData];
    
    return self;
}

- (void)keyboardToggle {
    if( [self.delegate respondsToSelector:@selector(OAuthCustomHostCreatorNeedsRedisplay:)] )
        [self.delegate OAuthCustomHostCreatorNeedsRedisplay:self];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if( !doneButton ) {
        doneButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                   target:self
                                                                   action:@selector(saveHost)];
        
        doneButton.enabled = NO;
    }
    
    [self.navigationItem setRightBarButtonItem:doneButton animated:YES];
    
    CGSize s = [self.tableView sizeThatFits:CGSizeMake( 400, 400 )];    
    [self.tableView setFrame:CGRectMake(0, 0, s.width, s.height)];
    
    self.contentSizeForViewInPopover = s;
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter]
     removeObserver:self 
     name:UIKeyboardDidChangeFrameNotification 
     object:nil];
    
    SFRelease(doneButton);
    SFRelease(newHost);
    self.delegate = nil;
    
    [super dealloc];
}

- (void)saveHost { 
    NSString *url = [newHost objectAtIndex:CustomHostURL];
    
    // basic https check. this is a little silly
    if( ![url hasPrefix:@"https://"] ) {
        url = [@"https://" stringByAppendingString:url];
        [newHost removeObjectAtIndex:CustomHostURL];
        [newHost insertObject:url atIndex:CustomHostURL];
    }
    
    if( ![url hasSuffix:@"/"] ) {
        url = [url stringByAppendingString:@"/"];
        [newHost removeObjectAtIndex:CustomHostURL];
        [newHost insertObject:url atIndex:CustomHostURL];
    }
    
    // tack it on the end of the custom host array
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSMutableArray *hosts = [NSMutableArray arrayWithArray:[OAuthLoginHostPicker customHosts]];
    [hosts addObject:newHost];
    
    [defaults setObject:hosts forKey:kCustomHostArrayKey];
    [defaults synchronize];
    
    if( [self.delegate respondsToSelector:@selector(OAuthCustomHostCreator:didSaveNewHostAtCustomHostIndex:)] )
        [self.delegate OAuthCustomHostCreator:self didSaveNewHostAtCustomHostIndex:( [hosts count] - 1 )];
}

#pragma mark - Table view

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    switch( section ) {
        case CustomHostName:
            return NSLocalizedString(@"Label", @"Label");
        case CustomHostURL:
            return NSLocalizedString(@"Host Name", @"Host Name");
    }
    
    return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return CustomHostNumFields;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    TextCell *cell = [TextCell cellForTableView:tableView];
    [cell setTextCellType:TextFieldCell];
    [cell setMaxLabelWidth:0];
    
    [cell setCellText:[newHost objectAtIndex:indexPath.section]];
    cell.delegate = self;
    cell.tag = indexPath.section;
    
    switch( indexPath.section ) {
        case CustomHostName:
            [cell setPlaceholder:NSLocalizedString(@"Optional", @"Optional")];
            [cell setKeyboardType:UIKeyboardTypeDefault];
            [cell setValidationType:ValidateAlphaNumeric];
            [cell setMaxLength:75];
            break;
        case CustomHostURL:
            [cell setPlaceholder:@"login.salesforce.com"];
            [cell setKeyboardType:UIKeyboardTypeURL];
            [cell setValidationType:ValidateURL];
            [cell setMaxLength:250];
            break;
        default:
            break;
    }
    
    return cell;
}

#pragma mark - text cell delegate

- (void)textCellValueChanged:(TextCell *)cell {
    [newHost removeObjectAtIndex:cell.tag];
    [newHost insertObject:[cell getCellText] atIndex:cell.tag];

    // URL field required. For now accept any non-empty value 
    if( [SFVUtil isEmpty:[newHost objectAtIndex:CustomHostURL]] ) {
        [doneButton setEnabled:NO];
        return;
    }
    
    [doneButton setEnabled:YES];
}

@end
