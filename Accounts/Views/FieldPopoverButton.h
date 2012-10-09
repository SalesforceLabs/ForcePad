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
// A generic field button that performs custom actions (user popovers, sending email, opening URLs) 
// depending on the type of field.

#import <UIKit/UIKit.h>
#import "zkSforce.h"
#import "SFVUtil.h"
#import "FollowButton.h"

@class DetailViewController;
@class FlyingWindowController;

@interface FieldPopoverButton : UIButton <UIPopoverControllerDelegate, UIActionSheetDelegate, UIWebViewDelegate, FollowButtonDelegate> {
    UIActionSheet *action;
}

enum FieldType {
    EmailField,
    URLField,
    UserField,
    TextField,
    AddressField,
    PhoneField,
    UserPhotoField,
    WebviewField,
    RelatedRecordField
};

@property enum FieldType fieldType;
@property BOOL isButtonInPopover;

@property (nonatomic, retain) NSDictionary *myRecord;
@property (nonatomic, retain) NSString *buttonDetailText;
@property (nonatomic, retain) UIPopoverController *popoverController;
@property (nonatomic, retain) FollowButton *followButton;

@property (nonatomic, assign) DetailViewController *detailViewController;
@property (nonatomic, assign) FlyingWindowController *flyingWindowController;

+ (id) buttonWithText:(NSString *)text fieldType:(enum FieldType)fT detailText:(NSString *)detailText;

- (NSString *) trimmedDetailText;

- (void) setFieldRecord:(NSDictionary *)record;
- (void) fieldTapped:(id)button;
- (UIScrollView *) userPopoverView;
- (void) walkFlyingWindows;
- (void) openEmailComposer:(id)sender;

- (void) orientationDidChange;

// utility functions
+ (UILabel *) labelForField:(NSString *)field;
+ (UILabel *) valueForField:(NSString *)value;

@end
