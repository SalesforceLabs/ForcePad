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
#import "FieldPopoverButton.h"
#import "DetailViewController.h"
#import "SimpleKeychain.h"
#import "RootViewController.h"
#import "FollowButton.h"
#import "SFVAppCache.h"
#import "SFVUtil.h"
#import "SFVAsync.h"
#import "UIImage+ImageUtils.h"
#import <QuartzCore/QuartzCore.h>

@implementation FieldPopoverButton

@synthesize popoverController, fieldType, buttonDetailText, detailViewController, myRecord, flyingWindowController, followButton, isButtonInPopover;

static NSString *facetimeFormat = @"facetime://%@";
static NSString *skypeFormat = @"skype:%@?call";
static NSString *openInMapsFormat = @"http://maps.google.com/maps?q=%@";

+ (id) buttonWithText:(NSString *)text fieldType:(enum FieldType)fT detailText:(NSString *)detailText {
    FieldPopoverButton *button = [self buttonWithType:UIButtonTypeCustom];
    
    button.buttonDetailText = detailText;
    button.fieldType = fT;
    button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    button.isButtonInPopover = NO;
    
    switch( button.fieldType ) {
        case TextField:
            [button setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
            [button setTitle:text forState:UIControlStateNormal];
            break;
        case UserPhotoField:
            break;
        case WebviewField:
            if( detailText && [detailText length] > 0 )
                [button setImage:[UIImage imageNamed:@"openPopover.png"] forState:UIControlStateNormal];
            
            break;
        default:
            [button setTitleColor:AppLinkColor forState:UIControlStateNormal];
            [button setTitle:text forState:UIControlStateNormal];
            button.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:16];
            break;
    }
              
    [button setTitleColor:[UIColor darkTextColor] forState:UIControlStateHighlighted];
    button.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
    button.titleLabel.numberOfLines = 0;
    button.titleLabel.textAlignment = UITextAlignmentLeft;
    button.titleLabel.adjustsFontSizeToFitWidth = NO;
    
    [button addTarget:button action:@selector(fieldTapped:) forControlEvents:UIControlEventTouchUpInside];
    
    [[NSNotificationCenter defaultCenter]
     addObserver:button 
     selector:@selector(orientationDidChange)
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
    
    return button;
}

- (void) setFieldRecord:(NSDictionary *)record {    
    self.myRecord = record;
    
    NSArray *requiredFields = nil;
    
    if( self.fieldType == UserField || self.fieldType == UserPhotoField )
        requiredFields = [NSArray arrayWithObjects:@"Name", @"Email", @"FullPhotoUrl", nil];
    else if( self.fieldType == RelatedRecordField )
        requiredFields = [NSArray arrayWithObject:[[SFVAppCache sharedSFVAppCache] nameFieldForsObject:[record valueForKeyPath:@"attributes.type"]]];
        
    if( record && requiredFields )
        for( NSString *field in requiredFields )
            if( [SFVUtil isEmpty:[record objectForKey:field]] ) {
                [self removeTarget:self action:@selector(fieldTapped:) forControlEvents:UIControlEventTouchUpInside];
                [self setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
                [self setTitleColor:[UIColor darkGrayColor] forState:UIControlStateHighlighted];
                self.titleLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16];
                
                break;
            }
}

- (NSString *) trimmedDetailText {
    if( [self.buttonDetailText length] > 250 )
        return [[self.buttonDetailText substringToIndex:250] stringByAppendingFormat:@"...\n[%i more characters]",
                [self.buttonDetailText length] - 250];
    
    return self.buttonDetailText;
}

// Capture tapping a field
- (void) fieldTapped:(FieldPopoverButton *)button {    
    UIViewController *popoverContent = nil;
    
    NSString *url = nil;
        
    switch( self.fieldType ) {
        case RelatedRecordField:
            [self walkFlyingWindows];
            
            if( self.flyingWindowController )
                [self.detailViewController tearOffFlyingWindowsStartingWith:self.flyingWindowController.rightFWC inclusive:NO];
            
            [self.detailViewController addFlyingWindow:FlyingWindowRecordOverview withArg:self.myRecord];
            
            break;
        case EmailField:
            action = [[UIActionSheet alloc] init];
            action.delegate = self;
            action.title = button.buttonDetailText;            
            [action addButtonWithTitle:NSLocalizedString(@"Copy", @"Copy")];
            [action addButtonWithTitle:NSLocalizedString(@"Send Email", @"Send email")];

            url = [NSString stringWithFormat:facetimeFormat, 
                                    [button.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""]];
            
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]])
                [action addButtonWithTitle:NSLocalizedString(@"Call with FaceTime", @"Call with FaceTime")];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];
            break;
        case URLField:            
            [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:self.buttonDetailText];
            
            break;
        case TextField:
            action = [[UIActionSheet alloc] initWithTitle:[self trimmedDetailText]
                                                 delegate:self
                                         cancelButtonTitle:( isButtonInPopover ? NSLocalizedString(@"Cancel", nil) : nil )
                                   destructiveButtonTitle:nil
                                        otherButtonTitles:NSLocalizedString(@"Copy", @"Copy"), nil];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];
            break;
        case PhoneField:
            action = [[UIActionSheet alloc] init];
            action.delegate = self;
            action.title = self.buttonDetailText;
            
            [action addButtonWithTitle:NSLocalizedString(@"Copy", @"Copy")];
            
            NSString *phone = [button.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""];
            
            url = [NSString stringWithFormat:skypeFormat, phone];
            
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]])
                [action addButtonWithTitle:NSLocalizedString(@"Call with Skype", @"Call with Skype")];
            
            url = [NSString stringWithFormat:facetimeFormat, phone];
            
            if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:url]])
                [action addButtonWithTitle:NSLocalizedString(@"Call with FaceTime", @"Call with FaceTime")];
            
            if( isButtonInPopover )
                action.cancelButtonIndex = [action addButtonWithTitle:NSLocalizedString(@"Cancel", nil)];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];
            break;
        case AddressField:
            action = [[UIActionSheet alloc] initWithTitle:button.buttonDetailText
                                                 delegate:self
                                        cancelButtonTitle:nil
                                   destructiveButtonTitle:nil
                                        otherButtonTitles:NSLocalizedString(@"Copy", @"Copy"),
                                                        NSLocalizedString(@"Open in Maps", @"Open in Maps"),
                                                        nil];
            
            [action showFromRect:button.frame inView:self.superview animated:YES];            
            break;
        case WebviewField:
            popoverContent = [[UIViewController alloc] init];
            UIWebView *wv = [[UIWebView alloc] initWithFrame:CGRectZero];
            wv.delegate = self;
            wv.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
            wv.scalesPageToFit = NO;
            wv.allowsInlineMediaPlayback = NO;
            wv.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"panelBG.gif"]];
            
            NSString *html =  [SFVUtil stringByAppendingSessionIdToImagesInHTMLString:
                                    [SFVUtil stringByDecodingEntities:[NSString stringWithFormat:@"<body style=\"margin: 0; padding: 5; max-width: 600px;\">%@</body>", self.buttonDetailText]]
                                                                                sessionId:[[[SFVUtil sharedSFVUtil] client] sessionId]];
        
            [wv loadHTMLString:html baseURL:nil];
            popoverContent.view = wv;
            [wv release];
            
            self.popoverController = [[[UIPopoverController alloc] initWithContentViewController:popoverContent] autorelease];
            [popoverContent release];
            
            [self.popoverController presentPopoverFromRect:button.frame
                                                    inView:self.superview
                                  permittedArrowDirections:UIPopoverArrowDirectionAny
                                                  animated:YES];            
            
            break;
        case UserField: 
        case UserPhotoField:                   
            popoverContent = [[UIViewController alloc] init];
            popoverContent.view = [self userPopoverView];
            popoverContent.contentSizeForViewInPopover = CGSizeMake( popoverContent.view.frame.size.width, popoverContent.view.frame.size.height );
            popoverContent.title = [myRecord objectForKey:@"Name"];
            
            if ([MFMailComposeViewController canSendMail])
                popoverContent.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] 
                                                                    initWithTitle:NSLocalizedString(@"Email", @"Email action")
                                                                            style:UIBarButtonItemStyleBordered
                                                                            target:self
                                                                            action:@selector(openEmailComposer:)] autorelease];
            
            if( [[SFVAppCache sharedSFVAppCache] isChatterEnabled] ) {
                NSString *pId = [myRecord objectForKey:@"Id"];
                
                if( pId && ![[[SFVUtil sharedSFVUtil] currentUserId] isEqualToString:pId] ) {
                    self.followButton = [FollowButton followButtonWithParentId:pId];
                    self.followButton.delegate = self;
                    
                    popoverContent.navigationItem.rightBarButtonItem = [FollowButton loadingBarButtonItem];
                }
            }
            
            UINavigationController *nav = [[UINavigationController alloc] initWithRootViewController:popoverContent];
            [popoverContent release];
            
            self.popoverController = [[[UIPopoverController alloc]
                                      initWithContentViewController:nav] autorelease];
            [nav release];

            [self.popoverController presentPopoverFromRect:button.frame
                                                    inView:self.superview
                                  permittedArrowDirections:UIPopoverArrowDirectionAny
                                                  animated:YES];
            
            [self.followButton performSelector:@selector(loadFollowState) withObject:nil afterDelay:0.5];
            break;
        default: break;
    }
}

// We've clicked a button in this contextual menu
- (void) actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {    
    NSString *urlString = nil;
        
    if( buttonIndex == actionSheet.cancelButtonIndex )
        return;
    
    if (buttonIndex == 0) {
        UIPasteboard *pasteboard = [UIPasteboard generalPasteboard];
        pasteboard.string = self.buttonDetailText;        
    } else if (buttonIndex == 1) {        
        switch( self.fieldType ) {
            case EmailField:
                [self openEmailComposer:self];
                break;
                
            case AddressField:
                urlString = [NSString stringWithFormat:openInMapsFormat,
                                 self.buttonDetailText];
                
                urlString = [urlString stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
                                
                [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                break;
            case PhoneField:
                urlString = [NSString stringWithFormat:skypeFormat, 
                                                        [self.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""]];
                
                if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]])
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                else {
                    urlString = [NSString stringWithFormat:facetimeFormat, 
                                 [self.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""]];
                    
                    if( [[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]] )
                        [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                }
                break;
            default: break;
        }
    } else if( buttonIndex == 2 ) {
        switch( self.fieldType ) {
            case PhoneField: 
            case EmailField:
                urlString = [NSString stringWithFormat:facetimeFormat, 
                                                 [self.buttonDetailText stringByReplacingOccurrencesOfString:@" " withString:@""]];
                
                if ([[UIApplication sharedApplication] canOpenURL:[NSURL URLWithString:urlString]])
                    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:urlString]];
                break;
            default: break;
        }
    }
    
    SFRelease(action);
}

- (UIScrollView *) userPopoverView {
    int curY = 10, curX = 5;
    UIScrollView *view = [[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, 350, 0)];
    
    view.indicatorStyle = UIScrollViewIndicatorStyleWhite;
    view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]]; 
    
    // User Photo
    NSString *url = nil;
    
    if( [[SFVAppCache sharedSFVAppCache] isChatterEnabled] )
        url = [myRecord objectForKey:@"FullPhotoUrl"];
    
    // User title
    if( ![SFVUtil isEmpty:[myRecord objectForKey:@"Title"]] ) {
        UILabel *userTitle = [[UILabel alloc] initWithFrame:CGRectZero];
        userTitle.text = [myRecord objectForKey:@"Title"];
        userTitle.textColor = [UIColor whiteColor];
        userTitle.backgroundColor = [UIColor clearColor];
        userTitle.font = [UIFont fontWithName:@"Helvetica" size:18];
        userTitle.numberOfLines = 0;
        userTitle.adjustsFontSizeToFitWidth = NO;
        userTitle.shadowColor = [UIColor darkTextColor];
        userTitle.shadowOffset = CGSizeMake(0, 2);
        
        CGSize s = [userTitle.text sizeWithFont:userTitle.font
                    constrainedToSize:CGSizeMake( 300, CGFLOAT_MAX )
                        lineBreakMode:UILineBreakModeWordWrap];
        [userTitle setFrame:CGRectMake( curX, curY, s.width, s.height )];

        curY += userTitle.frame.size.height;
        [view addSubview:userTitle];
        
        [userTitle release];
    }
    
    NSArray *orderedKeys = [NSArray arrayWithObjects:@"Department", @"Phone", @"MobilePhone", @"AboutMe", nil];
    NSDictionary *fieldNames = [NSDictionary dictionaryWithObjectsAndKeys:
                                @"Phone", @"Phone",
                                @"Department", @"Department",
                                @"Mobile", @"MobilePhone",
                                @"About Me", @"AboutMe",
                                nil];
    
    for( NSString *field in orderedKeys ) {
        if( [SFVUtil isEmpty:[myRecord objectForKey:field]] || ![fieldNames objectForKey:field] )
            continue;
        
        UILabel *label = [[self class] labelForField:[fieldNames objectForKey:field]];
        [label sizeToFit];
        [label setFrame:CGRectMake( curX, curY, label.frame.size.width, label.frame.size.height )];
        
        curY += label.frame.size.height;
        [view addSubview:label];
        
        enum FieldType ft = TextField;
        
        if( [[NSArray arrayWithObjects:@"Phone", @"MobilePhone", nil] containsObject:field] )
            ft = PhoneField;
        
        NSString *text = [myRecord objectForKey:field];
        
        FieldPopoverButton *valueButton = [FieldPopoverButton buttonWithText:text
                                                                   fieldType:ft
                                                                  detailText:text];
        valueButton.isButtonInPopover = YES;
        
        if( ft == TextField )
            [valueButton setTitleColor:[UIColor lightTextColor] forState:UIControlStateNormal];
        
        CGSize s = [text sizeWithFont:valueButton.titleLabel.font
                          constrainedToSize:CGSizeMake( 300, CGFLOAT_MAX )
                              lineBreakMode:UILineBreakModeWordWrap];
        [valueButton setFrame:CGRectMake( curX, curY, s.width, s.height )];
        [view addSubview:valueButton];
        
        curY += s.height;
    }
    
    if( ![SFVUtil isEmpty:url] ) {
        UIImageView *userPhotoView = [[UIImageView alloc] init];
        [view addSubview:userPhotoView];
        [userPhotoView release];
        
        if( [url hasPrefix:@"/"] )
            url = [[SimpleKeychain load:instanceURLKey] stringByAppendingString:url];
        
        [[SFVUtil sharedSFVUtil] loadImageFromURL:[url stringByAppendingFormat:@"?oauth_token=%@",
                                                   [[[SFVUtil sharedSFVUtil] client] sessionId]]
                                            cache:YES
                                     maxDimension:400 // 200 width
                                    completeBlock:^(UIImage *img, BOOL wasLoadedFromCache) {
                                        if( !img || !self.popoverController )
                                            return;
                                                                                
                                        userPhotoView.alpha = 0.0;
                                        userPhotoView.image = img;
                                        userPhotoView.layer.cornerRadius = 5.0f;
                                        userPhotoView.layer.masksToBounds = YES;
                                        [userPhotoView setFrame:CGRectMake( 5, 10, img.size.width, img.size.height )];
                                        
                                        [UIView animateWithDuration:( wasLoadedFromCache ? 0.2f : 0.5f )
                                                         animations:^(void) {
                                                             CGFloat maxX = 100, maxY = 100;
                                                             
                                                             for( UIView *subview in [view subviews] )
                                                                 if( ![subview isEqual:userPhotoView] ) {
                                                                     CGRect r = subview.frame;
                                                                     r.origin.x = img.size.width + 10;
                                                                     
                                                                     [subview setFrame:r];
                                                                     
                                                                     maxX = MAX( maxX, CGRectGetMaxX(subview.frame) + 10 );
                                                                     maxY = MAX( maxY, CGRectGetMaxY(subview.frame));
                                                                 }
                                                             
                                                             maxX = MAX( maxX, 325 );
                                                             maxY = MAX( maxY, 20 + img.size.height );
                                                             
                                                             userPhotoView.alpha = 1.0f;
                                                             [view setFrame:CGRectMake(0, 0, maxX, 320 )];
                                                             self.popoverController.popoverContentSize = CGSizeMake( maxX, 320 );
                                                             [view setContentSize:CGSizeMake( view.frame.size.width, MAX( maxY, CGRectGetHeight(view.frame) + 1 ) )];
                                                         }];
                                    }];
    }
    
    // first apply a minimum height
    curY = MAX( curY, 300 );
    
    // but the window itself shouldn't be too large
    [view setFrame:CGRectMake(0, 0, view.frame.size.width, MIN( curY, 300 ) )];
    [view setContentSize:CGSizeMake( view.frame.size.width, MAX( curY, view.frame.size.height + 1 ) )];
    [view setContentOffset:CGPointZero animated:NO];
    
    return [view autorelease];
}

- (void) openEmailComposer:(id)sender {
    [self.detailViewController openEmailComposer:( myRecord ? [myRecord objectForKey:@"Email"] : self.buttonDetailText )];
}

#pragma mark - webview delegate

- (void) webViewDidFinishLoad:(UIWebView *)webView {    
    CGSize s = [webView sizeThatFits:CGSizeZero];
        
    if( s.width < 320 ) 
        s.width = 320;
    else if( s.width > 600 ) 
        s.width = 600;
    
    if( s.height < 100 ) 
        s.height = 100;
    else if( s.height > 500 ) 
        s.height = 500;
    
    self.popoverController.popoverContentSize = s;
    
    [self.popoverController presentPopoverFromRect:self.frame
                                            inView:self.superview
                          permittedArrowDirections:UIPopoverArrowDirectionAny 
                                          animated:YES];
}

- (void) webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"failed load");
}

- (BOOL) webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    // Only load the initial rich text contents
    if( [[[request URL] absoluteString] isEqualToString:@"about:blank"] )
        return YES;
    
    // Otherwise, load the url in a separate webview
    [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:[[request URL] absoluteString]];
    [self.popoverController dismissPopoverAnimated:YES];
    self.popoverController = nil;
    
    return NO;
}

// a silly little function to determine in which flying window this button appears
- (void) walkFlyingWindows {
    UIView *parent = nil;
    
    if( self.flyingWindowController )
        return;
    
    for( FlyingWindowController *fwc in [self.detailViewController flyingWindows] ) {
        parent = self.superview;
        
        while( parent ) {
            if( [fwc.view isEqual:parent] ) {
                self.flyingWindowController = fwc;
                return;
            }
            
            parent = [parent superview];
        }
    }
}

#pragma mark - follow button delegate

- (void)followButtonDidChangeState:(FollowButton *)followButton toState:(enum FollowButtonState)state isUserAction:(BOOL)isUserAction {
    UINavigationController *nc = (UINavigationController *)self.popoverController.contentViewController;
    UIViewController *vc = nc.visibleViewController;
        
    if( state == FollowLoading )
        [vc.navigationItem setRightBarButtonItem:[FollowButton loadingBarButtonItem] animated:NO];
    else
        [vc.navigationItem setRightBarButtonItem:self.followButton animated:NO];
}

#pragma mark - util

- (void)orientationDidChange {
    if( popoverController && [popoverController isPopoverVisible] ) {
        [popoverController dismissPopoverAnimated:YES]; 
        self.popoverController = nil;
    }
    
    if( action && [action isVisible] ) {
        [action dismissWithClickedButtonIndex:-1 animated:YES];
        SFRelease(action);
    }
}

+ (UILabel *) labelForField:(NSString *)field {
    UILabel *label = [[UILabel alloc] init];
    label.text = field;
    label.font = [UIFont boldSystemFontOfSize:16];
    label.textColor = AppSecondaryColor;
    label.backgroundColor = [UIColor clearColor];
    label.shadowColor = [UIColor darkTextColor];
    label.shadowOffset = CGSizeMake(0, 1);
    
    [label sizeToFit];
    
    return [label autorelease];
}

+ (UILabel *) valueForField:(NSString *)value {
    UILabel *label = [[UILabel alloc] init];
    label.text = value;
    label.textColor = [UIColor lightTextColor];
    label.font = [UIFont systemFontOfSize:14];
    label.backgroundColor = [UIColor clearColor];
    label.numberOfLines = 0;
    
    [label sizeToFit];
    
    return [label autorelease];
}

- (void)dealloc {
    [myRecord release];
    [popoverController release];
    [buttonDetailText release];
    [followButton release];
    SFRelease(action);
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self 
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
    
    [super dealloc];
}

@end
