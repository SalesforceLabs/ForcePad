/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh.com
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
#import "PRPSmartTableViewCell.h"
#import "KTTextView.h"

@protocol TextCellDelegate;

@interface TextCell : PRPSmartTableViewCell <UITextFieldDelegate, UITextViewDelegate, UIGestureRecognizerDelegate> {
    int maxLength;
    float maxLabelWidth;
}

// Validation Field types
enum ValidationTypes {
    ValidateNone = 0,
    ValidateAlphaNumeric,
    ValidatePhone,
    ValidateURL,
    ValidateZipCode,
    ValidateInteger,
    ValidateDecimal,
    ValidateNumTypes,
};

// Text cell types
enum TextCellTypes {
    TextFieldCell = 0,
    TextViewCell,
    TextCellNumTypes,
};

@property (nonatomic, retain) NSString *fieldLabel;
@property (nonatomic, retain) UITextField *textField;
@property (nonatomic, retain) KTTextView *textView;
@property (nonatomic, retain) NSString *fieldName;

@property (nonatomic, assign) id <TextCellDelegate> delegate;

@property enum ValidationTypes validationType;
@property enum TextCellTypes cellType;

@property (nonatomic) BOOL allowTextViewCarriageReturns;

// Setup
- (void) dealloc;
- (id) initWithCellIdentifier:(NSString *)cellID;
- (void) setMaxLabelWidth:(float)width;
- (void) setMaxLength:(int)length;
- (int) getMaxLength;
- (void) setTextCellType:(enum TextCellTypes)textCellType;
- (void) setCellText:(NSString *)text;
- (void) setPlaceholder:(NSString *)text;
- (NSString *) getCellText;

// Text Field delegate
- (void) textFieldFinished:(id)sender;
- (BOOL) textFieldShouldReturn:(UITextField *)tf;
- (void) textFieldDidChange:(id)sender;
- (BOOL) textField:(UITextField *)textField shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string;

// Misc
- (BOOL) shouldChangeCharacters:(NSString *)characters range:(NSRange)range replacementString:(NSString *)string;
- (void) setKeyboardType:(UIKeyboardType) type;
- (void) setReturnKeyType:(UIReturnKeyType)type;
- (NSString*) formatNumber:(NSString*)mobileNumber;
- (int) getLength:(NSString*)mobileNumber;
- (BOOL) becomeFirstResponder;

@end

// START:Delegate
@protocol TextCellDelegate <NSObject>

@optional

// called when the text cell value changes
- (void) textCellValueChanged:(TextCell *)cell;

- (BOOL) textCellShouldReturn:(TextCell *)cell;

- (void) textCellDidBecomeFirstResponder:(TextCell *)cell;
- (void) textCellDidEndEditing:(TextCell *)cell;

@end
// END:Delegate