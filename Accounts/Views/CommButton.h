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
// A generic communication button that makes calls, opens webpages, or does facetime.

#import <UIKit/UIKit.h>
#import "zkSforce.h"
#import "SFVUtil.h"
#import "ChatterPostController.h"
#import <EventKit/EventKit.h>
#import <EventKitUI/EventKitUI.h>
#import <AddressBook/AddressBook.h>
#import <AddressBookUI/AddressBookUI.h>

@class DetailViewController;

@interface CommButton : UIButton <UIActionSheetDelegate, ChatterPostDelegate, UIPopoverControllerDelegate, EKEventEditViewDelegate, ABUnknownPersonViewControllerDelegate> {
    UIPopoverController *popoverController;
}

// Types of buttons
typedef enum CommTypes {
    CommWeb = 0,
    CommEmail,
    CommFacetime,
    CommSkype,
    CommEdit,
    CommClone,
    CommCustomActionButtons,
    CommNumButtonTypes
} CommType;

// Types of custom action buttons
typedef enum CommCustomActionTypes {
    CommPostToChatter = 0,
    CommShowAccountNews,
    CommViewOnTheWeb,
    CommAddToCalendar,
    CommSaveContactToAddressBook,
    CommCustomActionNumTypes
} CommCustomActionType;

@property (nonatomic) CommType commType;

@property (nonatomic, retain) UIActionSheet *actionSheet;
@property (nonatomic, retain) NSDictionary *record;

@property (nonatomic, assign) DetailViewController *detailViewController;

// Creates a new button of a given type from a given record
+ (id) commButtonWithType:(CommType)type withRecord:(NSDictionary *)record;

// Determine if this device supports skype/facetime
+ (BOOL) supportsButtonOfType:(CommType)type;

// Determine if this button supports individual options within it
- (BOOL) supportsButtonAtIndex:(NSInteger)index;

- (void) buttonTapped:(id)button;

- (void) orientationDidChange;

// If passing in nil, returns a new record
// Otherwise, attempts to merge contact details
- (ABRecordRef) buildContactRecord:(ABRecordRef)aRecord;

@end
