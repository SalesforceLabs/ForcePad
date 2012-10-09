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

#import "QCContactMenu.h"
#import "SFVAppCache.h"
#import "SFVAsync.h"
#import "DetailViewController.h"

@implementation QCContactMenu

@synthesize detailViewController, record, actionSheet, commButtonValues;

static NSString *facetimeFormat = @"facetime://%@";
static NSString *skypeFormat = @"skype:%@?call";

+ (QCContactMenu *)contactMenuForRecord:(NSDictionary *)record {
    if( !record || [record count] == 0 )
        return nil;
    
    // 1. set up stored field values
    NSMutableArray *fieldValues = [NSMutableArray array];
    
    for( int i = 0; i < QCCommNumButtonTypes; i++ )
        [fieldValues addObject:[NSMutableArray array]];
    
    NSArray *callFields = [NSArray arrayWithObjects:@"Phone", @"Fax", @"MobilePhone", nil];
    NSArray *emailFields = [NSArray arrayWithObjects:@"Email", nil];
    NSArray *webFields = [NSArray arrayWithObjects:@"Website", nil];
    NSString *fValue = nil;
    
    for( NSString *field in [record allKeys] ) {
        NSString *fieldType = [[SFVAppCache sharedSFVAppCache] field:field
                                                            onObject:[record objectForKey:kObjectTypeKey]
                                                      stringProperty:FieldType];
        
        fValue = [record objectForKey:field];
        
        if( [SFVUtil isEmpty:fValue] )
            continue;
        
        if( [QCContactMenu supportsButtonOfType:QCCommSkype] 
            && ( [callFields containsObject:field] || [fieldType isEqualToString:@"phone"] ) )
            [[fieldValues objectAtIndex:QCCommSkype] addObject:fValue];
        
        if( [QCContactMenu supportsButtonOfType:QCCommEmail] 
            && ( [emailFields containsObject:field] || [fieldType isEqualToString:@"email"] ) )
            [[fieldValues objectAtIndex:QCCommEmail] addObject:fValue];
        
        if( [QCContactMenu supportsButtonOfType:QCCommFacetime]
            && ( [callFields containsObject:field] 
                || [emailFields containsObject:field]
                || ( [fieldType isEqualToString:@"phone"] || [fieldType isEqualToString:@"email"] ) ) )
            [[fieldValues objectAtIndex:QCCommFacetime] addObject:fValue];
        
        if( [QCContactMenu supportsButtonOfType:QCCommWeb] 
            && ( [webFields containsObject:field] || [fieldType isEqualToString:@"url"] ) )
            [[fieldValues objectAtIndex:QCCommWeb] addObject:[SFVUtil truncateURL:[record objectForKey:field]]];
    }
    
    BOOL contactMenuHasNoItems = YES;
    
    for( int i = 0; i < QCCommNumButtonTypes; i++ )
        if( [[fieldValues objectAtIndex:i] count] > 0 ) {
            contactMenuHasNoItems = NO;
            break;
        }
    
    if( contactMenuHasNoItems )
        return nil;
    
    NSMutableArray *menus = [NSMutableArray array];
    
    for( int i = 0; i < QCCommNumButtonTypes; i++ )
        if( [QCContactMenu supportsButtonOfType:i] && [[fieldValues objectAtIndex:i] count] > 0 ) {
            [menus addObject:[[[QuadCurveMenuItem alloc] initWithImage:[UIImage imageNamed:@"bg-menuitem.png"]
                                                      highlightedImage:[UIImage imageNamed:@"bg-menuitem-highlighted.png"] 
                                                          ContentImage:[QCContactMenu imageForButtonOfType:i] 
                                               highlightedContentImage:nil] autorelease]];
        }
    
    QCContactMenu *menu = [[QCContactMenu alloc] initWithFrame:CGRectMake(0, 0, 170, 170)
                                                         menus:menus];
    menu.delegate = menu;
    
    menu.contentImage = [UIImage imageNamed:@"qccontact.png"];
    menu.image = menu.contentImage;
    
    menu.timeOffset = 0.1f;
    menu.nearRadius = 83.0f;
    menu.farRadius = 90.0f;
    menu.endRadius = 85.0f;
    menu.rotateAngle = M_PI;
    menu.menuWholeAngle = M_PI_2;
    
    menu.record = [[record copy] autorelease];
    menu.commButtonValues = fieldValues;
    
    [[NSNotificationCenter defaultCenter]
     addObserver:menu 
     selector:@selector(orientationDidChange)
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
        
    return [menu autorelease];
}

- (void)dealloc {
    self.detailViewController = nil;
    self.record = nil;
    self.actionSheet = nil;
    self.commButtonValues = nil;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self
     name:UIDeviceOrientationDidChangeNotification
     object:nil];
    
    [super dealloc];
}

- (void)orientationDidChange {
    if( actionSheet && [actionSheet isVisible] )
        [actionSheet dismissWithClickedButtonIndex:-1 animated:YES];
}

#pragma mark - config

+ (BOOL) supportsButtonOfType:(QCCommType)type {
    NSString *url = nil;
    
    switch( type ) {
        case QCCommEmail:
        case QCCommWeb:
            return YES;
        case QCCommSkype:
            url = [NSString stringWithFormat:skypeFormat, @"4155551212"];
            break;
        case QCCommFacetime:
            url = [NSString stringWithFormat:facetimeFormat, @"4155551212"];
            break;
        default:
            return NO;
    }
    
    return [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]];
}

+ (UIImage *)imageForButtonOfType:(QCCommType)type {
    // Button image
    switch( type ) {
        case QCCommWeb:
            return [UIImage imageNamed:@"websiteButton.png"];
        case QCCommEmail:
            return [UIImage imageNamed:@"emailButton.png"];
        case QCCommSkype:
            return [UIImage imageNamed:@"skypeButton.png"];
        case QCCommFacetime:
            return [UIImage imageNamed:@"facetimeButton.png"];
        default:
            NSLog(@"unexpected button type in CommButton.");
            return nil;
    }
}

+ (NSString *)titleForButtonOfType:(QCCommType)type {
    switch ( type ) {
        case QCCommWeb:
            return NSLocalizedString(@"Web", @"Web");
        case QCCommEmail:
            return NSLocalizedString(@"Email", @"Email");
        case QCCommSkype:
            return NSLocalizedString(@"Skype", @"Skype");
        case QCCommFacetime:
            return NSLocalizedString(@"FaceTime", @"FaceTime");
        default: break;
    }
    
    return nil;
}

#pragma mark - menu delegate

- (void)quadCurveMenu:(QCContactMenu *)menu didSelectIndex:(NSInteger)idx {  
    if( menu.actionSheet ) {
        [menu.actionSheet dismissWithClickedButtonIndex:-1 animated:NO];
        menu.actionSheet = nil;
    }
    
    menu.actionSheet = [[[UIActionSheet alloc] init] autorelease];
    menu.actionSheet.delegate = menu;
    
    activeType = 0;
    
    for( int x = 0; x < QCCommNumButtonTypes; x++ ) {
        if( [QCContactMenu supportsButtonOfType:x] && [[menu.commButtonValues objectAtIndex:x] count] > 0 )
            idx--;
        
        if( idx < 0 ) {
            activeType = x;
            break;
        }
    }
    
    menu.actionSheet.title = [[self class] titleForButtonOfType:activeType];
    
    for( NSString *value in [menu.commButtonValues objectAtIndex:activeType] )
        [menu.actionSheet addButtonWithTitle:value];
    
    if( [menu.actionSheet numberOfButtons] > 0 )
        [menu.actionSheet showFromRect:CGRectMake( menu.startPoint.x - floorf( menu.image.size.width / 2.0f ), 
                                                   menu.startPoint.y - floorf( menu.image.size.height / 2.0f ), 
                                                   menu.image.size.width, menu.image.size.height )
                                inView:menu.superview
                              animated:YES];
}

#pragma mark - action sheet delegate

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
    if( buttonIndex < 0 )
        return;
    
    NSString *value = [[self.commButtonValues objectAtIndex:activeType] objectAtIndex:buttonIndex];
    NSString *url = nil;
    
    value = [value stringByReplacingOccurrencesOfString:@" " withString:@""];
        
    switch( activeType ) {
        case QCCommSkype:
            url = [NSString stringWithFormat:skypeFormat, value];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            break;
        case QCCommFacetime:
            url = [NSString stringWithFormat:facetimeFormat, value];
            [[UIApplication sharedApplication] openURL:[NSURL URLWithString:url]];
            break;
        case QCCommWeb:
        case QCCommEmail:            
            if( activeType == QCCommWeb )
                [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:value];
            else if( activeType == QCCommEmail )
                [self.detailViewController openEmailComposer:value];
            
            break;
        default:
            break;
    }
    
    self.actionSheet = nil;
}

@end
