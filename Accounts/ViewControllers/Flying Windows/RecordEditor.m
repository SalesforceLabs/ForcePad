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

#import "RecordEditor.h"
#import "SFVAsync.h"
#import "SFVUtil.h"
#import "DSActivityView.h"
#import "TextCell.h"
#import "DetailViewController.h"
#import "SFVAppCache.h"
#import "SFRestAPI+SFVAdditions.h"
#import "PRPAlertView.h"
#import "RootViewController.h"
#import "DateTimePicker.h"

// TODO when selecting a dependent picklist, and the controlling field is empty, scroll to controlling field?

@interface RecordEditor (Private)
- (void) dismissPopoverWithDelegateCall;
@end

@implementation RecordEditor

#pragma mark - init, setup

// field types for which to not use textcells
#define kNonTextCells [NSArray arrayWithObjects:@"boolean", nil]

// switches on or off the dirty fields feature.
// when on, only fields the user explicitly modifies 
// (or that were included in a clone or initial defaults)
// will be included in upsert calls
#define kOnlyUpsertDirtyFields YES

@synthesize editorType, currentFirstResponder;

- (id) initWithFrame:(CGRect)frame {
    if( ( self = [super initWithFrame:frame] ) ) {        
        isDirty = NO;
        
        // Bar buttons
        cancelButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel
                                                                     target:self
                                                                     action:@selector(cancelEditing)];
        saveButton = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemSave
                                                                   target:self
                                                                   action:@selector(submitRecord)];
        
        // Record table
        recordTable = [[UITableView alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.navBar.frame), 
                                                                    CGRectGetWidth(frame), CGRectGetHeight(frame) - CGRectGetMaxY(self.navBar.frame))
                                                   style:UITableViewStylePlain];
        recordTable.dataSource = self;
        recordTable.delegate = self;
        recordTable.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        recordTable.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.gif"]];
        
        // Table Footer            
        UIImage *i = [UIImage imageNamed:@"tilde.png"];
        UIImageView *iv = [[[UIImageView alloc] initWithImage:i] autorelease];
        iv.alpha = 0.25f;
        [iv setFrame:CGRectMake( lroundf( ( CGRectGetWidth(frame) - i.size.width ) / 2.0f ), 10, i.size.width, i.size.height )];
        
        UIView *footerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(frame), 70 )] autorelease];
        [footerView addSubview:iv];
        recordTable.tableFooterView = footerView;
        
        [self.view addSubview:recordTable];
        
        isKeyboardVisible = NO;
        
        // Initialize the record table data
        sectionTitles = [[NSMutableArray alloc] init];
        layoutComponents = [[NSMutableArray alloc] init];
        relatedRecordDictionary = [[NSMutableDictionary alloc] init];
        fieldsToIndexPaths = [[NSMutableDictionary alloc] init];
        
        // Initialize error label
        errorLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, CGRectGetMaxY(self.navBar.frame), 0, 0)];
        errorLabel.backgroundColor = [UIColor clearColor];
        errorLabel.textColor = [UIColor redColor];
        errorLabel.font = [UIFont boldSystemFontOfSize:16];
        errorLabel.numberOfLines = 0;
        errorLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleLeftMargin |
                                        UIViewAutoresizingFlexibleRightMargin;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                              action:nil];
        tap.numberOfTapsRequired = 1;
        tap.cancelsTouchesInView = NO;
        tap.delaysTouchesBegan = YES;
        tap.delegate = self;
        
        [errorLabel addGestureRecognizer:tap];
        [tap release];
        
        [self.view addSubview:errorLabel];
    }
    
    [self updateNavBar];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(rotationEvent)
     name:UIDeviceOrientationDidChangeNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(keyboardWillChangeFrame:)
     name:UIKeyboardWillShowNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:self
     selector:@selector(keyboardWillChangeFrame:)
     name:UIKeyboardWillHideNotification
     object:nil];
    
    return self;
}

+ (NSString *)editorActionForEditType:(RecordEditorType)type {
    switch( type ) {
        case RecordEditorEditRecord:
            return NSLocalizedString(@"Edit", @"Edit");
        case RecordEditorNewRecord:
            return NSLocalizedString(@"New", @"New");
        default:
            return @"Unknown type";
    }
    
    return @"Unknown type";
}

- (void)updateNavBar {
    if( !record || [record count] == 0 ) {
        [self pushNavigationBarWithTitle:NSLocalizedString(@"Loading...", @"Loading...") animated:NO];
        return;
    }
    
    NSString *navTitle = [NSString stringWithFormat:@"%@ %@", 
                          [[self class] editorActionForEditType:self.editorType], 
                          ( self.editorType == RecordEditorNewRecord
                           ? [[SFVAppCache sharedSFVAppCache] labelForSObject:sObjectType usePlural:NO]
                           : [[SFVAppCache sharedSFVAppCache] nameForSObject:record] )];
    
    NSMutableArray *rightBarItems = [NSMutableArray array];
    
    UIBarButtonItem *spacer = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace
                                                                             target:nil
                                                                             action:nil] autorelease];
    
    if( [sObjectType isEqualToString:@"Contact"] || [sObjectType isEqualToString:@"Lead"] ) {
        [rightBarItems addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemBookmarks
                                                                                target:self
                                                                                action:@selector(showAddressBookPicker:)] autorelease]];
        [rightBarItems addObject:spacer];
    }
    
    if( self.editorType == RecordEditorEditRecord
        && [[SFVAppCache sharedSFVAppCache] doesObject:sObjectType 
                                          haveProperty:ObjectIsDeletable] )
            [rightBarItems addObject:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemTrash 
                                                                                    target:self 
                                                                                    action:@selector(deleteRecord:)] autorelease]];
    
    [rightBarItems addObject:spacer];    
    [rightBarItems addObject:saveButton];
    
    UIToolbar *rightBar = [[UIToolbar alloc] initWithFrame:CGRectMake( 0, 0, 40 * [rightBarItems count], CGRectGetHeight(self.navBar.frame))];
    rightBar.tintColor = self.navBar.tintColor;
    [rightBar setItems:rightBarItems
              animated:NO];
    
    [self pushNavigationBarWithTitle:navTitle
                            leftItem:cancelButton
                           rightItem:[[[UIBarButtonItem alloc] initWithCustomView:rightBar] autorelease]
                            animated:NO];
    [rightBar release];
}

// This is when we receive our record and kick off actual setup.
- (void)setRecord:(NSDictionary *)rec {    
    if( !rec ) // merde.
        return;
    
    record = [[NSMutableDictionary alloc] initWithDictionary:rec];
    
    // What kind of editor are we?
    if( ![SFVUtil isEmpty:[record objectForKey:@"Id"]] ) {
        self.editorType = RecordEditorEditRecord;
        sObjectType = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[record objectForKey:@"Id"]];
    } else
        self.editorType = RecordEditorNewRecord;
    
    if( !sObjectType )
        sObjectType = [record objectForKey:kObjectTypeKey];
    
    // just to be sure
    [record setObject:sObjectType
               forKey:kObjectTypeKey];
            
    [DSBezelActivityView newActivityViewForView:recordTable];
    
    // Ensure we have described the object and its layout
    [[SFRestAPI sharedInstance] SFVperformDescribeWithObjectType:sObjectType
                                                       failBlock:nil
                                                   completeBlock:^(NSDictionary *dict) {
                                                       if( ![self isViewLoaded] ) 
                                                           return;
                                                       
                                                       DescribeLayoutCompletionBlock completeBlock = ^(ZKDescribeLayoutResult *result) {
                                                           if( ![self isViewLoaded] ) 
                                                               return;
                                                           
                                                           if( [[SFVAppCache sharedSFVAppCache] doesObject:sObjectType
                                                                                              haveProperty:ObjectIsRecordTypeEnabled] ) {
                                                               if( [SFVUtil isEmpty:[record objectForKey:kRecordTypeIdField]] ) {
                                                                   NSDictionary *defaultRT = [[SFVUtil sharedSFVUtil] defaultRecordTypeForObject:sObjectType];
                                                                   
                                                                   // save to related records
                                                                   if( defaultRT ) {
                                                                       [relatedRecordDictionary setObject:[[defaultRT allValues] objectAtIndex:0]
                                                                                                   forKey:[[defaultRT allKeys] objectAtIndex:0]];
                                                                       
                                                                       // save to our record
                                                                       [record setObject:[[defaultRT allKeys] objectAtIndex:0]
                                                                                  forKey:kRecordTypeIdField];
                                                                   }
                                                               } 
                                                               
                                                               if( [record objectForKey:kRecordTypeRelationshipField] )
                                                                   [relatedRecordDictionary setObject:[[SFVAppCache sharedSFVAppCache] 
                                                                                                       nameForSObject:[record objectForKey:kRecordTypeRelationshipField]]
                                                                                               forKey:[record objectForKey:kRecordTypeIdField]];
                                                           }
                                                           
                                                           [self performSelector:@selector(recalculateLayoutComponents) withObject:nil afterDelay:0.8f];
                                                       };
                                                       
                                                       if( [[SFVAppCache sharedSFVAppCache] doesGlobalObject:sObjectType 
                                                                                                haveProperty:GlobalObjectIsLayoutable] )
                                                           [[SFVUtil sharedSFVUtil] describeLayoutForsObject:sObjectType
                                                                                               completeBlock:completeBlock];
                                                       else
                                                           completeBlock( nil );
                                                   }];
}

#pragma mark - layout parsing

- (NSArray *) parseLayoutForLayoutItem:(ZKDescribeLayoutItem *)item {
    // If this item is blank or a placeholder, we ignore it
    if( [item placeholder] || [[item layoutComponents] count] == 0 )
        return nil;
        
    //NSLog(@"%@ %@ %i %i", [item label], [(ZKDescribeLayoutComponent *)[[item layoutComponents] objectAtIndex:0] value], [item required], [item editable]);
    
    // Fields never to include in the layout.
    NSArray *fieldsToExclude = [NSArray arrayWithObjects:@"Id", nil];
    
    NSMutableArray *itemComponents = [NSMutableArray array];
    
    for( ZKDescribeLayoutComponent *dlc in [item layoutComponents] ) {                    
        if( dlc.type != zkComponentTypeField )
            continue;
        
        NSString *fieldName = [dlc value];
        
        // add record type field at the first section
        if( [fieldName isEqualToString:kRecordTypeIdField] ) {            
            NSMutableArray *rtArray = [NSMutableArray arrayWithCapacity:FieldNumComponents];
            
            for( int x = 0; x < FieldNumComponents; x++ )
                switch( x ) {
                    case FieldComponentName:
                        [rtArray addObject:kRecordTypeIdField];
                        break;
                    case FieldComponentLabel:
                        [rtArray addObject:[item label]];                                
                        
                        break;
                    case FieldComponentIsRequired:
                        [rtArray addObject:[NSNumber numberWithBool:YES]];
                        break;
                    case FieldComponentType:
                        [rtArray addObject:@"reference"];
                        break;
                    case FieldComponentDoNotRenderInTable:
                        [rtArray addObject:[NSNumber numberWithBool:NO]];
                        break;
                    case FieldComponentIsDirty:
                        [rtArray addObject:[NSNumber numberWithBool:YES]];
                        break;
                }
            
            [layoutComponents insertObject:[NSArray arrayWithObject:rtArray]
                                   atIndex:0];
            [sectionTitles insertObject:[item label]
                                atIndex:0];
            continue;
        } else if( [fieldsToExclude containsObject:fieldName] )
            continue;
        
        // Check our access to this field    
        if( self.editorType == RecordEditorNewRecord
            && ![[SFVAppCache sharedSFVAppCache] doesField:fieldName
                                                  onObject:sObjectType
                                              haveProperty:FieldIsCreateable] )
            continue;
        else if( self.editorType == RecordEditorEditRecord 
                && ![[SFVAppCache sharedSFVAppCache] doesField:fieldName
                                                      onObject:sObjectType
                                                  haveProperty:FieldIsUpdateable] )
            continue;
        
        // If this is a related field, save it into our related record dictionary
        if( [[SFVAppCache sharedSFVAppCache] doesField:fieldName
                                              onObject:sObjectType
                                          haveProperty:FieldIsReferenceField]
           && ![SFVUtil isEmpty:[record objectForKey:fieldName]] )
            [relatedRecordDictionary setObject:[[SFVAppCache sharedSFVAppCache] nameForSObject:
                                                [record objectForKey:
                                                 [[SFVAppCache sharedSFVAppCache] field:fieldName
                                                                               onObject:sObjectType
                                                                         stringProperty:FieldRelationshipName]]]
                                        forKey:[record objectForKey:fieldName]];
        
        // Apply a default value, if we are creating a new record
        if( self.editorType == RecordEditorNewRecord ) {
            NSString *defaultValue = [[SFVAppCache sharedSFVAppCache] field:fieldName 
                                                                   onObject:sObjectType
                                                             stringProperty:FieldDefaultValueFormula];
            NSString *fieldType = [[SFVAppCache sharedSFVAppCache] field:fieldName
                                                                onObject:sObjectType
                                                          stringProperty:FieldType];
            
            // do not specify default for owner
            if( ![SFVUtil isEmpty:defaultValue] && ![fieldName isEqualToString:@"OwnerId"] ) {
                if( [defaultValue isEqualToString:@"TODAY()"] )
                    [record setObject:[SFVUtil SOQLDatetimeFromDate:[NSDate date] isDateTime:[fieldType isEqualToString:@"datetime"]]
                               forKey:fieldName];
                else {                    
                    if( [fieldType isEqualToString:@"boolean"] )
                        [record setObject:[NSNumber numberWithBool:YES]
                                   forKey:fieldName];
                    else if( ![fieldType isEqualToString:@"date"] && ![fieldType isEqualToString:@"datetime"] )
                        [record setObject:defaultValue
                                   forKey:fieldName];
                }
            }
        }
        
        // Construct an array 
        NSMutableArray *fieldComponentArray = [NSMutableArray arrayWithCapacity:FieldNumComponents];
        
        for( int x = 0; x < FieldNumComponents; x++ )
            switch( x ) {
                case FieldComponentName:
                    [fieldComponentArray addObject:fieldName];
                    break;
                case FieldComponentLabel:
                    // If this layout item has a single field, we use that item's label.
                    // Otherwise, we use the field label for each field in that component
                    if( [[item layoutComponents] count] == 1 )
                        [fieldComponentArray addObject:[item label]];
                    else
                        [fieldComponentArray addObject:[[SFVAppCache sharedSFVAppCache] field:fieldName
                                                                                     onObject:sObjectType
                                                                               stringProperty:FieldLabel]];                                
                    
                    break;
                case FieldComponentIsRequired:
                    [fieldComponentArray addObject:[NSNumber numberWithBool:[item required]]];
                    break;
                case FieldComponentType:
                    [fieldComponentArray addObject:[[SFVAppCache sharedSFVAppCache] field:fieldName
                                                                                 onObject:sObjectType
                                                                           stringProperty:FieldType]];
                    break;
                case FieldComponentDoNotRenderInTable: {
                    // Read-only?
                    BOOL doNotRender = NO;
                    
                    // Always allow edits to owner and record type
                    if( ![item editable]
                        && ![[NSArray arrayWithObjects:@"OwnerId", kRecordTypeIdField, nil] containsObject:fieldName] ) {
                            NSLog(@"SKIP NON-EDITABLE %@", fieldName);
                            doNotRender = YES;
                    }
                    
                    [fieldComponentArray addObject:[NSNumber numberWithBool:doNotRender]];
                    
                    break;
                case FieldComponentIsDirty:
                    [fieldComponentArray addObject:[NSNumber numberWithBool:
                                                    ( self.editorType == RecordEditorNewRecord 
                                                      && ![SFVUtil isEmpty:[record objectForKey:fieldName]] )                                                   
                                                    ]];
                    break;
                }
            }
        
        // Add this field to our list
        [itemComponents addObject:fieldComponentArray];                  
    }
    
    return itemComponents;
}

- (void)recalculateLayoutComponents {
    int sectionsBefore = ( layoutComponents ? [layoutComponents count] : 0 );
    
    if( sectionTitles )
        [sectionTitles removeAllObjects];
    
    if( layoutComponents )
        [layoutComponents removeAllObjects];
    
    if( [sObjectType isEqualToString:@"CaseComment"] ) {
        NSMutableArray *sectionComponents = [NSMutableArray array];
        
        for( NSString *field in [NSArray arrayWithObjects:@"CommentBody", @"IsPublished", @"ParentId", nil] ) {
            NSMutableArray *bits = [NSMutableArray array];
            
            for( int i = 0; i < FieldNumComponents; i++ )
                switch( i ) {
                    case FieldComponentName:
                        [bits addObject:field];
                        break;
                    case FieldComponentType:
                        [bits addObject:[[SFVAppCache sharedSFVAppCache] field:field
                                                                      onObject:sObjectType
                                                                stringProperty:FieldType]];
                        break;
                    case FieldComponentLabel:
                        [bits addObject:[[SFVAppCache sharedSFVAppCache] field:field
                                                                      onObject:sObjectType
                                                                stringProperty:FieldLabel]];
                        break;
                    case FieldComponentIsRequired:
                        [bits addObject:[NSNumber numberWithBool:[field isEqualToString:@"CommentBody"]]];
                        break;
                    case FieldComponentDoNotRenderInTable:
                        [bits addObject:[NSNumber numberWithBool:[field isEqualToString:@"ParentId"]]];
                        break;
                    case FieldComponentIsDirty:
                        [bits addObject:[NSNumber numberWithBool:![SFVUtil isEmpty:[record objectForKey:field]]]];
                        break;
                }
            
            [sectionComponents addObject:bits];
        }
        
        [sectionTitles addObject:@""];
        [layoutComponents addObject:sectionComponents];
    } else {
        ZKDescribeLayout *layout = [[SFVUtil sharedSFVUtil] layoutForRecord:record];
        
        if( !layout ) // merde.
            return;
        
        // Block activity
        saveButton.enabled = NO;
        
        // 1. Loop through all sections in this page layout
        for( ZKDescribeLayoutSection *section in [layout editLayoutSections] ) {
            
            // Add this section to our section titles, if we're to use it        
            [sectionTitles addObject:( [section useHeading] ? [section heading] : @"" )];
            
            NSMutableArray *sectionComponents = [NSMutableArray array];
            
            // 2a. Add the left side of each row
            for( ZKDescribeLayoutRow *dlr in [section layoutRows]) {
                if( ![dlr layoutItems] || [[dlr layoutItems] count] == 0 )
                    continue;
                
                NSArray *bits = [self parseLayoutForLayoutItem:[[dlr layoutItems] objectAtIndex:0]];
                
                if( bits && [bits count] > 0 )
                    [sectionComponents addObjectsFromArray:bits];
            }
            
            // 2b. Add the right side of each row
            for( ZKDescribeLayoutRow *dlr in [section layoutRows]) {
                if( ![dlr layoutItems] || [[dlr layoutItems] count] == 1 )
                    continue;
                
                for( int i = 1; i < [[dlr layoutItems] count]; i++ ) {
                    NSArray *bits = [self parseLayoutForLayoutItem:[[dlr layoutItems] objectAtIndex:i]];
                    
                    if( bits && [bits count] > 0 )
                        [sectionComponents addObjectsFromArray:bits];
                }
            }
            
            // Retroactively check if there were any valid fields in this section
            if( [sectionComponents count] == 0 )
                [sectionTitles removeLastObject];
            else             
                [layoutComponents addObject:sectionComponents];
        }
    }
    
    [self updateNavBar];
    
    int sectionsAfter = [layoutComponents count];
    
    // enormous fail
    if( sectionsAfter == 0 )
        return;
    
    // Build the field -> index path dictionary
    for( int section = 0; section < [layoutComponents count]; section++ )
        for( int row = 0; row < [[layoutComponents objectAtIndex:section] count]; row++ ) {
            NSIndexPath *ip = [NSIndexPath indexPathForRow:row inSection:section];
            NSArray *bits = [self fieldArrayAtIndexPath:ip];
            
            if( !bits )
                continue;
            
            [fieldsToIndexPaths setObject:ip
                                   forKey:[bits objectAtIndex:FieldComponentName]];
        }
    
    //NSLog(@"layout: %@", layoutComponents);
    //NSLog(@"%@", fieldsToIndexPaths);
    
    NSRange reloadRange = NSMakeRange(0, 0), 
            insertRange = NSMakeRange(0, 0), 
            deleteRange = NSMakeRange(0, 0);
    
    if( sectionsAfter >= sectionsBefore ) {
        insertRange = NSMakeRange( sectionsBefore, sectionsAfter - sectionsBefore );
        reloadRange = NSMakeRange( 0, sectionsBefore );
    } else {
        deleteRange = NSMakeRange( sectionsAfter, sectionsBefore - sectionsAfter );
        reloadRange = NSMakeRange( 0, sectionsAfter );
    }
    
    [recordTable beginUpdates];
    
    if( reloadRange.length > 0 )
        [recordTable reloadSections:[NSIndexSet indexSetWithIndexesInRange:reloadRange]
                   withRowAnimation:UITableViewRowAnimationFade];
    
    if( deleteRange.length > 0 )
        [recordTable deleteSections:[NSIndexSet indexSetWithIndexesInRange:deleteRange]
                   withRowAnimation:UITableViewRowAnimationFade];
    else if( insertRange.length > 0 )
        [recordTable insertSections:[NSIndexSet indexSetWithIndexesInRange:insertRange]
                   withRowAnimation:UITableViewRowAnimationFade];
    
    [recordTable endUpdates];
    
    [DSBezelActivityView removeViewAnimated:YES];
    saveButton.enabled = [self canSave];
}

#pragma mark - View lifecycle

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [self dismissPopoverWithDelegateCall];
    
    [self tryForceResignFirstResponder];
}

- (void)dealloc {
    SFRelease(layoutComponents);
    SFRelease(sectionTitles);
    SFRelease(cancelSheet);
    SFRelease(cancelButton);
    SFRelease(saveButton);
    SFRelease(recordTable);
    SFRelease(record);
    SFRelease(popoverController);
    SFRelease(relatedRecordDictionary);
    SFRelease(activeIndexPath);
    SFRelease(fieldsToIndexPaths);
    SFRelease(errorLabel);
    SFRelease(errorField);
    
    self.currentFirstResponder = nil;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIDeviceOrientationDidChangeNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIKeyboardWillShowNotification
     object:nil];
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIKeyboardWillHideNotification
     object:nil];
    
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)rotationEvent {
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(actualRotationEvent) object:nil];
    [self performSelector:@selector(actualRotationEvent) withObject:nil afterDelay:0.4f];
}

- (void)actualRotationEvent {
    if( popoverController && [popoverController isPopoverVisible] )
        [self showPopover:popoverController fromIndexPath:[recordTable indexPathForSelectedRow]];
}

- (void)keyboardWillChangeFrame:(NSNotification *)notification {
    CGRect keyboardFrame = [[[notification userInfo] objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    //NSLog(@"keyboard frame raw %@", NSStringFromCGRect(keyboardFrame));
    
    UIWindow *window = [[[UIApplication sharedApplication] windows] objectAtIndex:0];
    UIView *mainSubviewOfWindow = window.rootViewController.view;
    CGRect keyboardFrameConverted = [mainSubviewOfWindow convertRect:keyboardFrame fromView:window];
    //NSLog(@"keyboard frame converted %@", NSStringFromCGRect(keyboardFrameConverted));
    
    CGFloat animationDuration = [[[notification userInfo] objectForKey:UIKeyboardAnimationDurationUserInfoKey] doubleValue];
    
    // YES if will show, NO if will hide    
    // the main window is always in portrait
    BOOL keyboardWillShow = keyboardFrameConverted.origin.y <
                                ( [RootViewController isPortrait] 
                                 ? CGRectGetHeight(mainSubviewOfWindow.frame) 
                                 : CGRectGetWidth(mainSubviewOfWindow.frame) );
        
    if( keyboardWillShow == isKeyboardVisible )
        return;
    
    CGRect tableRect = recordTable.frame;
    
    tableRect.origin.y = CGRectGetMaxY(self.navBar.frame);
    tableRect.origin.y += CGRectGetHeight(errorLabel.frame);
    
    tableRect.size.height = CGRectGetHeight(self.view.frame) - tableRect.origin.y;
        
    if( keyboardWillShow )
        tableRect.size.height -= CGRectGetHeight(keyboardFrameConverted);
    
    [self.view bringSubviewToFront:self.navBar];
    
    [UIView animateWithDuration:animationDuration
                     animations:^(void) {
                         [recordTable setFrame:tableRect]; 
                     } completion:^(BOOL finished) {
                         if( ![self isViewLoaded] ) 
                             return;
                         
                         isKeyboardVisible = keyboardWillShow;
                         
                         if( !isKeyboardVisible )
                             return;
                         
                         if( activeIndexPath )
                             [self scrollTableToIndexPath:activeIndexPath animated:YES];
                         else if( [recordTable indexPathForSelectedRow] )
                             [self scrollTableToIndexPath:[recordTable indexPathForSelectedRow] animated:YES];
                     }];
}

- (void)tryForceResignFirstResponder {
    if( self.currentFirstResponder )
        [self.currentFirstResponder resignFirstResponder];
}

#pragma mark - window actions

- (void)setDirtyFieldAtIndexPath:(NSIndexPath *)indexPath {    
    if( !indexPath )
        return;
    
    NSArray *arr = [self fieldArrayAtIndexPath:indexPath];
    
    if( [[arr objectAtIndex:FieldComponentIsDirty] boolValue] )
        return;
        
    NSMutableArray *newArray = [NSMutableArray arrayWithArray:arr];
    [newArray removeObjectAtIndex:FieldComponentIsDirty];
    [newArray insertObject:[NSNumber numberWithBool:YES]
                   atIndex:FieldComponentIsDirty];
    
    if( [[layoutComponents objectAtIndex:indexPath.section] isKindOfClass:[NSMutableArray class]] ) {
        [[layoutComponents objectAtIndex:indexPath.section] removeObjectAtIndex:indexPath.row];
        [[layoutComponents objectAtIndex:indexPath.section] insertObject:newArray
                                                                 atIndex:indexPath.row];
    }
}

- (void)cancelEditing {
    if( cancelSheet && [cancelSheet isVisible] ) {
        [cancelSheet dismissWithClickedButtonIndex:-1 animated:YES];
        SFRelease(cancelSheet);
        return;
    }
    
    [self tryForceResignFirstResponder];
    
    if( isDirty ) {
        cancelSheet = [[UIActionSheet alloc] initWithTitle:nil
                                                  delegate:self
                                         cancelButtonTitle:nil
                                    destructiveButtonTitle:NSLocalizedString(@"Cancel", @"Cancel")
                                         otherButtonTitles:nil];
        
        [cancelSheet showFromBarButtonItem:cancelButton animated:YES];
    } else
        [self dismissWindow];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if( buttonIndex == actionSheet.destructiveButtonIndex )
        [self dismissWindow];
}

- (void)dismissWindow {
    [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
}

- (void)submitRecord {
    [self tryForceResignFirstResponder];
    
    saveButton.enabled = NO;
    [DSBezelActivityView newActivityViewForView:self.view
                                      withLabel:NSLocalizedString(@"Saving...", @"Saving...")];
    
    // Create a sanitized dictionary for insertion
    NSMutableDictionary *toSave = [NSMutableDictionary dictionary];
    
    for( NSArray *section in layoutComponents )
        for( NSArray *fieldComponent in section ) {
            NSString *fieldName = [fieldComponent objectAtIndex:FieldComponentName];
            
            id val = [record objectForKey:fieldName];
            
            if( [val isKindOfClass:[NSDictionary class]] )
                continue;
            
            // Only include invisible fields if they have a value pre-populated.
            if( [[fieldComponent objectAtIndex:FieldComponentDoNotRenderInTable] boolValue] ) {
                if( ![SFVUtil isEmpty:val] ) {
                    NSLog(@"** invis field value: %@:%@", fieldName, val);
                    [toSave setObject:[[val copy] autorelease]
                               forKey:fieldName];
                }
                
                continue;
            }
            
            // yeah, but is it dirty?
            if( kOnlyUpsertDirtyFields
               && ![[fieldComponent objectAtIndex:FieldComponentIsDirty] boolValue] ) {
                NSLog(@"skipping clean field %@", fieldName);
                continue;
            }
            
            // nils out empty fields
            if( !val
               || [val isKindOfClass:[NSNull class]] 
               || ( [val isKindOfClass:[NSString class]] && [val isEqualToString:@""] ) ) {
                
                // nil value in a required field? don't include it in the response
                if( [[fieldComponent objectAtIndex:FieldComponentIsRequired] boolValue] ) {
                    NSLog(@"** NIL REQUIRED FIELD %@", fieldName);
                    continue;
                }
                
                if( [[fieldComponent objectAtIndex:FieldComponentType] isEqualToString:@"boolean"] )
                    [toSave setObject:[NSNumber numberWithBool:NO] 
                               forKey:fieldName];
                else
                    [toSave setObject:[NSNull null] 
                               forKey:fieldName];
                
                NSLog(@"** nil value for field: %@", fieldName);
                continue;
            }
            
            [toSave setObject:[[val copy] autorelease]
                       forKey:fieldName];
        }
    
    SFRestFailBlock failBlock = ^(NSError *err) {
        [DSBezelActivityView removeViewAnimated:YES];
        saveButton.enabled = YES;
        
        if( ![self isViewLoaded] ) 
            return;
        
        if( errorField )
            SFRelease(errorField);
        
        if( [[[err userInfo] objectForKey:@"fields"] count] > 0 ) {
            errorField = [[[[err userInfo] objectForKey:@"fields"] objectAtIndex:0] copy];
        
            errorLabel.text = [NSString stringWithFormat:@"%@: %@",
                               [[SFVAppCache sharedSFVAppCache] field:errorField
                                                             onObject:sObjectType
                                                       stringProperty:FieldLabel],
                               [[err userInfo] objectForKey:@"message"]];
        } else
            errorLabel.text = [[err userInfo] objectForKey:@"message"];
        
        [[SFAnalytics sharedInstance] tagEventOfType:SFVUserReceivedSaveError
                                          attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                                     errorLabel.text, @"Message",
                                                                     sObjectType, @"Object",
                                                                     [SFAnalytics bucketStringForNumber:[NSNumber numberWithInt:[toSave count]]
                                                                                             bucketSize:5], @"Field Count",
                                                                     nil]];
        
        CGSize s = [errorLabel.text sizeWithFont:errorLabel.font
                               constrainedToSize:CGSizeMake( CGRectGetWidth(recordTable.frame) - 10, 999 )];
        
        if( s.height < recordTable.rowHeight )
            s.height = recordTable.rowHeight;
        
        [UIView animateWithDuration:0.25f
                         animations:^(void) {
                             [errorLabel setFrame:CGRectMake( floorf( ( CGRectGetWidth(self.view.frame) - s.width ) / 2.0f ), 
                                                             CGRectGetMaxY(self.navBar.frame), s.width, s.height )];
                             [recordTable setFrame:CGRectMake(0, CGRectGetMaxY(errorLabel.frame), 
                                                              CGRectGetWidth(recordTable.frame), CGRectGetHeight(self.view.frame) - CGRectGetMaxY(errorLabel.frame))];
                         } 
                         completion:^(BOOL finished) {
                             if( errorField ) {
                                 [self scrollTableToIndexPath:[fieldsToIndexPaths objectForKey:errorField]
                                                     animated:YES];
                                 [self tableView:recordTable didSelectRowAtIndexPath:[fieldsToIndexPaths objectForKey:errorField]];
                             }
                         }];
    };
    
    SFRestDictionaryResponseBlock completeBlock = ^(NSDictionary *dict) {        
        if( ![self isViewLoaded] ) 
            return;
        
        [DSBezelActivityView removeViewAnimated:YES];
        saveButton.enabled = YES;
        
        if( self.editorType == RecordEditorEditRecord )
            [[SFAnalytics sharedInstance] tagEventOfType:SFVUserEditedRecord
                                              attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          sObjectType, @"Object",
                                                          [SFAnalytics bucketStringForNumber:[NSNumber numberWithInt:[toSave count]]
                                                                                  bucketSize:5], @"Field Count",
                                                          nil]];
        else
            [[SFAnalytics sharedInstance] tagEventOfType:SFVUserCreatedRecord
                                              attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          sObjectType, @"Object",
                                                          [SFAnalytics bucketStringForNumber:[NSNumber numberWithInt:[toSave count]]
                                                                                  bucketSize:5], @"Field Count",
                                                          nil]];
        
        [self.rootViewController refreshAllSubNavs];
        
        if( [record objectForKey:@"Id"] )
            [self.detailViewController clearFlyingWindowsForRecordId:[record objectForKey:@"Id"]];
        else {
            [record setObject:[dict objectForKey:@"id"]
                       forKey:@"Id"];
            
            [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:YES];
            [self.detailViewController addFlyingWindow:FlyingWindowRecordOverview withArg:record];
        }
    };
        
    if( self.editorType == RecordEditorEditRecord )
        [[SFRestAPI sharedInstance] performUpdateWithObjectType:sObjectType
                                                       objectId:[record objectForKey:@"Id"]
                                                         fields:toSave
                                                      failBlock:failBlock
                                                  completeBlock:completeBlock];
    else
        [[SFRestAPI sharedInstance] performCreateWithObjectType:sObjectType
                                                         fields:toSave
                                                      failBlock:failBlock
                                                  completeBlock:completeBlock];
}

- (void)deleteRecord:(id)sender {
    [PRPAlertView showWithTitle:[NSString stringWithFormat:@"Delete %@",
                                 [[SFVAppCache sharedSFVAppCache] labelForSObject:[record objectForKey:kObjectTypeKey] usePlural:NO]]
                        message:[NSString stringWithFormat:@"Delete %@?",
                                 [[SFVAppCache sharedSFVAppCache] nameForSObject:record]]
                    cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                    cancelBlock:nil
                     otherTitle:NSLocalizedString(@"Delete", @"Delete")
                     otherBlock:^(void) {   
                         // Cover up this window
                         [DSBezelActivityView newActivityViewForView:self.view];
                         
                         [[SFRestAPI sharedInstance] performDeleteWithObjectType:[record objectForKey:kObjectTypeKey]
                                                                        objectId:[record objectForKey:@"Id"]
                                                                       failBlock:^(NSError *err) {
                                                                           [DSBezelActivityView removeViewAnimated:NO];
                                                                           [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                                                                                               message:[[err userInfo] objectForKey:@"message"]
                                                                                           buttonTitle:NSLocalizedString(@"OK", @"OK")];
                                                                       }
                                                                   completeBlock:^(NSDictionary *dict) {
                                                                       [DSBezelActivityView removeViewAnimated:YES];
                                                                       
                                                                       // remove recent record
                                                                       [[SFVUtil sharedSFVUtil] removeRecentRecordWithId:[record objectForKey:@"Id"]];
                                                                       
                                                                       // Refresh all subnavs in the stack
                                                                       [self.rootViewController refreshAllSubNavs];
                                                                       
                                                                       // clears all our windows
                                                                       [self.detailViewController eventLogInOrOut];                                                                       
                                                                   }];
                     }];
}

- (BOOL)canSave {
    // we can save if every required field has a value
    /*for( NSArray *section in layoutComponents )
        for( NSArray *fieldComponent in section ) {
            if( ![[fieldComponent objectAtIndex:FieldComponentIsRequired] boolValue] )
                continue;
            
            // I don't care what anyone says, booleans ought not be required
            if( [[fieldComponent objectAtIndex:FieldComponentType] isEqualToString:@"boolean"] )
                continue;
            
            NSString *fieldName = [fieldComponent objectAtIndex:FieldComponentName];
            
            id val = [record objectForKey:fieldName];
            
            if( !val || [val isKindOfClass:[NSNull class]] )
                return NO;
            
            if( [[record objectForKey:fieldName] isKindOfClass:[NSString class]] 
                && [[record objectForKey:fieldName] isEqualToString:@""] )
                return NO;
        }*/
    
    // Nevermind...let the API sort it all out.
    return YES;
}

#pragma mark - address book lookup delegate 

- (void)showAddressBookPicker:(id)sender {
    if( popoverController && [popoverController isPopoverVisible] ) {
        [self dismissPopoverWithDelegateCall];
        return;
    }
    
    ABPeoplePickerNavigationController *picker = [[ABPeoplePickerNavigationController alloc] init];
    picker.peoplePickerDelegate = self;
    
    popoverController = [[UIPopoverController alloc] initWithContentViewController:picker];
    popoverController.delegate = self;
    [picker release];
    
    [popoverController presentPopoverFromBarButtonItem:sender
                              permittedArrowDirections:UIPopoverArrowDirectionUp
                                              animated:YES];
}

- (void)peoplePickerNavigationControllerDidCancel:(ABPeoplePickerNavigationController *)peoplePicker {
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker 
      shouldContinueAfterSelectingPerson:(ABRecordRef)person {
    NSMutableArray *indexesToReload = [NSMutableArray array];
        
    NSDictionary *stringProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                      @"FirstName", [NSNumber numberWithInt:kABPersonFirstNameProperty],
                                      @"LastName", [NSNumber numberWithInt:kABPersonLastNameProperty],
                                      @"Title", [NSNumber numberWithInt:kABPersonJobTitleProperty],
                                      @"Salutation", [NSNumber numberWithInt:kABPersonPrefixProperty],
                                      nil];
        
    for( NSNumber *property in [stringProperties allKeys] ) {
        NSString *field = [stringProperties objectForKey:property];
        NSString *prop = (NSString *)ABRecordCopyValue(person, [property intValue]);
        
        if( ![fieldsToIndexPaths objectForKey:field] || !prop || [prop length] == 0 ) {
            [prop release];
            continue;
        }
        
        [record setObject:prop
                   forKey:field];
        [indexesToReload addObject:[fieldsToIndexPaths objectForKey:field]];
        
        [prop release];
    }
    
    // Phone
    ABMultiValueRef phones = (ABMultiValueRef) ABRecordCopyValue(person, kABPersonPhoneProperty);
    if( [fieldsToIndexPaths objectForKey:@"Phone"] && ABMultiValueGetCount(phones) > 0 ) {
        [record setObject:[(NSString *)ABMultiValueCopyValueAtIndex(phones, 0) autorelease]
                   forKey:@"Phone"];
        [indexesToReload addObject:[fieldsToIndexPaths objectForKey:@"Phone"]];        
    }
    CFRelease(phones);
    
    // Email
    ABMultiValueRef emails = (ABMultiValueRef) ABRecordCopyValue(person, kABPersonEmailProperty);
    if( [fieldsToIndexPaths objectForKey:@"Email"] && ABMultiValueGetCount(emails) > 0 ) {
        NSString *firstEmail = (NSString *)ABMultiValueCopyValueAtIndex(emails, 0);
        
        if( firstEmail ) {
            [record setObject:firstEmail
                       forKey:@"Email"];
            [indexesToReload addObject:[fieldsToIndexPaths objectForKey:@"Email"]];
        }
        
        [firstEmail release];
    }
    CFRelease(emails);
    
    // Address
    ABMultiValueRef address = (ABMultiValueRef) ABRecordCopyValue(person, kABPersonAddressProperty);
    if( ABMultiValueGetCount(address) > 0 ) {
        CFDictionaryRef dict = ABMultiValueCopyValueAtIndex(address, 0);
        NSDictionary *addressProperties = [NSDictionary dictionaryWithObjectsAndKeys:
                                           @"MailingStreet", kABPersonAddressStreetKey,
                                           @"MailingCity", kABPersonAddressCityKey,
                                           @"MailingState", kABPersonAddressStateKey,
                                           @"MailingPostalCode", kABPersonAddressZIPKey,
                                           @"MailingCountry", kABPersonAddressCountryKey,
                                           nil];
            
        for( NSString *property in [addressProperties allKeys] ) {
            NSString *field = [addressProperties objectForKey:property];
            NSString *prop = (NSString *)CFDictionaryGetValue(dict, property);
            
            if( ![fieldsToIndexPaths objectForKey:field] || !prop )
                continue;
            
            [record setObject:prop
                       forKey:field];
            [indexesToReload addObject:[fieldsToIndexPaths objectForKey:field]];
        }
        
        CFRelease(dict);
    }
    CFRelease(address);
    
    [self dismissPopoverWithDelegateCall];
    
    // Mark all these fields dirty
    for( NSIndexPath *path in indexesToReload )
        [self setDirtyFieldAtIndexPath:path];
    
    [recordTable reloadRowsAtIndexPaths:indexesToReload
                       withRowAnimation:UITableViewRowAnimationFade];
        
    return NO;
}

- (BOOL)peoplePickerNavigationController:(ABPeoplePickerNavigationController *)peoplePicker 
      shouldContinueAfterSelectingPerson:(ABRecordRef)person 
                                property:(ABPropertyID)property 
                              identifier:(ABMultiValueIdentifier)identifier {
    return NO;
}

#pragma mark - object lookup delegate

- (void)objectLookupDidSelectRecord:(ObjectLookupController *)objectLookupController record:(NSDictionary *)rec {
    if( popoverController && [popoverController isPopoverVisible] ) {
        [self dismissPopoverWithDelegateCall];
    }
    
    // save ID in the record for this field
    NSString *fieldName = [[self fieldArrayAtIndexPath:[recordTable indexPathForSelectedRow]] objectAtIndex:FieldComponentName];
    
    if( [SFVUtil isEmpty:[record objectForKey:fieldName]] 
        || ![[record objectForKey:fieldName] isEqualToString:[rec objectForKey:@"Id"]] )
        isDirty = YES;
    
    [record setObject:[rec objectForKey:@"Id"] forKey:fieldName];
    
    // save its name in our related record dictionary
    [relatedRecordDictionary setObject:[[SFVAppCache sharedSFVAppCache] nameForSObject:rec]
                                forKey:[rec objectForKey:@"Id"]];
    
    // reload this row
    [self setDirtyFieldAtIndexPath:[recordTable indexPathForSelectedRow]];
    [recordTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:[recordTable indexPathForSelectedRow]]
                       withRowAnimation:UITableViewRowAnimationRight];
    
    saveButton.enabled = [self canSave];
}

#pragma mark - text cell delegate

- (void)textCellValueChanged:(TextCell *)cell {    
    if( !cell )
        return;
    
    // save the updated value in our dictionary
    NSIndexPath *indexPath = [recordTable indexPathForCell:cell];
    
    // this can happen if we scroll the tableview quickly
    if( !indexPath )
        return;
    
    if( activeIndexPath )
        SFRelease(activeIndexPath);
    
    activeIndexPath = [indexPath copy];
    
    [self scrollTableToIndexPath:activeIndexPath animated:NO];
        
    NSString *fieldName = [[self fieldArrayAtIndexPath:indexPath] objectAtIndex:FieldComponentName];  
    
    [record setObject:[cell getCellText]
               forKey:fieldName];
    
    if( self.editorType != RecordEditorNewRecord 
        && [fieldName isEqualToString:[[SFVAppCache sharedSFVAppCache] nameFieldForsObject:sObjectType]] )
        [self updateNavBar];
    
    saveButton.enabled = [self canSave];
    
    [self setDirtyFieldAtIndexPath:indexPath];
}

- (BOOL)textCellShouldReturn:(TextCell *)cell {
    /*NSIndexPath *indexPath = [recordTable indexPathForCell:cell];
    
    if( !indexPath )
        return YES;
    
    // Find the next valid text cell
    for( int section = indexPath.section; section < [recordTable numberOfSections]; section++ )
        for( int row = ( section == indexPath.section ? indexPath.row : 0 ); row < [recordTable numberOfRowsInSection:section]; row++ ) {
            NSIndexPath *path = [NSIndexPath indexPathForRow:row inSection:section];
            
            if( [path compare:indexPath] == NSOrderedSame )
                continue;
            
            NSArray *arr = [self fieldArrayAtIndexPath:path];
            
            if( ![[NSArray arrayWithObjects:@"date", @"datetime", @"picklist", @"multipicklist", @"reference", @"boolean", nil] 
                  containsObject:[arr objectAtIndex:FieldComponentType]] ) {      
                [self scrollTableToIndexPath:path animated:NO];
                
                TextCell *c = (TextCell *)[recordTable cellForRowAtIndexPath:path];
                
                if( c ) {
                    [c becomeFirstResponder];
                    return NO;
                }
                
                return YES;
            }
        }*/
    
    return YES;
}

- (void)textCellDidBecomeFirstResponder:(TextCell *)cell {
    if( cell ) {        
        if( activeIndexPath )
            SFRelease( activeIndexPath );
        
        if( [recordTable indexPathForCell:cell] )
            activeIndexPath = [[recordTable indexPathForCell:cell] copy];
        
        self.currentFirstResponder = ( cell.cellType == TextViewCell ? cell.textView : cell.textField );
    }
}

- (void)textCellDidEndEditing:(TextCell *)cell {
    self.currentFirstResponder = nil;
}

#pragma mark - popover delegate

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)popoverController {
    [recordTable deselectRowAtIndexPath:[recordTable indexPathForSelectedRow] animated:YES];
    return YES;
}

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)pop {
    SFRelease(popoverController);
}

- (void)dismissPopoverWithDelegateCall {
    if( popoverController ) {
        [popoverController dismissPopoverAnimated:YES];
        [popoverController.delegate popoverControllerDidDismissPopover:popoverController];
    }
}

#pragma mark - picklist delegate

- (void)picklistPicker:(PicklistPicker *)picker didSelectValue:(NSString *)value label:(NSString *)label {
    isDirty = YES;
    
    if( !picker.allowsMultiSelect ) {
        [self dismissPopoverWithDelegateCall];
        
        [record setObject:value
                   forKey:picker.fieldName];
        
        if( [picker.fieldName isEqualToString:kRecordTypeIdField] ) {            
            // we've changed the record type
            [relatedRecordDictionary setObject:label
                                        forKey:value];
            
            [record removeObjectForKey:kRecordTypeRelationshipField];
            [record setObject:value forKey:kRecordTypeIdField];
            
            [self recalculateLayoutComponents];
            return;
        }
        
        [self reloadDependentFieldsForControllingIndexPath:[recordTable indexPathForSelectedRow]];
        
        [recordTable deselectRowAtIndexPath:[recordTable indexPathForSelectedRow]
                                   animated:YES];
    } else {
        NSString *currentVal = [record objectForKey:picker.fieldName];
        
        if( [SFVUtil isEmpty:currentVal] )
            currentVal = value;
        else
            currentVal = [currentVal stringByAppendingFormat:@"%@%@",
                            kSalesforcePicklistValueSeparator,
                            value];
        
        [record setObject:currentVal
                   forKey:picker.fieldName];
        
        TextCell *cell = (TextCell *)[recordTable cellForRowAtIndexPath:[recordTable indexPathForSelectedRow]];
        
        [cell setCellText:[[cell getCellText] stringByAppendingFormat:@"%@%@",
                           ( [SFVUtil isEmpty:[cell getCellText]] ? @"" : kSalesforcePicklistValueSeparator ),
                           label]];
        
        [self setDirtyFieldAtIndexPath:[recordTable indexPathForSelectedRow]];
    }
    
    saveButton.enabled = [self canSave];
}

- (void)picklistPicker:(PicklistPicker *)picker didDeselectValue:(NSString *)value label:(NSString *)label {    
    [self setDirtyFieldAtIndexPath:[recordTable indexPathForSelectedRow]];
    
    if( !picker.allowsMultiSelect ) {
        [self dismissPopoverWithDelegateCall];
        [recordTable deselectRowAtIndexPath:[recordTable indexPathForSelectedRow] animated:YES];
        return;
    }
    
    isDirty = YES;
    
    NSString *currentValues = [record objectForKey:picker.fieldName];
    
    NSMutableArray *bits = [NSMutableArray arrayWithArray:[currentValues componentsSeparatedByString:kSalesforcePicklistValueSeparator]];
    [bits removeObject:value];
    
    NSString *newValues = [bits componentsJoinedByString:kSalesforcePicklistValueSeparator];
    
    [record setObject:newValues forKey:picker.fieldName];
    
    TextCell *cell = (TextCell *)[recordTable cellForRowAtIndexPath:[recordTable indexPathForSelectedRow]];
    
    NSString *currentLabels = [cell getCellText];
    
    NSMutableArray *currentLabelBits = [NSMutableArray arrayWithArray:[currentLabels componentsSeparatedByString:kSalesforcePicklistValueSeparator]];
    [currentLabelBits removeObject:label];    
    
    [cell setCellText:[currentLabelBits componentsJoinedByString:kSalesforcePicklistValueSeparator]];
}

#pragma mark - datetime picker delegate

- (void)dateTimePicker:(DateTimePicker *)picker didChangeToDate:(NSDate *)newDate {    
    isDirty = YES;        

    NSIndexPath *indexPath = [recordTable indexPathForSelectedRow];
    NSArray *fieldArray = [self fieldArrayAtIndexPath:indexPath];
    
    [record setObject:[SFVUtil SOQLDatetimeFromDate:newDate 
                                         isDateTime:[[fieldArray objectAtIndex:FieldComponentType] isEqualToString:@"datetime"]]
               forKey:[fieldArray objectAtIndex:FieldComponentName]];
    
    [recordTable reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                       withRowAnimation:UITableViewRowAnimationNone];
    
    [recordTable selectRowAtIndexPath:indexPath
                             animated:NO
                       scrollPosition:UITableViewScrollPositionNone];
        
    
    saveButton.enabled = [self canSave];
    [self setDirtyFieldAtIndexPath:[recordTable indexPathForSelectedRow]];
}

- (void)dateTimePickerDidClearFieldValue:(DateTimePicker *)picker {
    [self clearSelectedField];
}

#pragma mark - table cell utility functions

- (void) scrollTableToIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {   
    if( !indexPath )
        return;
    
    if( [recordTable isDragging] || [recordTable isDecelerating] || [recordTable isTracking] )
        return;
    
    // Calculate the current location of this cell
    CGRect rect = [recordTable rectForRowAtIndexPath:indexPath];
    
    // Adjust for section header
    rect.origin.y -= [self tableView:recordTable heightForHeaderInSection:indexPath.section];
        
    [recordTable setContentOffset:rect.origin
                         animated:animated];
}

- (void) showPopover:(UIPopoverController *)pop fromIndexPath:(NSIndexPath *)indexPath {
    BOOL isVisible = NO;
    
    // Do not redisplay address book pickers
    if( [[pop contentViewController] isKindOfClass:[ABPeoplePickerNavigationController class]] )
        return;
        
    for( NSIndexPath *path in [recordTable indexPathsForVisibleRows] )
        if( [path compare:indexPath] == NSOrderedSame ) {
            isVisible = YES;
            break;
        }
    
    if( !isVisible )
        [self scrollTableToIndexPath:indexPath animated:NO];
    
    // Calculate the popover launching point
    CGRect popRect = [recordTable rectForRowAtIndexPath:indexPath];
    popRect.origin.y += CGRectGetHeight(self.navBar.frame);
    popRect.origin.y -= [recordTable contentOffset].y;
    popRect.origin.y += CGRectGetHeight(errorLabel.frame);
    
    pop.delegate = self;
    
    [pop presentPopoverFromRect:popRect
                         inView:self.view
       permittedArrowDirections:UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight
                       animated:NO];
}

- (NSArray *) fieldArrayAtIndexPath:(NSIndexPath *)indexPath {
    if( !indexPath || indexPath.section >= [layoutComponents count] )
        return nil;
    
    NSArray *bits = [layoutComponents objectAtIndex:indexPath.section];
    int target = indexPath.row;
    
    for( int i = 0; i < [bits count]; i++ ) {
        if( ![[[bits objectAtIndex:i] objectAtIndex:FieldComponentDoNotRenderInTable] boolValue] )
            target--;
        
        if( target < 0 )
            return [bits objectAtIndex:i];
    }
    
    return nil;
}

- (void)clearSelectedField {
    NSArray *fieldArray = [self fieldArrayAtIndexPath:[recordTable indexPathForSelectedRow]];
    NSString *fieldName = [fieldArray objectAtIndex:FieldComponentName];
    
    if( popoverController && [popoverController isPopoverVisible] ) {
        [self dismissPopoverWithDelegateCall];
    }
    
    if( [record objectForKey:fieldName] ) {        
        if( [[fieldArray objectAtIndex:FieldComponentType] isEqualToString:@"reference"] ) {
            [relatedRecordDictionary removeObjectForKey:[record objectForKey:fieldName]];
            [record removeObjectForKey:[[SFVAppCache sharedSFVAppCache] field:fieldName
                                                                     onObject:sObjectType
                                                               stringProperty:FieldRelationshipName]];
        }
        
        [record setObject:@"" forKey:fieldName];
    }
    
    [self reloadDependentFieldsForControllingIndexPath:[recordTable indexPathForSelectedRow]];
    
    saveButton.enabled = [self canSave];
}

- (void)reloadDependentFieldsForControllingIndexPath:(NSIndexPath *)indexPath {
    if( !indexPath )
        return;
    
    NSMutableArray *reloadRows = [NSMutableArray arrayWithObject:indexPath];
    NSArray *fieldBits = [self fieldArrayAtIndexPath:indexPath];
    
    for( NSString *field in [fieldsToIndexPaths allKeys] )
        if( [[SFVAppCache sharedSFVAppCache] doesField:field
                                              onObject:sObjectType
                                          haveProperty:FieldIsDependentPicklist]
           && [[[SFVAppCache sharedSFVAppCache] field:field
                                             onObject:sObjectType
                                       stringProperty:FieldControllingFieldName] isEqualToString:[fieldBits objectAtIndex:FieldComponentName]] ) {
            [record removeObjectForKey:field];
            [reloadRows addObject:[fieldsToIndexPaths objectForKey:field]];
        } else if( [sObjectType isEqualToString:@"Event"]
                  && [[fieldBits objectAtIndex:FieldComponentName] isEqualToString:@"IsAllDayEvent"]
                  && [[NSArray arrayWithObjects:@"StartDateTime", @"EndDateTime", nil] containsObject:field] ) {
            [reloadRows addObject:[fieldsToIndexPaths objectForKey:field]];
            
            NSString *currentVal = [record objectForKey:field];
            
            // Convert to date or datetime
            if( ![SFVUtil isEmpty:currentVal] ) {
                currentVal = [SFVUtil SOQLDatetimeFromDate:[SFVUtil dateFromSOQLDatetime:currentVal] 
                                                isDateTime:![[record objectForKey:@"IsAllDayEvent"] boolValue]];
                [record setObject:currentVal
                           forKey:field];
            }
        }
    
    if( [reloadRows count] > 0 ) {
        [recordTable reloadRowsAtIndexPaths:reloadRows
                           withRowAnimation:UITableViewRowAnimationFade];
        
        for( NSIndexPath *path in reloadRows )
            [self setDirtyFieldAtIndexPath:path];
    }
}

#pragma mark - table view delegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {    
    if( recordTable && popoverController && [popoverController isPopoverVisible] )
        [self showPopover:popoverController fromIndexPath:[recordTable indexPathForSelectedRow]];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if( [[self tableView:tableView titleForHeaderInSection:section] isEqualToString:@""] )
        return 0;
    
    return [UIImage imageNamed:@"sectionheader.png"].size.height;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [sectionTitles objectAtIndex:section];
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if( [[self tableView:tableView titleForHeaderInSection:section] isEqualToString:@""] )
        return nil;
    
    UIImageView *sectionView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sectionheader.png"]];
    
    UILabel *customLabel = [[UILabel alloc] initWithFrame:CGRectMake(10, -1, CGRectGetWidth(recordTable.frame), sectionView.image.size.height )];
    customLabel.textColor = [UIColor whiteColor];
    customLabel.text = [self tableView:tableView titleForHeaderInSection:section];    
    customLabel.font = [UIFont boldSystemFontOfSize:16];
    customLabel.backgroundColor = [UIColor clearColor];
    [sectionView addSubview:customLabel];
    [customLabel release];
    
    return [sectionView autorelease];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [layoutComponents count];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    int i = 0; 
    NSArray *bits = [layoutComponents objectAtIndex:section];
    
    for( int x = 0; x < [bits count]; x++ )
        if( ![[[bits objectAtIndex:x] objectAtIndex:FieldComponentDoNotRenderInTable] boolValue] )
            i++;
    
    return i;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *fieldType = [[self fieldArrayAtIndexPath:indexPath] objectAtIndex:FieldComponentType];
    
    if( [fieldType isEqualToString:@"textarea"] )
        return tableView.rowHeight * 2;
    
    return tableView.rowHeight;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {    
    NSArray *fieldArray = [self fieldArrayAtIndexPath:indexPath];
    TextCell *cell = [TextCell cellForTableView:recordTable];
    cell.delegate = self;
    
    // Field label
    cell.textLabel.text = [fieldArray objectAtIndex:FieldComponentLabel];
    [cell setMaxLabelWidth:floorf( CGRectGetWidth(recordTable.frame) * 0.35f )];
    [cell setPlaceholder:nil];
    
    // boolean cells use the check images
    if( [[fieldArray objectAtIndex:FieldComponentType] isEqualToString:@"boolean"] ) {
        [cell setTextCellType:TextFieldCell];
        [cell setCellText:@""];
        
        if( [[record objectForKey:[fieldArray objectAtIndex:FieldComponentName]] boolValue] )
            cell.imageView.image = [UIImage imageNamed:@"check_yes.png"];
        else
            cell.imageView.image = [UIImage imageNamed:@"check_no.png"];
    } else {
        cell.imageView.image = nil;
        
        // every other type of field has some kind of text to display
        if( [[fieldArray objectAtIndex:FieldComponentType] isEqualToString:@"textarea"] ) {
            [cell setTextCellType:TextViewCell];
            [cell setReturnKeyType:UIReturnKeyDefault];
            cell.allowTextViewCarriageReturns = YES;
        } else {
            [cell setTextCellType:TextFieldCell];
            [cell setReturnKeyType:UIReturnKeyDone];
            cell.allowTextViewCarriageReturns = NO;
        }
    
        NSString *fieldName = [fieldArray objectAtIndex:FieldComponentName];
        NSString *fieldType = [fieldArray objectAtIndex:FieldComponentType];
        
        // set the max length for this field based on its type
        if( [[NSArray arrayWithObjects:@"string", @"textarea", @"url", @"email", nil] containsObject:fieldType] )
            [cell setMaxLength:[[SFVAppCache sharedSFVAppCache] field:fieldName
                                                             onObject:sObjectType
                                                       numberProperty:FieldLength]];
        else if( [fieldType isEqualToString:@"int"] )
            [cell setMaxLength:[[SFVAppCache sharedSFVAppCache] field:fieldName
                                                             onObject:sObjectType
                                                       numberProperty:FieldDigits]];
        else if( [[NSArray arrayWithObjects:@"double", @"percent", @"currency", nil] containsObject:fieldType] )
            [cell setMaxLength:[[SFVAppCache sharedSFVAppCache] field:fieldName
                                                             onObject:sObjectType
                                                       numberProperty:FieldPrecision]];
        else // this is a sensible default, right?
            [cell setMaxLength:255];
        
        // Record value for this field 
        [cell setCellText:@""];
        
        id val = [record objectForKey:fieldName];
        
        if( val && [[fieldArray objectAtIndex:FieldComponentType] isEqualToString:@"reference"] )
            [cell setCellText:[relatedRecordDictionary objectForKey:[record objectForKey:fieldName]]];
        else if( val ) {
            if( [val isKindOfClass:[NSString class]] )
                [cell setCellText:val];
            else if( [val isKindOfClass:[NSNumber class]] )
                [cell setCellText:[val stringValue]];
        }
        
        // Placeholder
        if( [[fieldArray objectAtIndex:FieldComponentIsRequired] boolValue] )
           [cell setPlaceholder:NSLocalizedString(@"Required", @"Required")];
        
        // set up keyboard and validation types for those fields that are directly editable
        if( [fieldType isEqualToString:@"url"] ) {
            [cell setKeyboardType:UIKeyboardTypeURL];
            [cell setValidationType:ValidateURL];
        } else if( [fieldType isEqualToString:@"email"] ) {
            [cell setKeyboardType:UIKeyboardTypeEmailAddress];
            [cell setValidationType:ValidateNone];
        } else if( [fieldType isEqualToString:@"phone"] ) {
            [cell setKeyboardType:UIKeyboardTypePhonePad];
            [cell setValidationType:ValidatePhone];
        } else if( [fieldType isEqualToString:@"currency"] 
                  || [fieldType isEqualToString:@"double"] 
                  || [fieldType isEqualToString:@"percent"] ) {
            [cell setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
            [cell setValidationType:ValidateDecimal];
        } else if( [fieldType isEqualToString:@"int"] ) {
            [cell setKeyboardType:UIKeyboardTypeNumbersAndPunctuation];
            [cell setValidationType:ValidateInteger];
        } else {
            [cell setKeyboardType:UIKeyboardTypeDefault];
            [cell setValidationType:ValidateNone];
        }
        
        // set up selectable/not selectable based on which fields are popovers
        if( [[NSArray arrayWithObjects:@"reference", @"picklist", @"multipicklist", @"date", @"datetime", @"combobox", nil] containsObject:fieldType] ) {
            cell.selectionStyle = UITableViewCellSelectionStyleBlue;
            cell.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
            cell.textField.enabled = NO;
            
            if( [[NSArray arrayWithObjects:@"date", @"datetime", nil] containsObject:fieldType] )
                [cell setCellText:[[SFVUtil sharedSFVUtil] textValueForField:fieldName
                                                              withDictionary:record]];
        } else {
            cell.selectionStyle = UITableViewCellSelectionStyleNone;    
            cell.selectedBackgroundView = nil;
            cell.textField.enabled = YES;
        }
    }
        
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSArray *fieldArray = [self fieldArrayAtIndexPath:indexPath];
    NSString *fieldName = [fieldArray objectAtIndex:FieldComponentName];
    NSString *fieldType = [fieldArray objectAtIndex:FieldComponentType];
            
    // hide the popover, if visible
    if( popoverController && [popoverController isPopoverVisible] ) {
        [self dismissPopoverWithDelegateCall];
        [tableView deselectRowAtIndexPath:[tableView indexPathForSelectedRow] animated:NO];
    }
    
    if( activeIndexPath )
        SFRelease(activeIndexPath);
    
    activeIndexPath = [indexPath copy];

    if( [fieldName isEqualToString:kRecordTypeIdField] 
        || [fieldType isEqualToString:@"picklist"] 
        || [fieldType isEqualToString:@"combobox"]
        || [fieldType isEqualToString:@"multipicklist"] ) {  
        
        // If this is a dependent picklist, and if the controlling object is empty,
        // we cannot yet edit this picklist
        if( [[SFVAppCache sharedSFVAppCache] doesField:fieldName
                                              onObject:sObjectType
                                          haveProperty:FieldIsDependentPicklist]
            && [SFVUtil isEmpty:[record objectForKey:[[SFVAppCache sharedSFVAppCache] field:fieldName
                                                                                   onObject:sObjectType
                                                                             stringProperty:FieldControllingFieldName]]] ) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
        }
        
        PicklistPicker *picker = nil;
        
        if( [fieldName isEqualToString:kRecordTypeIdField] )
            picker = [[PicklistPicker alloc] initWithRecordTypeListForObject:sObjectType
                                                      withSelectedRecordType:[record objectForKey:kRecordTypeIdField]];
        else
            picker = [[PicklistPicker alloc] initWithPicklistField:fieldName
                                                          onRecord:record
                                                withSelectedValues:( [SFVUtil isEmpty:[record objectForKey:fieldName]] 
                                                                    ? nil 
                                                                    : [[record objectForKey:fieldName] componentsSeparatedByString:kSalesforcePicklistValueSeparator] )];
        
        picker.title = [fieldArray objectAtIndex:FieldComponentLabel];
        picker.delegate = self;
        picker.allowsMultiSelect = [fieldType isEqualToString:@"multipicklist"];
        picker.allowsCustomValue = [fieldType isEqualToString:@"combobox"];
        
        if( picker.allowsCustomValue && ![[SFVUtil sharedSFVUtil] isValue:[record objectForKey:fieldName]
                                                               inPicklist:fieldName
                                                                 onObject:sObjectType] )
            picker.initialCustomText = [record objectForKey:fieldName];
        
        if( ![SFVUtil isEmpty:[record objectForKey:fieldName]]
            && ![[fieldArray objectAtIndex:FieldComponentIsRequired] boolValue] )
            picker.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
                                                     initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                     target:self
                                                     action:@selector(clearSelectedField)] autorelease];
        
        [picker reloadAndResize];
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:picker];
        [picker release];
        
        popoverController = [[UIPopoverController alloc] initWithContentViewController:nav];
        [nav release];
        
        [self tryForceResignFirstResponder];
                        
        [self showPopover:popoverController fromIndexPath:indexPath];        
    } else if( [fieldType isEqualToString:@"boolean"] ) {
        BOOL oppositeValue = ![[record objectForKey:fieldName] boolValue];
        [record setObject:[NSNumber numberWithBool:oppositeValue] forKey:fieldName];
        saveButton.enabled = [self canSave];
        
        [self tryForceResignFirstResponder];
        
        [self reloadDependentFieldsForControllingIndexPath:indexPath];
    } else if( [fieldType isEqualToString:@"date"] || [fieldType isEqualToString:@"datetime"] ) {
        DateTimePicker *dateTimePicker = [DateTimePicker dateTimePicker];
        dateTimePicker.dateTimeDelegate = self;
        
        [dateTimePicker setDateTimePickerTitle:[[SFVAppCache sharedSFVAppCache] field:fieldName
                                                                             onObject:[record objectForKey:kObjectTypeKey]
                                                                       stringProperty:FieldLabel]];
        
        if( [[[SFVAppCache sharedSFVAppCache] field:fieldName
                                           onObject:[record objectForKey:kObjectTypeKey]
                                     stringProperty:FieldType] isEqualToString:@"date"]
           || ( [[record objectForKey:kObjectTypeKey] isEqualToString:@"Event"]
               && [[record objectForKey:@"IsAllDayEvent"] boolValue]
               && [[NSArray arrayWithObjects:@"StartDateTime", @"EndDateTime", nil] containsObject:fieldName] ) )
            [dateTimePicker setDatePickerMode:UIDatePickerModeDate];
        else
            [dateTimePicker setDatePickerMode:UIDatePickerModeDateAndTime];
                
        if( ![SFVUtil isEmpty:[record objectForKey:fieldName]]
            && ![[fieldArray objectAtIndex:FieldComponentIsRequired] boolValue] )
            dateTimePicker.allowsClearingFieldValue = YES;
        
        if( ![SFVUtil isEmpty:[record objectForKey:fieldName]] )
            [dateTimePicker setDatePickerDate:[SFVUtil dateFromSOQLDatetime:[record objectForKey:fieldName]]];
        
        // working around the world's most idiotic bug
        // http://omegadelta.net/2010/06/04/ipad-simulator-crashes-if-a-uidatepicker-is-in-a-uipopovercontroller/
        
        UINavigationController *nav = [[[UINavigationController alloc] initWithRootViewController:dateTimePicker] autorelease];
                        
        popoverController = [[UIPopoverController alloc] initWithContentViewController:nav];
                
        [self tryForceResignFirstResponder];
                
        [self showPopover:popoverController fromIndexPath:indexPath];        
    } else if( [fieldType isEqualToString:@"reference"] ) {
        NSArray *refTo = [[SFVAppCache sharedSFVAppCache] field:fieldName
                                                       onObject:sObjectType
                                                  arrayProperty:FieldReferenceTo];
        
        NSMutableDictionary *dict = [NSMutableDictionary dictionary];
        
        for( NSString *ob in refTo )
            [dict setObject:( [ob isEqualToString:@"User"] 
                               ? [NSString stringWithFormat:@"%@ where isactive=true order by lastname asc limit 5",
                                    [[[SFVAppCache sharedSFVAppCache] shortFieldListForObject:ob] componentsJoinedByString:@","]]
                               : @"" )
                     forKey:ob];
        
        ObjectLookupController *olc = [[ObjectLookupController alloc] initWithSearchScope:dict];
        olc.delegate = self;
        olc.title = [fieldArray objectAtIndex:FieldComponentLabel];
        [olc.searchBar becomeFirstResponder];
        
        if( ![SFVUtil isEmpty:[record objectForKey:fieldName]]
            && ![[fieldArray objectAtIndex:FieldComponentIsRequired] boolValue] )
            olc.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] 
                                                      initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                                           target:self
                                                                           action:@selector(clearSelectedField)] autorelease];
        
        UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:olc];
        [olc release];
        
        popoverController = [[UIPopoverController alloc] initWithContentViewController:nav];
        [nav release];
        
        [self tryForceResignFirstResponder];
                
        [self showPopover:popoverController fromIndexPath:indexPath];
    } else
        [self scrollTableToIndexPath:indexPath animated:YES];
}

#pragma mark - gesture delegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    if( [gestureRecognizer isKindOfClass:[UITapGestureRecognizer class]] && errorField )
        [self scrollTableToIndexPath:[fieldsToIndexPaths objectForKey:errorField]
                            animated:YES];
    
    return YES;
}

@end
