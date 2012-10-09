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

#import "SFVAppDelegate.h"
#import "DetailViewController.h"
#import "RecordOverviewController.h"
#import "RecordNewsViewController.h"
#import "SubNavViewController.h"
#import "RootViewController.h"
#import "SFVUtil.h"
#import "zkSforce.h"
#import "FieldPopoverButton.h"
#import "FlyingWindowController.h"
#import <QuartzCore/QuartzCore.h>
#import "WebViewController.h"
#import "PRPAlertView.h"
#import "ListOfRelatedListsViewController.h"
#import "RelatedListGridView.h"
#import "RecentRecordsController.h"
#import "SFVAppCache.h"
#import "RecordEditor.h"
#import "SFVAsync.h"

@implementation DetailViewController

@synthesize subNavViewController, rootViewController, flyingWindows, browseButton;

static float windowOverlap = 60.0f;

// allow multiple flying windows of the same type?
BOOL allowMultipleWindows = NO;

- (void) awakeFromNib {
    [super awakeFromNib];
    
    self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"linenBG.png"]];
    self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
}

- (void)viewDidLoad {
    [super viewDidLoad];
        
    if( !monoLogo ) {
        monoLogo = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"sfv_mono.png"]];
        monoLogo.alpha = 0.05f;
        monoLogo.layer.cornerRadius = 75.0f;
        monoLogo.layer.masksToBounds = YES;
        monoLogo.layer.borderColor = [UIColor lightGrayColor].CGColor;
        monoLogo.layer.borderWidth = 2.0f;
        
        monoLogo.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | 
                                        UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
                
        CGPoint origin = CGPointCenteredOriginPointForRects(self.view.frame, CGRectMake(0, 0, monoLogo.image.size.width, monoLogo.image.size.height));
        
        [monoLogo setFrame:CGRectMake( origin.x, origin.y, monoLogo.image.size.width, monoLogo.image.size.height)];
        [self.view addSubview:monoLogo];
    }
}

- (void)viewWillDisappear:(BOOL)animated {       
    [super viewWillDisappear:animated];
    
    [self clearFlyingWindows];
}

- (void)dealloc {
    [browseButton release];
    [flyingWindows release];
    SFRelease(monoLogo);
    [super dealloc];
}

- (void) handleInterfaceRotation:(BOOL)isPortrait {   
    if( isPortrait == [RootViewController isPortrait] )
        return;
    
    if( [self.subNavViewController respondsToSelector:@selector(handleInterfaceRotation:)] )
        [self.subNavViewController handleInterfaceRotation:isPortrait];
    
    float framewidth;
            
    if( !isPortrait )
        framewidth = DevicePortraitWindowHeight - masterWidth;
    else
        framewidth = DevicePortraitWindowWidth;
                    
    if( [self numberOfFlyingWindows] > 0 )
        for( FlyingWindowController *fwc in self.flyingWindows ) {
            CGRect r = fwc.view.frame;
                        
            if( [fwc isLargeWindow] )
                r.size.width = floorf( framewidth - windowOverlap );
            else
                r.size.width = floorf( framewidth / 2.0f );
                 
            if( [fwc isLargeWindow] )
                r.origin.x = floorf( ( ( framewidth - r.size.width ) / 2.0f ) + ( windowOverlap / 2.0f ) );
            else if( [self numberOfFlyingWindows] == 1 || ![fwc isEqual:[self.flyingWindows lastObject]] )
                r.origin.x = 0;
            else
                r.origin.x = floorf( framewidth / 2.0f );
                                                         
            [fwc setFrame:r];
        }
}    

- (void) setPopoverButton:(UIBarButtonItem *)button {    
    if( button )
        self.browseButton = button;
    
    
    for( int i = 0; i < [self numberOfFlyingWindows]; i++ ) {
        FlyingWindowController *fwc = [self.flyingWindows objectAtIndex:i];
        
        if( i == 0 ) {
            if( [RootViewController isPortrait] )
                [fwc.navBar.topItem setLeftBarButtonItem:self.browseButton animated:NO];
            else
                [fwc.navBar.topItem setLeftBarButtonItem:nil animated:NO];
        } else if( i > 0 && [fwc.navBar.topItem.leftBarButtonItem isEqual:self.browseButton] )
            [fwc.navBar.topItem setLeftBarButtonItem:nil animated:NO];
    }
}

- (void) didSelectAccount:(NSDictionary *) acc {   
    if( !acc )
        return;
    
    if( [SFVUtil isEmpty:[acc objectForKey:@"Id"]] ) // merde.
        return;
    
    NSDictionary *record = [[acc copy] autorelease];
        
    // Make sure the network meter is reset
    for( int x = 0; x < 20; x++ )
        [[SFVUtil sharedSFVUtil] endNetworkAction];
    
    // Save this as a recently viewed record
    [[SFVUtil sharedSFVUtil] addRecentRecord:[record objectForKey:@"Id"]];
        
    // Refresh the favorites view if it's in the current window stack
    for( SubNavViewController *snvc in [self.rootViewController viewControllers] )
        if( snvc.subNavTableType == SubNavObjectListTypePicker && [snvc.searchResults count] == 0 ) {
            NSLog(@"REFRESH LIST PICKER FOR RECENT COUNT");
            [snvc refresh];
        }

    // If this record is not layoutable, open it in a webview
    if( ![[SFVAppCache sharedSFVAppCache] doesGlobalObject:[record objectForKey:kObjectTypeKey]
                                              haveProperty:GlobalObjectIsLayoutable] )
        [self addFlyingWindow:FlyingWindowWebView withArg:[[SFVAppCache sharedSFVAppCache] webURLForURL:[@"/" stringByAppendingString:[record objectForKey:@"Id"]]]];
    else {
        [self clearFlyingWindows];
        [self addFlyingWindow:FlyingWindowRecordOverview withArg:record];
    }
        
    [self setPopoverButton:self.browseButton];
}

#pragma mark - Flying Window delegate/management

- (void)clearFlyingWindowsForRecordId:(NSString *)recordId {   
    if( !recordId || [self numberOfFlyingWindows] == 0 )
        return;
    
    for( int i = [self.flyingWindows count] - 1; i >= 0; i-- ) {
        FlyingWindowController *fwc = [self.flyingWindows objectAtIndex:i];
                
        if( fwc.account && [[fwc.account objectForKey:@"Id"] hasPrefix:recordId] )
            [self removeFlyingWindowAtIndex:i reassignNeighbors:YES];
    }
    
    if( [self numberOfFlyingWindows] == 0 )
        [self addFlyingWindow:FlyingWindowRecordOverview
                      withArg:[NSDictionary dictionaryWithObject:recordId forKey:@"Id"]];
}

- (BOOL) flyingWindowShouldDrag:(FlyingWindowController *)flyingWindowController {
    if( flyingWindowController.flyingWindowType == FlyingWindowWebView )
        return !((WebViewController *)flyingWindowController).isFullScreen;
    
    return YES;
}

- (CGPoint) translateFlyingWindowCenterPoint:(FlyingWindowController *)flyingWindowController originalPoint:(CGPoint)originalPoint isDragging:(BOOL)isDragging {
    float framewidth = ( [RootViewController isPortrait] ? DevicePortraitWindowWidth : DevicePortraitWindowHeight - masterWidth ), 
        windowwidth = CGRectGetWidth( flyingWindowController.view.frame ),
        leftCenter = floorf( windowwidth / 2.0f ),
        centerCenter = floorf( framewidth / 2.0f ), 
        rightCenter = centerCenter + floorf( windowwidth / 2.0f ),
        largeWindowLeft = centerCenter + floorf( windowOverlap / 2.0f ), 
            leftbound, rightbound, target;
    CGPoint newPoint;
    int totalWindowCount = [self numberOfFlyingWindows];
    BOOL isLeftmost, isRightmost, isAlone;
        
    isLeftmost = [[self.flyingWindows objectAtIndex:0] isEqual:flyingWindowController];
    isRightmost = [[self.flyingWindows lastObject] isEqual:flyingWindowController];
    isAlone = totalWindowCount == 1; 
    
    leftbound = rightbound = target = leftCenter;
    
    // define a left/right bound for dragging, and a target when released, for each type of window
    // given its position in the window stack        
    if( isAlone ) {
        leftbound = rightbound = target = leftCenter;
    } else if( isLeftmost ) {
        rightbound = target = leftCenter;
    } else if( !isLeftmost && !isRightmost ) {
        leftbound = leftCenter;
        
        if( !flyingWindowController.leftFWC.leftFWC || ![flyingWindowController.leftFWC.leftFWC isViewLoaded] )
            rightbound = rightCenter;
        else
            rightbound = framewidth;
        
        if( flyingWindowController.leftFWC.leftFWC 
           && [flyingWindowController.leftFWC.leftFWC isViewLoaded] 
           && originalPoint.x > rightCenter + 75 )
            target = framewidth + floorf( windowwidth / 2.0f );
        else if( ( rightCenter - originalPoint.x ) > ( originalPoint.x - leftCenter ) )
            target = leftCenter;
        else
            target = rightCenter;        
    } else if( isRightmost && !isLeftmost ) {        
        if( [flyingWindowController isLargeWindow] )
            leftbound = target = largeWindowLeft;
        else
            leftbound = target = rightCenter;
        
        if( totalWindowCount <= 2 ) {
            rightbound = target = rightCenter;
            
            if( [flyingWindowController isLargeWindow] && originalPoint.x < centerCenter )
                target = largeWindowLeft;
        } else {
            rightbound = framewidth;
            
            if( originalPoint.x > rightCenter + 100 )
                target = framewidth + floorf( windowwidth / 2.0f );
            else if( originalPoint.x > centerCenter )
                target = rightCenter;
        }
    }
    
    // the window is being dragged. move it and its immediate neighbors to match the drag
    if( isDragging ) {    
        // if we are dragging beyond a bound, we apply some resistance 
        if( originalPoint.x < leftbound )
            newPoint.x = leftbound + ( ( originalPoint.x - leftbound ) / 7.0f );
        else if( originalPoint.x > rightbound )
            newPoint.x = rightbound + ( ( originalPoint.x - rightbound ) / 7.0f );
        else
            newPoint.x = originalPoint.x;
        
        CGPoint otherCenter;
        float otherWidth, ourWidth = flyingWindowController.view.frame.size.width;
            
        if( flyingWindowController.leftFWC && [flyingWindowController.leftFWC isViewLoaded] ) {
            otherCenter = flyingWindowController.leftFWC.view.center;
            otherWidth = flyingWindowController.leftFWC.view.frame.size.width;
            
            otherCenter.x = newPoint.x - ( ourWidth / 2.0f ) - ( otherWidth / 2.0f );
            
            if( otherCenter.x < otherWidth / 2.0f )
                otherCenter.x = otherWidth / 2.0f;
            
            otherCenter.x = lroundf( otherCenter.x );
            
            if( CGRectIntersectsRect( flyingWindowController.view.frame, flyingWindowController.leftFWC.view.frame ) &&
               CGRectIntersection( flyingWindowController.view.frame, flyingWindowController.leftFWC.view.frame ).size.width > 40 )
                [flyingWindowController.leftFWC slideFlyingWindowToPoint:otherCenter bounce:NO];
            else
                [flyingWindowController.leftFWC.view setCenter:otherCenter];
        }
        
        if( flyingWindowController.rightFWC && [flyingWindowController.rightFWC isViewLoaded] ) {
            otherCenter = flyingWindowController.rightFWC.view.center;
            otherWidth = flyingWindowController.rightFWC.view.frame.size.width;
            
            otherCenter.x = lroundf( newPoint.x + ( ourWidth / 2.0f ) + ( otherWidth / 2.0f ) );
            
            [self.view bringSubviewToFront:flyingWindowController.rightFWC.view];
            
            if( CGRectIntersectsRect( flyingWindowController.view.frame, flyingWindowController.rightFWC.view.frame ) &&
               CGRectIntersection( flyingWindowController.view.frame, flyingWindowController.rightFWC.view.frame ).size.width > 40 )
                [flyingWindowController.rightFWC slideFlyingWindowToPoint:otherCenter bounce:NO];
            else
                [flyingWindowController.rightFWC.view setCenter:otherCenter];
            
            if( flyingWindowController.rightFWC.rightFWC && [flyingWindowController.rightFWC.rightFWC isViewLoaded] ) {
                [self.view bringSubviewToFront:flyingWindowController.rightFWC.rightFWC.view];
                
                CGPoint p = flyingWindowController.rightFWC.rightFWC.view.center;
                
                p.x = otherCenter.x + ( flyingWindowController.rightFWC.view.frame.size.width / 2.0f ) + ( flyingWindowController.rightFWC.rightFWC.view.frame.size.width / 2.0f );
                
                [flyingWindowController.rightFWC.rightFWC.view setCenter:p];
            }
        }            
        
        // dimming
        /*if( flyingWindowController.leftFWC ) {
            CGRect overlap = CGRectIntersection( flyingWindowController.view.frame, flyingWindowController.leftFWC.view.frame );
            float perc = overlap.size.width / flyingWindowController.leftFWC.view.frame.size.width;

            [flyingWindowController.leftFWC setDimmerAlpha:perc];
        }
        
        [flyingWindowController setDimmerAlpha:0];
        
        if( flyingWindowController.rightFWC ) {
            CGRect overlap = CGRectIntersection( flyingWindowController.view.frame, flyingWindowController.rightFWC.view.frame );
            float perc = overlap.size.width / flyingWindowController.rightFWC.view.frame.size.width;
            
            [flyingWindowController.rightFWC setDimmerAlpha:perc];
        }*/
    } else { /* released touch. snap to target */
        newPoint.x = target;
        
        // Ensure the window to our left slides back to its position
        if( flyingWindowController.leftFWC && [flyingWindowController.leftFWC isViewLoaded] ) {
            CGPoint p = flyingWindowController.leftFWC.view.center;
            CGRect r = flyingWindowController.leftFWC.view.frame;
                
            if( target >= framewidth )
                p.x = [flyingWindowController.leftFWC isLargeWindow] ? largeWindowLeft : centerCenter + ( r.size.width / 2.0f );
            else
                p.x = r.size.width / 2.0f;
            
            [flyingWindowController.leftFWC slideFlyingWindowToPoint:p bounce:NO];
        }
            
        // And the window to our right
        if( flyingWindowController.rightFWC && [flyingWindowController.rightFWC isViewLoaded] ) {
            CGRect r = flyingWindowController.rightFWC.view.frame;
            CGPoint p = flyingWindowController.rightFWC.view.center;
            
            if( target <= leftCenter )
                p.x = CGRectGetWidth(flyingWindowController.view.frame) + ( CGRectGetWidth(r) / 2.0f );
            else
                p.x = framewidth + ( r.size.width / 2.0f );
                
            [flyingWindowController.rightFWC slideFlyingWindowToPoint:p bounce:NO];
            
            /*if( flyingWindowController.rightFWC.rightFWC ) {
                p = flyingWindowController.rightFWC.rightFWC.view.center;
                p.x = framewidth + ( flyingWindowController.rightFWC.rightFWC.view.frame.size.width / 2.0f );
                
                [flyingWindowController.rightFWC.rightFWC slideFlyingWindowToPoint:p bounce:NO];
            }*/
        }    
    }
    
    if( !newPoint.x )
        newPoint.x = 0;

    newPoint.y = floorf( CGRectGetHeight(self.view.frame) / 2.0f );
            
    return newPoint;
}

- (void) tearOffFlyingWindowsStartingWith:(FlyingWindowController *)flyingWindowController inclusive:(BOOL)inclusive {
    if( !self.flyingWindows || [self.flyingWindows count] == 0 || !flyingWindowController )
        return;
    
    int tearPoint = -1;
    
    for( int x = 0; x < [self.flyingWindows count]; x++ ) {
        FlyingWindowController *fwc = [self.flyingWindows objectAtIndex:x];
        
        if( [fwc isEqual:flyingWindowController] ) {
            tearPoint = x;
            break;
        }
    }
    
    if( tearPoint != -1 )
        for( int x = [self.flyingWindows count] - 1; x >= tearPoint; x-- ) {
            FlyingWindowController *fwc = [self.flyingWindows objectAtIndex:x];
            
            if( !inclusive && [fwc isEqual:flyingWindowController] )
                continue;
            
            [self removeFlyingWindowAtIndex:x reassignNeighbors:YES];//( x == tearPoint )];
        }
    
    if( [self numberOfFlyingWindows] > 1 ) {
        CGPoint p = CGPointMake( lroundf( self.view.frame.size.width * 0.75f ), lroundf( self.view.frame.size.height / 2.0f ) );
        
        if( [[self.flyingWindows lastObject] isLargeWindow] )
            p.x = lroundf( ( self.view.frame.size.width / 2.0f ) + ( windowOverlap / 2.0f ) );
        
        [[self.flyingWindows lastObject] slideFlyingWindowToPoint:p bounce:YES];
    }
}

- (void) addFlyingWindow:(FlyingWindowType)windowType withArg:(id)arg {
    FlyingWindowController *fwc = nil;
    CGFloat framewidth = floorf( [RootViewController isPortrait] 
                           ? DevicePortraitWindowWidth
                           : DevicePortraitWindowHeight - masterWidth );
        
    if( !self.flyingWindows )
        self.flyingWindows = [NSMutableArray array];
    
    // Always zap webviews every time we add a new window
    [self removeFirstFlyingWindowOfType:FlyingWindowWebView];
    
    switch( windowType ) {
        // Max of one record editor window
        case FlyingWindowRecordEditor:
            [self removeFirstFlyingWindowOfType:FlyingWindowRecordEditor];
            break;
        // Max of one news window
        case FlyingWindowNews:
            [self removeFirstFlyingWindowOfType:FlyingWindowNews];
            break;
        // Max of one record overview window *per record id*
        case FlyingWindowRecordOverview:
            [self clearFlyingWindowsForRecordId:[arg objectForKey:@"Id"]];            
            break;
        // default to a max of 3 of any one type
        default:
            if( [self numberOfFlyingWindowsOfType:windowType] >= 3 )
                [self removeFirstFlyingWindowOfType:windowType];
            
            break;
    }
    
    // Move the last window out of the way
    if( [self numberOfFlyingWindows] > 0 ) {
        FlyingWindowController *fwc = [self.flyingWindows lastObject];        
        
        CGRect fr = fwc.view.frame;
        CGPoint leftEdge = CGPointMake( lroundf( fr.size.width / 2.0f ), lroundf( fr.size.height / 2.0f ) );
                
        [fwc slideFlyingWindowToPoint:leftEdge bounce:NO];
    }
    
    CGRect r = CGRectMake( DevicePortraitWindowHeight, 0, floorf( framewidth / 2.0f ), self.view.bounds.size.height );
    
    float centerCenter = floorf( framewidth / 2.0f ),
        rightCenter = floorf( 1.5f * centerCenter );
    
    ZKRelatedList *relatedList = nil;
    
    switch( windowType ) {
        case FlyingWindowRecordOverview:
            fwc = [[RecordOverviewController alloc] initWithFrame:r];
            break;
        case FlyingWindowRecordEditor:
            r.size.width = floorf( framewidth - windowOverlap );
            fwc = [[RecordEditor alloc] initWithFrame:r];
            [(RecordEditor*)fwc setRecord:arg];
            break;
        case FlyingWindowNews:
            fwc = [[RecordNewsViewController alloc] initWithFrame:r];
            
            if( arg ) {
                [(RecordNewsViewController *)fwc setCompoundNewsView:YES];
                [(RecordNewsViewController *)fwc setSearchTerm:arg];
            } else
                NSLog(@"ERR: News view with no search term specified");

            break;
        case FlyingWindowWebView:
            r.size.width = floorf( framewidth - windowOverlap );
            fwc = [[WebViewController alloc] initWithFrame:r];
            [(WebViewController *)fwc loadURL:arg];
            
            rightCenter = framewidth;
            break;
        case FlyingWindowRelatedListGrid:
            r.size.width = floorf( framewidth - windowOverlap );
            
            ZKDescribeLayout *layout = [[SFVUtil sharedSFVUtil] layoutForRecord:[arg objectAtIndex:0]];
            
            for( ZKRelatedList *list in [layout relatedLists] )
                if( [[list sobject] isEqualToString:[arg objectAtIndex:1]] ) {
                    relatedList = list;
                    break;
                }
            
            fwc = [[RelatedListGridView alloc] initWithRelatedList:relatedList inFrame:r];
            
            rightCenter = framewidth;
            break;
        case FlyingWindowListofRelatedLists:            
            fwc = [[ListOfRelatedListsViewController alloc] initWithFrame:r];
            break;
        case FlyingWindowRecentRecords:
            fwc = [[RecentRecordsController alloc] initWithFrame:r];
            break;
        default:
            break;
    }
    
    fwc.detailViewController = self;
    fwc.rootViewController = self.rootViewController;
    fwc.delegate = self;
    fwc.flyingWindowType = windowType;
    
    if( [arg isKindOfClass:[NSArray class]] )
        [fwc selectAccount:[arg objectAtIndex:0]];
    else    
        [fwc selectAccount:arg];
    
    CGPoint center = CGPointMake( rightCenter, floorf( r.size.height / 2.0f ) );
    
    if( [self numberOfFlyingWindows] > 0 ) {
        fwc.leftFWC = [self.flyingWindows lastObject];
        ((FlyingWindowController *)[self.flyingWindows lastObject]).rightFWC = fwc;
    }
    
    if( [fwc isLargeWindow] ) {
        if( [self numberOfFlyingWindows] == 0 )
            center.x = centerCenter - ( windowOverlap / 2.0f );
        else
            center.x = centerCenter + ( windowOverlap / 2.0f );
    } else if( [self numberOfFlyingWindows] == 0 )
        center.x = centerCenter / 2.0f;
    else
        center.x = rightCenter;
        
    [self.flyingWindows addObject:fwc];
    [self.view addSubview:fwc.view];
    
    [fwc slideFlyingWindowToPoint:center bounce:YES];
    [fwc release];
}

- (void) removeFlyingWindowAtIndex:(NSInteger)index reassignNeighbors:(BOOL)reassignNeighbors {
    if( index >= [self numberOfFlyingWindows] )
        return;
    
    FlyingWindowController *fwc = [flyingWindows objectAtIndex:index];
    
    if( reassignNeighbors && fwc.rightFWC && [fwc.rightFWC isViewLoaded] ) {
        if( fwc.leftFWC && [fwc.leftFWC isViewLoaded] )
            fwc.rightFWC.leftFWC = fwc.leftFWC;
        else
            fwc.rightFWC.leftFWC = nil;
    }
    
    if( reassignNeighbors && [fwc.leftFWC isViewLoaded] ) {
        if( fwc.rightFWC && [fwc.rightFWC isViewLoaded] )
            fwc.leftFWC.rightFWC = fwc.rightFWC;
        else
            fwc.leftFWC.rightFWC = nil;
    }
    
    // Hang onto it
    [fwc retain];

    // pop it off the stack
    [self.flyingWindows removeObjectAtIndex:index];
    
    // And animate out
    [UIView animateWithDuration:0.25f
                     animations:^(void) {
                         [fwc.view setAlpha:0.0f];
                     } 
                     completion:^(BOOL finished) {
                         // Farewell, brave soldier
                         [fwc.view removeFromSuperview];
                         [fwc release];
                         
                         // move button
                         [self setPopoverButton:self.browseButton];
                     }];
}


- (void) clearFlyingWindows {
    NSInteger numWindows = [self numberOfFlyingWindows];
    
    if( numWindows == 0 )
        return;
    
    for( int i = 0; i < numWindows; i++ )
        [self removeFlyingWindowAtIndex:0 reassignNeighbors:YES];
}

- (NSInteger) numberOfFlyingWindows {
    if( !self.flyingWindows )
        return 0;
    
    return [self.flyingWindows count];
}

- (NSInteger) numberOfFlyingWindowsOfType:(FlyingWindowType)windowType {
    if( !self.flyingWindows )
        return 0;
    
    int count = 0;
    
    for( FlyingWindowController *fwc in self.flyingWindows )
        if( fwc.flyingWindowType == windowType )
            count++;
    
    return count;
}

- (void) removeFirstFlyingWindowOfType:(FlyingWindowType)windowType {
    if( [self numberOfFlyingWindows] == 0 )
        return;
    
    for( int i = 0; i < [self numberOfFlyingWindows]; i++ )
        if( ((FlyingWindowController *)[flyingWindows objectAtIndex:i]).flyingWindowType == windowType ) {
            [self removeFlyingWindowAtIndex:i reassignNeighbors:YES];
            break;
        }
}

- (NSDictionary *)mostRecentlySelectedRecord {
    if( [self numberOfFlyingWindows] == 0 )
        return nil;
    
    for( int i = [self numberOfFlyingWindows] - 1; i >= 0; i-- )
        if( ((FlyingWindowController *)[self.flyingWindows objectAtIndex:i]).flyingWindowType == FlyingWindowRecordOverview )
            return [[((RecordOverviewController *)[self.flyingWindows objectAtIndex:i]).account copy] autorelease];
    
    return nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
} 

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {    
    [self handleInterfaceRotation:UIInterfaceOrientationIsPortrait(toInterfaceOrientation)];
}

- (void) eventLogInOrOut {   
    [self clearFlyingWindows];

    [self.rootViewController subNavSelectAccountWithId:nil];
    
    if( [self.rootViewController isLoggedIn] )
        [self addFlyingWindow:FlyingWindowRecentRecords withArg:nil];
}

#pragma mark - email and webview

- (void) openEmailComposer:(NSString *)toAddress {
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
        mailViewController.mailComposeDelegate = self;
        [mailViewController setSubject:@""];
        [mailViewController setToRecipients:[NSArray arrayWithObjects:toAddress, nil]];
        
        
        [self.rootViewController.splitViewController presentModalViewController:mailViewController animated:YES];
        [mailViewController release];
    }
}

- (void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {    
    [self.rootViewController.splitViewController dismissModalViewControllerAnimated:YES];
    
    if (result == MFMailComposeResultFailed && error )
        [PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert") 
                            message:[error localizedDescription] 
                        buttonTitle:NSLocalizedString(@"OK",@"OK")];
}

@end
