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

#import "SFVUtil.h"
#import "zkSforce.h"
#import "DetailViewController.h"
#import "RootViewController.h"
#import "CommButton.h"
#import "SFVAppCache.h"
#import "SimpleKeychain.h"
#import "PRPAlertView.h"
#import "SFVUtil.h"
#import "SFVAsync.h"
#import "SFRestAPI+Blocks.h"
#import "DSActivityView.h"

@implementation CommButton

@synthesize actionSheet, commType, detailViewController, record;

static NSString *facetimeFormat = @"facetime://%@";
static NSString *skypeFormat = @"skype:%@?call";

+ (id) commButtonWithType:(CommType)type withRecord:(NSDictionary *)rec {
    CommButton *button = [self buttonWithType:UIButtonTypeCustom];
    
    button.commType = type;
    button.record = [[rec copy] autorelease];
    [button addTarget:button action:@selector(buttonTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    // Button image
    switch( type ) {
        case CommWeb:
            [button setImage:[UIImage imageNamed:@"websiteButton.png"] forState:UIControlStateNormal];
            break;
        case CommEmail:
            [button setImage:[UIImage imageNamed:@"emailButton.png"] forState:UIControlStateNormal];
            break;
        case CommSkype:
            [button setImage:[UIImage imageNamed:@"skypeButton.png"] forState:UIControlStateNormal];
            break;
        case CommFacetime:
            [button setImage:[UIImage imageNamed:@"facetimeButton.png"] forState:UIControlStateNormal];
            break;
        case CommCustomActionButtons:
            [button setImage:[UIImage imageNamed:@"actionButton.png"] forState:UIControlStateNormal];
            break;
        case CommEdit:
            [button setImage:[UIImage imageNamed:@"editButton.png"] forState:UIControlStateNormal];
            break;
        case CommClone:
            [button setImage:[UIImage imageNamed:@"cloneButton.png"] forState:UIControlStateNormal];
            break;
        default:
            NSLog(@"unexpected button type in CommButton.");
            return nil;
    }
    
    // Build our action sheet with eligible fields of the right type
    button.actionSheet = [[[UIActionSheet alloc] init] autorelease];
    button.actionSheet.delegate = button;
    button.actionSheet.title = nil;
    
    NSString *sObjectType = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[rec objectForKey:@"Id"]];  
    
    switch( type ) {
        case CommCustomActionButtons: {
            for( int i = 0; i < CommCustomActionNumTypes; i++ ) {
                if( ![button supportsButtonAtIndex:i] )
                    continue;
                
                switch( i ) {
                    case CommViewOnTheWeb:
                        [button.actionSheet addButtonWithTitle:NSLocalizedString(@"View on the Web", @"View on the Web")];
                        break;
                    case CommPostToChatter:
                        [button.actionSheet addButtonWithTitle:NSLocalizedString(@"Post to Chatter", @"Post to Chatter")];
                        break;
                    case CommShowAccountNews:
                        [button.actionSheet addButtonWithTitle:[NSString stringWithFormat:@"%@ %@",
                                                                [[SFVAppCache sharedSFVAppCache] labelForSObject:@"Account" usePlural:NO],
                                                                NSLocalizedString(@"News", @"News")]];
                        break;
                    case CommAddToCalendar:
                        [button.actionSheet addButtonWithTitle:NSLocalizedString(@"Add to Calendar", @"Add to Calendar")];
                        break;
                    case CommSaveContactToAddressBook:
                        [button.actionSheet addButtonWithTitle:NSLocalizedString(@"Add to Address Book", @"Add to Address Book")];
                        break;
                    default: break;
                }
            }
            
            // Did we actually add any buttons to this action sheet?
            if( [SFVUtil isEmpty:[button.actionSheet buttonTitleAtIndex:0]] )
                button = nil;
            
            break;
        }
        case CommEdit:
            // Verify that we can edit this record
            if( ![[SFVAppCache sharedSFVAppCache] doesObject:[rec objectForKey:kObjectTypeKey]
                                                haveProperty:ObjectIsUpdatable] 
                || ( [sObjectType isEqualToString:@"Lead"] && [[rec objectForKey:@"IsConverted"] boolValue] ) )
                button = nil;
            
            break;
        case CommClone:
            // Verify we can insert this record
            if( ![[SFVAppCache sharedSFVAppCache] doesObject:[rec objectForKey:kObjectTypeKey]
                                                haveProperty:ObjectIsCreatable] )
                button = nil;
            
            break;
        case CommEmail:
        case CommSkype:
        case CommFacetime:
        case CommWeb: {
            NSArray *callFields = [NSArray arrayWithObjects:@"Phone", @"Fax", @"MobilePhone", nil];
            NSArray *emailFields = [NSArray arrayWithObjects:@"Email", nil];
            NSArray *webFields = [NSArray arrayWithObjects:@"Website", nil];
            NSString *fValue = nil;
            
            for( NSString *field in [rec allKeys] ) {
                NSString *fieldType = [[SFVAppCache sharedSFVAppCache] field:field
                                                                    onObject:sObjectType
                                                              stringProperty:FieldType];
                
                fValue = [rec objectForKey:field];
                
                if( [SFVUtil isEmpty:fValue] )
                    continue;
                
                switch( type ) {
                    case CommSkype:
                        if( [callFields containsObject:field] ||
                           ( [fieldType isEqualToString:@"phone"] ) )
                            [button.actionSheet addButtonWithTitle:fValue];
                        break;
                    case CommEmail:
                        if( [emailFields containsObject:field] || 
                           ( [fieldType isEqualToString:@"email"] ) )
                            [button.actionSheet addButtonWithTitle:fValue];
                        break;
                    case CommFacetime:
                        if( [callFields containsObject:field] || 
                           [emailFields containsObject:field] ||
                           ( [fieldType isEqualToString:@"phone"] || [fieldType isEqualToString:@"email"] ) )
                            [button.actionSheet addButtonWithTitle:fValue];
                        break;                    
                    case CommWeb:
                        if( [webFields containsObject:field] || 
                           ( [fieldType isEqualToString:@"url"] ) )
                            [button.actionSheet addButtonWithTitle:[SFVUtil truncateURL:[rec objectForKey:field]]];
                    default:
                        break;
                }
            }
            
            // Did we actually add any buttons to this action sheet?
            if( [SFVUtil isEmpty:[button.actionSheet buttonTitleAtIndex:0]] )
                button = nil;
            
            break;
        }
        default:
            break;
    }
    
    if( !button )
        return nil;
    
    [[NSNotificationCenter defaultCenter]
     addObserver:button 
     selector:@selector(orientationDidChange)
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
    
    return button;
}

- (void)dealloc {
    self.record = nil;
    self.actionSheet = nil;
    self.detailViewController = nil;
    
    SFRelease(popoverController);
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self 
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
    
    [super dealloc];
}

+ (BOOL) supportsButtonOfType:(CommType)type {
    NSString *url = nil;
    
    switch( type ) {
        case CommEmail:
        case CommWeb:
            return NO;
        case CommCustomActionButtons:
        case CommEdit: // checked above, in init
        case CommClone: // checked above, in init
            return YES;
        /*case CommSkype:
            url = [NSString stringWithFormat:skypeFormat, @"4155551212"];
            break;
        case CommFacetime:
            url = [NSString stringWithFormat:facetimeFormat, @"4155551212"];
            break;*/
        default:
            return NO;
    }
    
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]];
}

- (BOOL)supportsButtonAtIndex:(NSInteger)index {
    switch( self.commType ) {
        case CommCustomActionButtons:
            switch( index ) {
                case CommViewOnTheWeb:
                    return YES;
                case CommPostToChatter:
                    return ( [[SFVAppCache sharedSFVAppCache] doesGlobalObject:[record objectForKey:kObjectTypeKey]
                                                                haveProperty:GlobalObjectIsFeedEnabled]
                             && ( [[record objectForKey:kObjectTypeKey] isEqualToString:@"Lead"]
                                  ? ![[record objectForKey:@"IsConverted"] boolValue]
                                  : YES ) );
                case CommShowAccountNews:
                    return [[record objectForKey:kObjectTypeKey] isEqualToString:@"Account"];
                case CommAddToCalendar:
                    return [[record objectForKey:kObjectTypeKey] isEqualToString:@"Event"];
                case CommSaveContactToAddressBook:
                    return [[NSArray arrayWithObjects:@"Contact", @"Lead", nil] containsObject:[record objectForKey:kObjectTypeKey]];
                default: break;
            }
            
            break;
        default: break;
    }
    
    return YES;
}

#pragma mark - POOSH BUTTON

- (void) buttonTapped:(id)button {
    switch( self.commType ) {
        case CommEdit:
        case CommClone: {
            // Only difference between edit and clone is the lack of a record Id.
            NSMutableDictionary *dict = [NSMutableDictionary dictionaryWithDictionary:self.record];
            
            if( commType == CommClone )
                [dict removeObjectForKey:@"Id"];
            
            // Use standard view, if any
            if( [[SFVAppCache sharedSFVAppCache] doesObject:[record objectForKey:kObjectTypeKey]
                                               haveProperty:ObjectHasCustomEditRecordURL] )
                [self.detailViewController addFlyingWindow:FlyingWindowWebView
                                                   withArg:[[[SFVAppCache sharedSFVAppCache] object:[record objectForKey:kObjectTypeKey]
                                                                                     stringProperty:ObjectEditURL] 
                                                            stringByReplacingOccurrencesOfString:@"{ID}" 
                                                            withString:[record objectForKey:@"Id"]]];
            else
                [self.detailViewController addFlyingWindow:FlyingWindowRecordEditor withArg:dict];
            
            break;
         }
        default:
            if( self.actionSheet && [self.actionSheet isVisible] ) {
                [self.actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
                return;
            }
            
            [actionSheet showFromRect:self.frame 
                               inView:self.superview 
                             animated:YES];
    }
}

- (void) actionSheet:(UIActionSheet *)as clickedButtonAtIndex:(NSInteger)buttonIndex { 
    if( buttonIndex < 0 )
        return;
    
    NSString *value = [as buttonTitleAtIndex:buttonIndex];
    NSString *url = nil;
    
    value = [value stringByReplacingOccurrencesOfString:@" " withString:@""];
    
    switch( self.commType ) {
        case CommCustomActionButtons: {
            int mappedIndex = 0;
            
            for( int x = 0; x < CommCustomActionNumTypes; x++ ) {
                if( [self supportsButtonAtIndex:x] )
                    buttonIndex--;
                
                if( buttonIndex < 0 ) {
                    mappedIndex = x;
                    break;
                }
            }
            
            switch( mappedIndex ) {
                case CommViewOnTheWeb:
                    url = [[SFVAppCache sharedSFVAppCache] webURLForURL:[@"/" stringByAppendingString:[self.record objectForKey:@"Id"]]];
                    [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:url];
                    break;
                case CommPostToChatter: {
                    NSMutableDictionary *postDic = [NSMutableDictionary dictionary];
                    
                    if( [[SFVAppCache sharedSFVAppCache] doesGlobalObject:[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[record objectForKey:@"Id"]]
                                                             haveProperty:GlobalObjectIsFeedEnabled] ) {
                        [postDic setObject:[record objectForKey:@"Id"] forKey:kParentField];
                        [postDic setObject:[[SFVAppCache sharedSFVAppCache] nameForSObject:record] forKey:kParentName];
                        [postDic setObject:[[SFVAppCache sharedSFVAppCache] labelForSObject:[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[record objectForKey:@"Id"]] usePlural:NO]
                                    forKey:kParentType];
                    } else {
                        [postDic setObject:[[SimpleKeychain load:instanceURLKey] stringByAppendingFormat:@"/%@", [record objectForKey:@"Id"]]
                                    forKey:kLinkField];
                        [postDic setObject:[NSString stringWithFormat:@"%@: %@",
                                            [[SFVAppCache sharedSFVAppCache] labelForSObject:[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[record objectForKey:@"Id"]] usePlural:NO],
                                            [[SFVAppCache sharedSFVAppCache] nameForSObject:record]]
                                    forKey:kTitleField];
                    }
                    
                    ChatterPostController *cpc = [[ChatterPostController alloc] initWithPostDictionary:postDic];
                    cpc.delegate = self;
                    
                    UINavigationController *aNavController = [[UINavigationController alloc] initWithRootViewController:cpc];
                    [cpc release];
                    
                    popoverController = [[UIPopoverController alloc] initWithContentViewController:aNavController];
                    popoverController.delegate = self;
                    [aNavController release];
                    
                    [popoverController presentPopoverFromRect:self.frame
                                                       inView:self.superview
                                     permittedArrowDirections:UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight
                                                     animated:YES];
                    break;
                }
                case CommShowAccountNews:
                    [self.detailViewController addFlyingWindow:FlyingWindowNews withArg:[[SFVAppCache sharedSFVAppCache] nameForSObject:self.record]];
                    break;
                case CommAddToCalendar: {
                    EKEventEditViewController *eventController = [[EKEventEditViewController alloc] init];
                    eventController.editViewDelegate = self;
                    eventController.eventStore = [[SFVUtil sharedSFVUtil] sharedEventStore];
                    
                    EKEvent *event = [EKEvent eventWithEventStore:[[SFVUtil sharedSFVUtil] sharedEventStore]];                    
                    event.availability = EKEventAvailabilityBusy;
                    event.title = [record objectForKey:@"Subject"];
                    event.location = [record objectForKey:@"Location"];
                    event.notes = [record objectForKey:@"Description"] ;
                    event.allDay = [[record objectForKey:@"IsAllDayEvent"] boolValue];
                    
                    if( [record objectForKey:@"StartDateTime"] )
                        event.startDate = [SFVUtil dateFromSOQLDatetime:[record objectForKey:@"StartDateTime"]];
                    
                    if( [record objectForKey:@"EndDateTime"] )
                        event.endDate = [SFVUtil dateFromSOQLDatetime:[record objectForKey:@"EndDateTime"]];
                    
                    eventController.event = event;
                    
                    popoverController = [[UIPopoverController alloc] initWithContentViewController:eventController];
                    popoverController.delegate = self;
                    [eventController release];
                    
                    [popoverController presentPopoverFromRect:self.frame
                                                       inView:self.superview
                                     permittedArrowDirections:UIPopoverArrowDirectionAny
                                                     animated:YES];
                    
                    break;
                }
                case CommSaveContactToAddressBook: {
                    ABUnknownPersonViewController *unknownPersonViewController = [[ABUnknownPersonViewController alloc] init];
                    unknownPersonViewController.unknownPersonViewDelegate = self;
                    unknownPersonViewController.displayedPerson = (ABRecordRef)[self buildContactRecord:nil];
                    unknownPersonViewController.allowsActions = YES;
                    unknownPersonViewController.allowsAddingToAddressBook = YES;
                    
                    UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:unknownPersonViewController];
                    [unknownPersonViewController release];
                    
                    popoverController = [[UIPopoverController alloc] initWithContentViewController:nav];
                    popoverController.delegate = self;
                    [nav release];
                    
                    [popoverController presentPopoverFromRect:self.frame
                                                       inView:self.superview
                                     permittedArrowDirections:UIPopoverArrowDirectionAny
                                                     animated:YES];
                    
                    break;
                }
            }
            
            return;
        }
        case CommSkype:
            url = [NSString stringWithFormat:skypeFormat, value];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            break;
        case CommFacetime:
            url = [NSString stringWithFormat:facetimeFormat, value];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            break;
        case CommWeb:
        case CommEmail:
            url = value;
            
            if( commType == CommWeb )
                [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:url];
            else if( commType == CommEmail )
                [self.detailViewController openEmailComposer:url];
            
            break;
        default:
            break;
    }
}

- (void) actualOrientationEvent {
    if( actionSheet && [actionSheet isVisible] )
        [actionSheet dismissWithClickedButtonIndex:-1 animated:NO];
    
    if( popoverController && [popoverController isPopoverVisible] )
        [popoverController presentPopoverFromRect:self.frame
                                           inView:self.superview
                         permittedArrowDirections:UIPopoverArrowDirectionLeft | UIPopoverArrowDirectionRight
                                         animated:YES];
}

- (void)orientationDidChange {
    // This is a slanderous, lecherous hack because flying windows can take their time to
    // relocate after the orientation event.
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(actualOrientationEvent) object:nil];
    [self performSelector:@selector(actualOrientationEvent) withObject:nil afterDelay:0.4f];
}

#pragma mark - address book

- (ABRecordRef)buildContactRecord:(ABRecordRef)aRecord {
    BOOL isNewContact = aRecord == nil;
    
    if( isNewContact )
        aRecord = ABPersonCreate();
    
    // Name
    if( isNewContact && ![SFVUtil isEmpty:[record objectForKey:@"FirstName"]] )
        ABRecordSetValue(aRecord, kABPersonFirstNameProperty, [record objectForKey:@"FirstName"], nil);
    
    if( isNewContact && ![SFVUtil isEmpty:[record objectForKey:@"LastName"]] )
        ABRecordSetValue(aRecord, kABPersonLastNameProperty, [record objectForKey:@"LastName"], nil);
    
    // Work Phone
    if( ![SFVUtil isEmpty:[record objectForKey:@"Phone"]] ) {
        ABMutableMultiValueRef multi = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(multi, [record objectForKey:@"Phone"], kABWorkLabel, nil);
        ABRecordSetValue(aRecord, kABPersonPhoneProperty, multi, nil);
        CFRelease(multi);
    }
        
    // Mobile Phone
    if( ![SFVUtil isEmpty:[record objectForKey:@"MobilePhone"]] ) {
        ABMutableMultiValueRef multi = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(multi, [record objectForKey:@"MobilePhone"], kABHomeLabel, nil);
        ABRecordSetValue(aRecord, kABPersonPhoneProperty, multi, nil);
        CFRelease(multi);
    }
    
    // Company
    if( ![SFVUtil isEmpty:[record valueForKeyPath:@"Account.Name"]] )
        ABRecordSetValue( aRecord, kABPersonOrganizationProperty, [record valueForKeyPath:@"Account.Name"], nil);
    
    if( ![SFVUtil isEmpty:[record valueForKeyPath:@"Company"]] )
        ABRecordSetValue( aRecord, kABPersonOrganizationProperty, [record valueForKeyPath:@"Company"], nil);
    
    // email
    if( ![SFVUtil isEmpty:[record objectForKey:@"Email"]] ) {
        ABMutableMultiValueRef multiemail = ABMultiValueCreateMutable(kABMultiStringPropertyType);
        ABMultiValueAddValueAndLabel(multiemail, [record objectForKey:@"Email"], kABWorkLabel, nil);
        ABRecordSetValue(aRecord, kABPersonEmailProperty, multiemail, nil);
        CFRelease(multiemail);
    }
    
    // Title
    if( ![SFVUtil isEmpty:[record objectForKey:@"Title"]] )
        ABRecordSetValue(aRecord, kABPersonJobTitleProperty, [record objectForKey:@"Title"], nil);
    
    // Address
    ABMutableMultiValueRef address = ABMultiValueCreateMutable(kABMultiDictionaryPropertyType);  
    NSMutableDictionary *addressDict = [NSMutableDictionary dictionary];
    
    if( ![SFVUtil isEmpty:[record objectForKey:@"MailingStreet"]] )
        [addressDict setObject:[record objectForKey:@"MailingStreet"]
                        forKey:(NSString *)kABPersonAddressStreetKey];  
    
    if( ![SFVUtil isEmpty:[record objectForKey:@"MailingPostalCode"]] )
        [addressDict setObject:[record objectForKey:@"MailingPostalCode"]
                        forKey:(NSString *)kABPersonAddressZIPKey];  
    
    if( ![SFVUtil isEmpty:[record objectForKey:@"MailingCity"]] )
        [addressDict setObject:[record objectForKey:@"MailingCity"]
                        forKey:(NSString *)kABPersonAddressCityKey]; 
    
    if( ![SFVUtil isEmpty:[record objectForKey:@"MailingState"]] )
        [addressDict setObject:[record objectForKey:@"MailingState"]
                        forKey:(NSString *)kABPersonAddressStateKey];  
    
    if( ![SFVUtil isEmpty:[record objectForKey:@"MailingCountry"]] )
        [addressDict setObject:[record objectForKey:@"MailingCountry"]
                        forKey:(NSString *)kABPersonAddressCountryKey];  
    
    if( [addressDict count] > 0 ) {
        ABMultiValueAddValueAndLabel(address, addressDict, kABWorkLabel, nil);
        ABRecordSetValue(aRecord, kABPersonAddressProperty, address, nil); 
    }
    
    CFRelease(address); 
    
    if( isNewContact )
        return [(id)aRecord autorelease];
    
    return aRecord;
}

- (void)unknownPersonViewController:(ABUnknownPersonViewController *)unknownCardViewController didResolveToPerson:(ABRecordRef)person {
    if( person )
        [popoverController dismissPopoverAnimated:YES];
}

- (BOOL)unknownPersonViewController:(ABUnknownPersonViewController *)personViewController 
shouldPerformDefaultActionForPerson:(ABRecordRef)person 
                           property:(ABPropertyID)property 
                         identifier:(ABMultiValueIdentifier)identifier {
    return NO;
}

#pragma mark - event delegate

- (void)eventEditViewController:(EKEventEditViewController *)controller didCompleteWithAction:(EKEventEditViewAction)action {
    NSError *error = nil;
    
    switch( action ) {
        case EKEventEditViewActionSaved:
            [controller.eventStore saveEvent:controller.event
                                        span:EKSpanThisEvent
                                       error:&error];
            break;
        default:
            break;
    }
    
    if( error )
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert") 
                            message:[error localizedDescription] 
                        cancelTitle:nil 
                        cancelBlock:nil 
                         otherTitle:@"OK" 
                         otherBlock:^(void) {
            [popoverController dismissPopoverAnimated:YES];
        }];
    else
        [popoverController dismissPopoverAnimated:YES];
}

#pragma mark - chatter posting

- (void)chatterPostDidDismiss:(ChatterPostController *)chatterPostController {
    [popoverController dismissPopoverAnimated:YES];
}

- (void)chatterPostDidFailWithError:(ChatterPostController *)chatterPostController error:(NSError *)e {
    [[SFVUtil sharedSFVUtil] receivedAPIError:e];
    [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert") 
                        message:[[e userInfo] objectForKey:@"message"]
                    buttonTitle:@"OK"];
}

- (void)chatterPostDidPost:(ChatterPostController *)chatterPostController {
    [popoverController dismissPopoverAnimated:YES];
}

#pragma mark - popover delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)pop {
    SFRelease(popoverController);
}

- (BOOL)popoverControllerShouldDismissPopover:(UIPopoverController *)pc {
    UIViewController *cont = [popoverController contentViewController];
    
    if( [cont isKindOfClass:[UINavigationController class]] ) {
        UIViewController *visible = [(UINavigationController *)cont visibleViewController];

        if( [visible isKindOfClass:[ChatterPostController class]] )
            return ![(ChatterPostController *)visible isDirty];
        
        return YES;
    }
    
    return NO;
}

@end
