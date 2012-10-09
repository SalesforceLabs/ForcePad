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

#import "PicklistPicker.h"
#import "SFVUtil.h"
#import "PRPSmartTableViewCell.h"
#import "SFVAppCache.h"
#import "SFVAsync.h"

@implementation PicklistPicker

@synthesize delegate, allowsMultiSelect, fieldName, objectName, allowsCustomValue, initialCustomText;

#pragma mark - setup

- (id) init {
    if( ( self = [super init] ) ) {
        allowsMultiSelect = NO;
        self.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
        self.view.backgroundColor = self.tableView.backgroundColor;
        self.tableView.separatorColor = [UIColor darkGrayColor];
        self.tableView.indicatorStyle = UIScrollViewIndicatorStyleWhite;
        
        selectedValues = [[NSMutableArray alloc] init];
        picklistValueArray = [[NSMutableArray alloc] init];
    }
    
    return self;
}

- (id)initWithRecordTypeListForObject:(NSString *)object withSelectedRecordType:(NSString *)recordTypeId {
    if( ( self = [self init] ) ) {
        self.fieldName = kRecordTypeIdField;
        self.objectName = object;
        
        // all record types for this object
        NSMutableDictionary *rtDict = [NSMutableDictionary dictionaryWithDictionary:[[SFVUtil sharedSFVUtil] availableRecordTypesForObject:object]];
        
        NSArray *sortedNames = [SFVUtil sortArray:[rtDict allValues]];
        
        for( NSString *name in sortedNames )
            for( NSString *rtID in [rtDict allKeys] )
                if( [[rtDict objectForKey:rtID] isEqualToString:name] ) {
                    [picklistValueArray addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                                                      rtID, @"value",
                                                      [rtDict objectForKey:rtID], @"label",
                                                      nil]];
            
                    [rtDict removeObjectForKey:rtID];
                    break;
                }
        
        // select our default
        if( recordTypeId )
            [selectedValues addObject:recordTypeId];
    }
    
    [self reloadAndResize];
    
    return self;
}

- (id)initWithPicklistField:(NSString *)field onRecord:(NSDictionary *)record withSelectedValues:(NSArray *)values {
    if( ( self = [self init] ) ) {
        self.fieldName = field;
        
        if( [record objectForKey:kObjectTypeKey] )
            self.objectName = [record objectForKey:kObjectTypeKey];
        else
            self.objectName = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[record objectForKey:@"Id"]];
        
        [picklistValueArray addObjectsFromArray:[[SFVUtil sharedSFVUtil] picklistValuesForField:field onObject:record filterByRecordType:YES]];
        
        // add selected values
        if( values )
            [selectedValues addObjectsFromArray:values];
    }
    
    [self reloadAndResize];
        
    return self;
}

- (void)reloadAndResize {
    [self.tableView reloadData];
    
    CGSize s = [self.tableView sizeThatFits:CGSizeMake( 300, 400 )];
    [self.tableView setFrame:CGRectMake(0, 0, s.width, s.height)];
    
    self.contentSizeForViewInPopover = s;
}

- (void)dealloc {
    SFRelease(picklistValueArray);
    SFRelease(selectedValues);
    self.delegate = nil;
    self.fieldName = nil;
    self.objectName = nil;
    self.initialCustomText = nil;
    
    [super dealloc];
}

#pragma mark - View lifecycle

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark - textcell delegate 

- (void)textCellValueChanged:(TextCell *)cell {
    self.initialCustomText = [cell getCellText];
}

- (BOOL)textCellShouldReturn:(TextCell *)cell {
    return YES;
}

- (void)textCellDidEndEditing:(TextCell *)cell {
    if( [self.delegate respondsToSelector:@selector(picklistPicker:didSelectValue:label:)] )
        [self.delegate picklistPicker:self didSelectValue:[cell getCellText] label:[cell getCellText]];
}

#pragma mark - table view delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [picklistValueArray count] + ( allowsCustomValue ? 1 : 0 );
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    int row = indexPath.row;
    
    if( allowsCustomValue && row == 0 ) {
        // custom value row
        TextCell *cell = [TextCell cellForTableView:tableView];
        cell.delegate = self;
        [cell setTextCellType:TextFieldCell];
        
        cell.textLabel.text = nil;        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        [cell setMaxLength:60];
        [cell setReturnKeyType:UIReturnKeyDone];
        cell.textField.textColor = [UIColor lightGrayColor];
        [cell setCellText:self.initialCustomText];
        [cell setPlaceholder:NSLocalizedString(@"Custom Value", @"Custom Value")];
        
        return cell;
    } else {
        if( allowsCustomValue ) 
            row--;
    
        PRPSmartTableViewCell *cell = [PRPSmartTableViewCell cellForTableView:tableView];
        NSDictionary *picklistValue = [picklistValueArray objectAtIndex:row];
        
        cell.textLabel.text = [picklistValue objectForKey:@"label"];
        cell.textLabel.numberOfLines = 2;
        cell.textLabel.font = [UIFont boldSystemFontOfSize:16];
        cell.textLabel.textColor = [UIColor lightGrayColor];
        cell.backgroundView = nil;
        cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
        
        if( [selectedValues containsObject:[picklistValue objectForKey:@"value"]] )
            cell.accessoryType = UITableViewCellAccessoryCheckmark;
        else
            cell.accessoryType = UITableViewCellAccessoryNone;
        
        return cell;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if( allowsCustomValue && indexPath.row == 0 )
        return;
    
    NSDictionary *picklistValue = [picklistValueArray objectAtIndex:( allowsCustomValue ? indexPath.row - 1 : indexPath.row )];
    NSString *value = [picklistValue objectForKey:@"value"];
    NSString *label = [picklistValue objectForKey:@"label"];
    
    if( [selectedValues containsObject:value] ) {
        [selectedValues removeObject:value];
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
        
        if( [self.delegate respondsToSelector:@selector(picklistPicker:didDeselectValue:label:)] )
            [self.delegate picklistPicker:self didDeselectValue:value label:label];
    } else {
        [selectedValues addObject:value];
        [self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                              withRowAnimation:UITableViewRowAnimationFade];
        
        if( [self.delegate respondsToSelector:@selector(picklistPicker:didSelectValue:label:)] )
            [self.delegate picklistPicker:self didSelectValue:value label:label];
    }
}

@end
