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

#import "OAuthLoginHostPicker.h"
#import "PRPSmartTableViewCell.h"
#import "SFVUtil.h"

@implementation OAuthLoginHostPicker

@synthesize delegate;

- (id)initWithStyle:(UITableViewStyle)style {
    if(( self = [super initWithStyle:style] )) {
        self.title = NSLocalizedString(@"Login Host", @"Login Host");
        
        self.tableView.allowsSelectionDuringEditing = YES;
        
        self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
        self.tableView.separatorColor = [UIColor darkGrayColor];
    }
    
    [self reloadAndResize];
    
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if( !self.navigationItem.leftBarButtonItem && [[[self class] customHosts] count] > 0 )
        [self.navigationItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                                               target:self
                                                                                               action:@selector(tappedEdit:)] autorelease]
                                         animated:YES];
    
    if( !self.navigationItem.rightBarButtonItem )
        [self.navigationItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                                target:self
                                                                                                action:@selector(tappedAddHost:)] autorelease]
                                          animated:YES];
}

- (void)reloadAndResize {
    [self.tableView reloadData];
    
    CGSize s = [self.tableView sizeThatFits:CGSizeMake( 300, 400 )];
    [self.tableView setFrame:CGRectMake(0, 0, s.width, s.height)];
    
    self.contentSizeForViewInPopover = s;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)dealloc {
    self.delegate = nil;
    [super dealloc];
}

#pragma mark - custom hosts

+ (NSArray *)customHosts {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    NSArray *ret = [defaults arrayForKey:kCustomHostArrayKey];
    
    if( !ret )
        return [NSArray array];
    
    return ret;
}

+ (NSUInteger)indexOfCurrentLoginHost {
    NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
    
    return [defaults integerForKey:kLoginHostIndexKey];
}

+ (NSString *) URLForCurrentLoginHost {
    NSString *host = nil;
    NSInteger i = [self indexOfCurrentLoginHost];
    
    switch( i ) {
        case LoginProduction:
            host = kProdLoginURL;
            break;
        case LoginSandbox:
            host = kSandboxLoginURL;
            break;
        default:
            host = [[[[self class] customHosts] objectAtIndex:i - LoginNumStandardTypes] objectAtIndex:CustomHostURL];
            break;
    }
    
    return [( [SFVUtil isEmpty:host] ? kProdLoginURL : host ) lowercaseString];
}

+ (NSString *) nameForCurrentLoginHost { 
    NSInteger i = [self indexOfCurrentLoginHost];
    
    switch( i ) {
        case LoginProduction:
            return NSLocalizedString(@"Production", @"Production");
        case LoginSandbox:
            return NSLocalizedString(@"Sandbox", @"Sandbox");
        default: {
            NSArray *arr = [[[self class] customHosts] objectAtIndex:i - LoginNumStandardTypes];
            
            return ( [SFVUtil isEmpty:[arr objectAtIndex:CustomHostName]] ? NSLocalizedString(@"Custom Host", @"Custom Host") : 
                    [arr objectAtIndex:CustomHostName] );
        }
    }
    
    return @"undef";
}

#pragma mark - Table view data source/delegate

- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    return !( indexPath.row == LoginProduction || indexPath.row == LoginSandbox );
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return LoginNumStandardTypes + [[[self class] customHosts] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    PRPSmartTableViewCell *cell = [PRPSmartTableViewCell cellForTableView:tableView];
    
    cell.textLabel.textColor = [UIColor lightGrayColor];
    cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
    
    if( indexPath.row < LoginNumStandardTypes ) {
        cell.detailTextLabel.text = nil;
        
        switch( indexPath.row ) {
            case LoginProduction:
                cell.textLabel.text = NSLocalizedString(@"Production", @"Production");
                break;
            case LoginSandbox:
                cell.textLabel.text = NSLocalizedString(@"Sandbox", @"Sandbox");
                break;
            default: break;
        }
    } else {
        NSArray *host = [[[self class] customHosts] objectAtIndex:indexPath.row - LoginNumStandardTypes];
        
        if( [SFVUtil isEmpty:[host objectAtIndex:CustomHostName]] ) {
            cell.textLabel.text = [host objectAtIndex:CustomHostURL];
            cell.detailTextLabel.text = nil;
            cell.textLabel.numberOfLines = 2;
        } else {
            cell.textLabel.text = [host objectAtIndex:CustomHostName];
            cell.detailTextLabel.text = [host objectAtIndex:CustomHostURL];
            cell.textLabel.numberOfLines = 1;
        }
    }
    
    if( [[self class] indexOfCurrentLoginHost] == indexPath.row )
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
    else
        cell.accessoryType = UITableViewCellAccessoryNone;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {            
    if( [self.delegate respondsToSelector:@selector(OAuthLoginHost:didSelectLoginHostAtIndex:)] )
        [self.delegate OAuthLoginHost:self didSelectLoginHostAtIndex:indexPath.row];
    
    [self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    if( editingStyle == UITableViewCellEditingStyleDelete ) {
        BOOL isCurrentlySelected = ( indexPath.row == [[self class] indexOfCurrentLoginHost] );
        int pos = indexPath.row - LoginNumStandardTypes;
        NSMutableArray *arr = [NSMutableArray arrayWithArray:[[self class] customHosts]];
        NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
        
        [arr removeObjectAtIndex:pos];
        [defaults setObject:arr forKey:kCustomHostArrayKey];
        
        if( indexPath.row < [[self class] indexOfCurrentLoginHost] )
            [defaults setInteger:( [[self class] indexOfCurrentLoginHost] - 1 ) forKey:kLoginHostIndexKey];
        
        [self.tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] 
                              withRowAnimation:UITableViewRowAnimationFade];
        
        if( isCurrentlySelected ) {            
            if( [self.delegate respondsToSelector:@selector(OAuthLoginHost:didSelectLoginHostAtIndex:)] )
                [self.delegate OAuthLoginHost:self didSelectLoginHostAtIndex:0];
            
            [defaults setInteger:0 forKey:kLoginHostIndexKey];
        }
        
        [defaults synchronize];
        
        [self performSelector:@selector(reloadAndResize) withObject:nil afterDelay:0.35f];
    }
}

#pragma mark - actions

- (void)tappedAddHost:(id)sender {
    if( [self.delegate respondsToSelector:@selector(OAuthLoginHostDidTapAddCustomHostButton:)] )
        [self.delegate OAuthLoginHostDidTapAddCustomHostButton:self];
}

- (void)tappedEdit:(id)sender {
    UIBarButtonItem *btn = nil;
    
    if( [self.tableView isEditing] ) {
        [self.tableView setEditing:NO animated:YES];
        
        if( [[[self class] customHosts] count] > 0 )
            btn = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemEdit
                                                                 target:self
                                                                 action:@selector(tappedEdit:)] autorelease];
        
        [self.navigationItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd
                                                                                                  target:self
                                                                                                  action:@selector(tappedAddHost:)] autorelease]
                                          animated:YES];
    } else {
        [self.tableView setEditing:YES animated:YES];
        
        btn = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                             target:self
                                                             action:@selector(tappedEdit:)] autorelease];
        
        [self.navigationItem setRightBarButtonItem:nil animated:YES];
    }
    
    [self.navigationItem setLeftBarButtonItem:btn animated:YES];
}

@end
