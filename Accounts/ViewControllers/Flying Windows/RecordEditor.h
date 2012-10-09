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
#import "FlyingWindowController.h"
#import "ObjectLookupController.h"
#import "TextCell.h"
#import "PicklistPicker.h"
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>
#import "DateTimePicker.h"

@interface RecordEditor : FlyingWindowController 
        <UITableViewDelegate, UITableViewDataSource, ObjectLookupDelegate, 
        UIActionSheetDelegate, TextCellDelegate, UIPopoverControllerDelegate, PicklistPickerDelegate, 
        UIGestureRecognizerDelegate, ABPeoplePickerNavigationControllerDelegate, DateTimePickerDelegate> {    
    // Our actual tableview and record
    UITableView *recordTable;
    NSMutableDictionary *record;
    
    // Store the layout of the record we are editing.
    // If we change a recordtype, this has to get recalculated.
    // The format is an array of arrays. 
    // Each sub-array is a layout section and contains a list of layout components.
    NSMutableArray *layoutComponents;
    
    // Stores the names of the section headers. The first section is always record type
    NSMutableArray *sectionTitles;
                                                    
    // Stores all related records in our editing layout
    // key: id, value: record name
    NSMutableDictionary *relatedRecordDictionary;
    
    // Action sheet used to confirm cancelling the edit operation
    UIActionSheet *cancelSheet;
    
    // Bar buttons
    UIBarButtonItem *cancelButton;
    UIBarButtonItem *saveButton;
    
    // sObject Type
    NSString *sObjectType;
    
    // If true, requires an action sheet to cancel editing
    BOOL isDirty;
    
    // Currently visible popover
    UIPopoverController *popoverController;
    
    NSIndexPath *activeIndexPath;
    
    // Dictionary of field -> index path
    NSMutableDictionary *fieldsToIndexPaths;
    
    // display the currently active error
    UILabel *errorLabel;
    NSString *errorField;
    
    BOOL isKeyboardVisible;
}

// the type of this editing window.
typedef enum RecordEditorTypes {
    RecordEditorNewRecord = 0,
    RecordEditorEditRecord,
    RecordEditorNumTypes
} RecordEditorType;

// Each field component in the layout component array
// is itself an array with this format. All components are strings
// except where noted
typedef enum RecordComponentFields {
    FieldComponentName = 0,
    FieldComponentType,
    FieldComponentLabel,
    FieldComponentIsRequired, // number with boolean
    FieldComponentDoNotRenderInTable, // number with boolean
    FieldComponentIsDirty, // number with boolean
    FieldNumComponents
} RecordComponentField;

/* Properties */

@property (nonatomic) RecordEditorType editorType;

@property (nonatomic, assign) UIResponder *currentFirstResponder;

/* Setup */

// Main init
- (id) initWithFrame:(CGRect)frame;

// If acc is a dictionary with an 'Id' field, we start in 'edit' mode.
// Otherwise we start in 'new' mode, with at minimum an object type
- (void) setRecord:(NSDictionary *)rec;

// Recalculates our table layout and reloads accordingly.
- (NSArray *) parseLayoutForLayoutItem:(ZKDescribeLayoutItem *)item;
- (void) recalculateLayoutComponents;
- (void) setDirtyFieldAtIndexPath:(NSIndexPath *)indexPath;

// One-word action verb (New, Create, Edit) based on our current mode
+ (NSString *) editorActionForEditType:(RecordEditorType)type;

// Rotation
- (void) rotationEvent;
- (void) actualRotationEvent;

// Keyboard
- (void) keyboardWillChangeFrame:(NSNotification *)notification;
- (void) tryForceResignFirstResponder;

// Util
- (void) scrollTableToIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (void) showPopover:(UIPopoverController *)pop fromIndexPath:(NSIndexPath *)indexPath;

/* Record Editing */

- (NSArray *) fieldArrayAtIndexPath:(NSIndexPath *)indexPath;
- (void) clearSelectedField;
- (void) updateNavBar;

- (void) deleteRecord:(id)sender;

- (void) reloadDependentFieldsForControllingIndexPath:(NSIndexPath *)indexPath;

- (void) showAddressBookPicker:(id)sender;

// If true, allows a save action (all required fields are filled, etc)
- (BOOL) canSave;

// Cancel a new/edit
- (void) cancelEditing;
- (void) dismissWindow;

// Submitting a record
- (void) submitRecord;

@end
