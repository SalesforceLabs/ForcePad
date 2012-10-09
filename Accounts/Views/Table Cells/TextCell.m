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

#import "TextCell.h"
#import "SFVUtil.h"

@implementation TextCell

@synthesize textField, delegate, fieldLabel, validationType, fieldName, cellType, textView, allowTextViewCarriageReturns;

static CGFloat kCellHorizontalOffset = 5.0f;

#pragma mark - setup

- (void)dealloc {
    self.fieldName = nil;
    self.fieldLabel = nil;
    self.textField = nil;
    self.textView = nil;
    
    self.delegate = nil;
    [super dealloc];
}

- (id)initWithCellIdentifier:(NSString *)cellID {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID])) {
        self.selectionStyle = UITableViewCellSelectionStyleNone;
        self.textLabel.textColor = [UIColor darkGrayColor];
        self.textLabel.adjustsFontSizeToFitWidth = NO;
        self.textLabel.textAlignment = UITextAlignmentRight;
        self.textLabel.text = @"";
        self.textLabel.font = [UIFont boldSystemFontOfSize:16];
        self.textLabel.numberOfLines = 0;
        
        self.allowTextViewCarriageReturns = NO;
        
        maxLength = 100;
        maxLabelWidth = 120;
        
        UITapGestureRecognizer *gesture = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                  action:@selector(becomeFirstResponder)];
        gesture.numberOfTapsRequired = 1;
        gesture.numberOfTouchesRequired = 1;
        gesture.cancelsTouchesInView = NO;
        gesture.delaysTouchesBegan = NO;
        gesture.delegate = self;
        
        [self.contentView addGestureRecognizer:gesture];
        [gesture release];
    }
    
    return self;
}

- (void) setTextCellType:(enum TextCellTypes)textCellType {
    self.cellType = textCellType;
            
    if( self.cellType == TextFieldCell && !self.textField ) {
        self.textField = [[[UITextField alloc] initWithFrame:CGRectMake(0, 0, 310, 22)] autorelease];
        textField.delegate = self;
        textField.textAlignment = UITextAlignmentLeft;
        textField.returnKeyType = UIReturnKeyDone;
        textField.autocorrectionType = UITextAutocorrectionTypeNo;
        textField.clearButtonMode = UITextFieldViewModeWhileEditing;
        textField.clearsOnBeginEditing = NO;
        textField.textColor = AppTextCellColor;
        textField.text = @"";
        textField.placeholder = @"";
        textField.font = [UIFont systemFontOfSize:16];
        textField.backgroundColor = [UIColor clearColor];
        
        [textField addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
        
        [textField addTarget:self
                      action:@selector(textFieldFinished:)
            forControlEvents:UIControlEventEditingDidEndOnExit];
        
        self.accessoryView = self.textField;
    } else if( self.cellType == TextViewCell && !self.textView ) {
        self.textView = [[[KTTextView alloc] initWithFrame:CGRectMake(0, 0, 330, 22)] autorelease];
        textView.delegate = self;
        textView.textAlignment = UITextAlignmentLeft;
        textView.returnKeyType = UIReturnKeyDone;
        textView.autocorrectionType = UITextAutocorrectionTypeNo;
        textView.textColor = AppTextCellColor;
        textView.text = @"";
        textView.font = [UIFont systemFontOfSize:16]; 
        textView.editable = YES;
        textView.backgroundColor = [UIColor clearColor];
                
        self.accessoryView = self.textView;
    }
}

- (BOOL) becomeFirstResponder {
    if( self.cellType == TextFieldCell && self.textField && [self.textField canBecomeFirstResponder] )
        return [self.textField becomeFirstResponder];
    else if( self.cellType == TextViewCell && self.textView && [self.textView canBecomeFirstResponder] )
        return [self.textView becomeFirstResponder];
    
    return NO;
}

- (BOOL) resignFirstResponder {    
    if( self.cellType == TextFieldCell )
        return [self.textField resignFirstResponder];
    else
        return [self.textView resignFirstResponder];
}

- (void) setKeyboardType:(UIKeyboardType)type {
    if( self.cellType == TextFieldCell )
        [self.textField setKeyboardType:type];
    else
        [self.textView setKeyboardType:type];
}

- (void)setReturnKeyType:(UIReturnKeyType)type {
    if( self.cellType == TextFieldCell )
        [self.textField setReturnKeyType:type];
    else
        [self.textView setReturnKeyType:type];
}

- (void) setCellText:(NSString *)text {
    if( [SFVUtil isEmpty:text] )
        text = @"";
    
    if( self.cellType == TextFieldCell )
        self.textField.text = text;
    else
        self.textView.text = text;
}

- (void)setPlaceholder:(NSString *)text {
    if( [SFVUtil isEmpty:text] )
        text = @"";
    
    if( self.cellType == TextFieldCell )
        self.textField.placeholder = text;
    else
        self.textView.placeholderText = text;
}

- (NSString *) getCellText {
    NSString *text = nil;
    
    if( self.cellType == TextFieldCell )
        text = self.textField.text;
    else
        text = self.textView.text;
    
    return ( text ? text : @"" );
}

- (void) setMaxLength:(int) length {
    maxLength = length;
}

- (int) getMaxLength {
    return maxLength;
}

- (void) setMaxLabelWidth:(float)width {
    maxLabelWidth = width;
}

- (BOOL) shouldChangeCharacters:(NSString *)characters range:(NSRange)range replacementString:(NSString *)string {    
    NSString *str = [characters stringByReplacingCharactersInRange:range withString:string];
    int length = [str length];
    
    // If we are a decimal, enforce just one decimal point
    if( validationType == ValidateDecimal
       && [str rangeOfString:@"."].location != NSNotFound ) {
        if( [[str componentsSeparatedByString:@"."] count] > 2 )
            return NO;
        
        // decimal does not count against our length
        length--;
    }
    
    if( length > maxLength )
        return NO;
    
    if( !validationType || validationType == ValidateNone )
        return YES;
    
    NSMutableCharacterSet *validChars = nil;
    
    switch( validationType ) {
        case ValidateAlphaNumeric:
            validChars = [NSMutableCharacterSet alphanumericCharacterSet];
            [validChars formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
            [validChars formUnionWithCharacterSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
            break;
        case ValidateInteger:
            validChars = [NSMutableCharacterSet decimalDigitCharacterSet];
            break;
        case ValidatePhone:
            validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789+-() "];
            [validChars formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
            [validChars formUnionWithCharacterSet:[NSCharacterSet alphanumericCharacterSet]];
            break;
        case ValidateZipCode:
            validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789-,()"];
            break;
        case ValidateDecimal:
            validChars = [NSMutableCharacterSet characterSetWithCharactersInString:@"0123456789.-"];
            [validChars formUnionWithCharacterSet:[NSCharacterSet decimalDigitCharacterSet]];
            break;
        case ValidateURL:
            validChars = [NSMutableCharacterSet alphanumericCharacterSet];
            [validChars formUnionWithCharacterSet:[NSCharacterSet punctuationCharacterSet]];
            [validChars formUnionWithCharacterSet:[NSCharacterSet characterSetWithCharactersInString:@"=<>?&+"]];
            break;
            
        default: break;
    }
    
    // Formats to (XXX) XXX-XXXX
    // Removed this so we can support international numbers too
    /*if( validationType == ValidatePhone ) {
        int length = [self getLength:characters];
        
        if(length == 10) {
            if(range.length == 0)
                return NO;
        } else if(length == 3) {
            NSString *num = [self formatNumber:characters];

            [self setCellText:[NSString stringWithFormat:@"(%@) ",num]];
            
            if(range.length > 0)
                [self setCellText:[NSString stringWithFormat:@"%@",[num substringToIndex:3]]];
        } else if(length == 6) {
            NSString *num = [self formatNumber:characters];
            
            [self setCellText:[NSString stringWithFormat:@"(%@) %@-",[num  substringToIndex:3],[num substringFromIndex:3]]];
            
            if(range.length > 0)
                [self setCellText:[NSString stringWithFormat:@"(%@) %@",[num substringToIndex:3],[num substringFromIndex:3]]];
        }
    }*/
    
    if( !validChars )
        return YES;
    
    NSCharacterSet *unacceptedInput = [validChars invertedSet];
    
    str = [[str lowercaseString] decomposedStringWithCanonicalMapping];
    
    return [[str componentsSeparatedByCharactersInSet:unacceptedInput] count] == 1;
}

#pragma mark - textfield delegate

- (void) textFieldDidChange:(id)sender {
    if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
        [self.delegate textCellValueChanged:self];
}

- (void) textFieldDidEndEditing:(UITextField *)tf {   
    if( [self.delegate respondsToSelector:@selector(textCellDidEndEditing:)] )
        [self.delegate textCellDidEndEditing:self];
}

- (BOOL) textFieldShouldReturn:(UITextField *)tf {        
    if( [self.delegate respondsToSelector:@selector(textCellShouldReturn:)] )
        return [self.delegate textCellShouldReturn:self];
    
    return YES;
}

- (void)textFieldDidBeginEditing:(UITextField *)tf {
    if( [self.delegate respondsToSelector:@selector(textCellDidBecomeFirstResponder:)] )
        [self.delegate textCellDidBecomeFirstResponder:self];
}

- (void) textFieldFinished:(id)sender {
    //if( [self.delegate respondsToSelector:@selector(textCellDidEndEditing:)] )
    //    [self.delegate textCellDidEndEditing:self];
}

- (BOOL)textField:(UITextField *)tf shouldChangeCharactersInRange:(NSRange)range replacementString:(NSString *)string {    
    return [self shouldChangeCharacters:tf.text range:range replacementString:string];
}

#pragma mark - textview delegate

- (BOOL)textView:(UITextView *)tv shouldChangeTextInRange:(NSRange)range replacementText:(NSString *)text {
    if( [text isEqualToString:@"\n"] && !allowTextViewCarriageReturns ) {
        [self textViewDidEndEditing:tv];
        return NO;
    }
    
    return [self shouldChangeCharacters:tv.text range:range replacementString:text];
}

- (void)textViewDidBeginEditing:(UITextView *)textView {    
    if( [self.delegate respondsToSelector:@selector(textCellDidBecomeFirstResponder:)] )
        [self.delegate textCellDidBecomeFirstResponder:self];
}

- (void)textViewDidChange:(UITextView *)tv {
    if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
        [self.delegate textCellValueChanged:self];
}

- (void)textViewDidEndEditing:(UITextView *)tv {     
    if( [self.delegate respondsToSelector:@selector(textCellDidEndEditing:)] )
        [self.delegate textCellDidEndEditing:self];
}

- (void)textViewDidChangeSelection:(UITextView *)tv {
    //if( [self.delegate respondsToSelector:@selector(textCellValueChanged:)] )
    //    [self.delegate textCellValueChanged:self];
}

- (BOOL)textViewShouldEndEditing:(UITextView *)textView {
    if( [self.delegate respondsToSelector:@selector(textCellShouldReturn:)] )
        return [self.delegate textCellShouldReturn:self];
    
    return YES;
}

#pragma mark - misc

- (void) layoutSubviews {
    [super layoutSubviews];
    
    CGSize cellSize = self.frame.size;
    CGSize labelSize = [self.textLabel.text sizeWithFont:self.textLabel.font 
                                       constrainedToSize:CGSizeMake( maxLabelWidth, cellSize.height )];
    
    [self.textLabel setFrame:CGRectMake( kCellHorizontalOffset, 
                                       ( self.cellType == TextFieldCell 
                                            ? floorf( ( cellSize.height - labelSize.height ) / 2.0f ) 
                                            : 8 ),
                                       maxLabelWidth, labelSize.height )];
        
    CGRect r = ( self.cellType == TextFieldCell 
                 ? self.textField.frame 
                 : self.textView.frame );
        
    if( [SFVUtil isEmpty:self.textLabel.text] ) {
        r.origin.x = 15;
        r.size.width = CGRectGetWidth(self.frame) - r.origin.x - 10;
    } else {
        r.origin.x = CGRectGetMaxX(self.textLabel.frame) + 11;
        r.size.width = CGRectGetWidth(self.frame) - r.origin.x - 15;
    }
    
    if( self.imageView.image ) {
        CGSize imgSize = self.imageView.image.size;
        
        [self.imageView setFrame:CGRectMake( r.origin.x, 
                                            floorf( ( cellSize.height - imgSize.height ) / 2.0f ),
                                            imgSize.width, imgSize.height)];
        
        [self.textField removeFromSuperview];
        [self.textView removeFromSuperview];
    } else if( self.cellType == TextFieldCell ) {
        CGSize valueSize = [@"AAAA" sizeWithFont:self.textField.font 
                               constrainedToSize:CGSizeMake( r.size.width, cellSize.height )];   
        
        if( valueSize.height == 0 ) // sigh
            valueSize.height = cellSize.height / 2;
        
        r.origin.y = floorf( ( cellSize.height - valueSize.height ) / 2.0f );
        r.size.height = valueSize.height;
        [self.textField setFrame:r];
        self.accessoryView = textField;
        [self.textView removeFromSuperview];
    } else {
        r.origin.y = 0;
        r.origin.x -= 8;
        r.size.height = cellSize.height;
        [self.textView setFrame:r];
        self.accessoryView = textView;
        [self.textField removeFromSuperview];
    }
}

// http://stackoverflow.com/questions/6052966/phone-number-validation-formatting-on-iphone-ios
- (NSString*)formatNumber:(NSString*)mobileNumber {
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"(" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@")" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@" " withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"-" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"+" withString:@""];
        
    int length = [mobileNumber length];
    if(length > 10)
    {
        mobileNumber = [mobileNumber substringFromIndex: length-10];
    }

    return mobileNumber;
}


- (int) getLength:(NSString*)mobileNumber {
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"(" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@")" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@" " withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"-" withString:@""];
    mobileNumber = [mobileNumber stringByReplacingOccurrencesOfString:@"+" withString:@""];
    
    int length = [mobileNumber length];
    
    return length;
}

#pragma mark - gesture recognizer delegate

- (BOOL)gestureRecognizerShouldBegin:(UIGestureRecognizer *)gestureRecognizer {
    // pass to tableview
    [self becomeFirstResponder];
    
    return YES;
}

@end