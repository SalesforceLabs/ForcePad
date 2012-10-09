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
#import "TextCell.h"

@protocol PicklistPickerDelegate;

@interface PicklistPicker : UITableViewController <TextCellDelegate> {    
    // Array of dictionaries.
    NSMutableArray *picklistValueArray;
    
    // Array of picklist values (not labels)
    NSMutableArray *selectedValues;
}

// If true, allows multiple selections
@property (nonatomic) BOOL allowsMultiSelect;

// If true, allows a custom value (e.g. comboboxes)
@property (nonatomic) BOOL allowsCustomValue;

@property (nonatomic, assign) id <PicklistPickerDelegate> delegate;

@property (nonatomic, copy) NSString *fieldName;
@property (nonatomic, copy) NSString *objectName;
@property (nonatomic, copy) NSString *initialCustomText;

- (id) initWithPicklistField:(NSString *)field onRecord:(NSDictionary *)record withSelectedValues:(NSArray *)values;
- (id) initWithRecordTypeListForObject:(NSString *)object withSelectedRecordType:(NSString *)recordTypeId;

- (void) reloadAndResize;

@end

// START:Delegate
@protocol PicklistPickerDelegate <NSObject>

@optional

- (void) picklistPicker:(PicklistPicker *)picker didSelectValue:(NSString *)value label:(NSString *)label;
- (void) picklistPicker:(PicklistPicker *)picker didDeselectValue:(NSString *)value label:(NSString *)label;

@end
// END:Delegate