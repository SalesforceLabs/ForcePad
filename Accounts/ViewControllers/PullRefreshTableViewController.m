//
//  PullRefreshTableViewController.m
//  Plancast
//
//  Created by Leah Culver on 7/2/10.
//  Copyright (c) 2010 Leah Culver
//
//  Permission is hereby granted, free of charge, to any person
//  obtaining a copy of this software and associated documentation
//  files (the "Software"), to deal in the Software without
//  restriction, including without limitation the rights to use,
//  copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the
//  Software is furnished to do so, subject to the following
//  conditions:
//
//  The above copyright notice and this permission notice shall be
//  included in all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
//  EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
//  OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
//  NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
//  HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
//  WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
//  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
//  OTHER DEALINGS IN THE SOFTWARE.
//

// JH modified to add last refresh times and an auto-updating timer

#import <QuartzCore/QuartzCore.h>
#import "PullRefreshTableViewController.h"
#import "SFVUtil.h"
#import "SFVAppDelegate.h"
#import "UIImage+ImageUtils.h"

#define REFRESH_HEADER_HEIGHT 52.0f
#define PULLTEXT NSLocalizedString(@"Pull down to Refresh", @"Pull to refresh")
#define RELEASETEXT NSLocalizedString(@"Release to Refresh", @"Release to refresh")
#define LOADINGTEXT NSLocalizedString(@"Loading...", @"Loading...")

@implementation PullRefreshTableViewController

@synthesize lastRefresh, refreshHeaderView, refreshLabel, refreshArrow, refreshSpinner, useHeaderImage;

- (id)initWithStyle:(UITableViewStyle)style {
    self = [super initWithStyle:style];
    self.useHeaderImage = NO;

    return self;
}

- (id)initWithStyle:(UITableViewStyle)style useHeaderImage:(BOOL)uHI {
    self = [self initWithStyle:style];
    self.useHeaderImage = uHI;
    
    return self;
}

- (void)viewDidLoad {    
    [self addPullToRefreshHeader];
    
    [super viewDidLoad];
}

- (void)addPullToRefreshHeader {    
    refreshHeaderView = [[UIView alloc] initWithFrame:CGRectMake( 0, 0 - REFRESH_HEADER_HEIGHT, masterWidth, REFRESH_HEADER_HEIGHT)];
    refreshHeaderView.backgroundColor = [UIColor clearColor];
    
    int curX = 10;
    
    // background image
    if( useHeaderImage ) {
        curX = 90;
        /*UIImage *bg = [UIImage imageNamed:@"refreshHeader.png"];
        
        UIImageView *bgImage = [[UIImageView alloc] initWithImage:bg];
        [bgImage setFrame:CGRectMake(0, - ( bg.size.height - REFRESH_HEADER_HEIGHT ), bg.size.width, bg.size.height)];
        [refreshHeaderView addSubview:bgImage];
        [bgImage release];*/
    }
    
    UIImage *arrowImage = [[UIImage imageNamed:@"arrow_white.png"] imageAtScale];
    
    refreshArrow = [[UIImageView alloc] initWithImage:arrowImage];
    refreshArrow.frame = CGRectMake( curX,
                                    (REFRESH_HEADER_HEIGHT - 25) / 2,
                                    arrowImage.size.width, arrowImage.size.height);
    
    refreshSpinner = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    refreshSpinner.frame = CGRectMake( curX, (REFRESH_HEADER_HEIGHT - 20) / 2, 20, 20);
    refreshSpinner.hidesWhenStopped = YES;
    
    curX += 10;

    refreshLabel = [[UILabel alloc] initWithFrame:CGRectMake( curX, 0, 200, REFRESH_HEADER_HEIGHT)];
    refreshLabel.backgroundColor = [UIColor clearColor];
    refreshLabel.font = [UIFont boldSystemFontOfSize:13.0];
    refreshLabel.textColor = [UIColor whiteColor];
    refreshLabel.textAlignment = UITextAlignmentCenter;
    
    lastRefresh = [[UILabel alloc] initWithFrame:CGRectMake( curX, 15, 200, REFRESH_HEADER_HEIGHT)];
    lastRefresh.backgroundColor = [UIColor clearColor];
    lastRefresh.textColor = [UIColor lightGrayColor];
    lastRefresh.font = [UIFont systemFontOfSize:12.0];
    lastRefresh.textAlignment = UITextAlignmentCenter;
    
    if( useHeaderImage ) {
        refreshLabel.font = [UIFont boldSystemFontOfSize:14];
        refreshLabel.textColor = UIColorFromRGB(0x333333);
        lastRefresh.textColor = [UIColor darkTextColor];
    }

    [refreshHeaderView addSubview:refreshLabel];
    [refreshHeaderView addSubview:refreshArrow];
    [refreshHeaderView addSubview:refreshSpinner];
    [refreshHeaderView addSubview:lastRefresh];
    [self.tableView addSubview:refreshHeaderView];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    if (isLoading) return;
    isDragging = YES;
}

- (void)scrollViewDidScroll:(UIScrollView *)scrollView {
    if (isLoading) {
        // Update the content inset, good for section headers
        if (scrollView.contentOffset.y > 0)
            self.tableView.contentInset = UIEdgeInsetsZero;
        else if (scrollView.contentOffset.y >= -REFRESH_HEADER_HEIGHT)
            self.tableView.contentInset = UIEdgeInsetsMake(-scrollView.contentOffset.y, 0, 0, 0);
    } else if (isDragging && scrollView.contentOffset.y < 0) {
        // Update the arrow direction and label
        [UIView beginAnimations:nil context:NULL];
        if (scrollView.contentOffset.y < -REFRESH_HEADER_HEIGHT) {
            // User is scrolling above the header
            refreshLabel.text = RELEASETEXT;
            [refreshArrow layer].transform = CATransform3DMakeRotation(M_PI, 0, 0, 1);
        } else { // User is scrolling somewhere within the header
            refreshLabel.text = PULLTEXT;
            [refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
        }
        [UIView commitAnimations];
    }
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    if (isLoading) return;
    isDragging = NO;
    if (scrollView.contentOffset.y <= -REFRESH_HEADER_HEIGHT) {
        // Released above the header
        [self startLoading];
    }
}

- (void)startLoading {
    isLoading = YES;
    
    // If we have an update timer going, end it
    if( updateTimer )
        [updateTimer invalidate], updateTimer = nil;

    // Show the header
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDuration:0.3];
    self.tableView.contentInset = UIEdgeInsetsMake(REFRESH_HEADER_HEIGHT, 0, 0, 0);
    refreshLabel.text = LOADINGTEXT;
    refreshArrow.hidden = YES;
    [refreshSpinner startAnimating];
    [UIView commitAnimations];

    // Refresh action!
    [self refresh];
}

- (void)stopLoading {
    isLoading = NO;
    
    // Update the last refresh time
    /*NSLocale *locale = [NSLocale currentLocale];
    NSDateFormatter *formatter = [[[NSDateFormatter alloc] init] autorelease]; 
    NSString *dateFormat = [NSDateFormatter dateFormatFromTemplate:@"MMM d yyyy h:mm" options:0 locale:locale];
    [formatter setDateFormat:dateFormat];
    [formatter setLocale:locale];*/
    
    
    lastRefreshTime = [[NSDate date] retain];
    lastRefresh.text = [NSString stringWithFormat:@"%@: %@", 
                        NSLocalizedString(@"Last Update", @"last update"),
                        [SFVUtil relativeTime:lastRefreshTime]];
    
    // Start the update timer, if it has been stopped
    if( !updateTimer )
        updateTimer = [NSTimer scheduledTimerWithTimeInterval:5.0
                                                       target:self
                                                     selector:@selector(updateRefreshTime)
                                                     userInfo:nil
                                                      repeats:YES];

    // Hide the header
    [UIView beginAnimations:nil context:NULL];
    [UIView setAnimationDelegate:self];
    [UIView setAnimationDuration:0.3];
    [UIView setAnimationDidStopSelector:@selector(stopLoadingComplete:finished:context:)];
    self.tableView.contentInset = UIEdgeInsetsZero;
    [refreshArrow layer].transform = CATransform3DMakeRotation(M_PI * 2, 0, 0, 1);
    [UIView commitAnimations];
}

- (void) updateRefreshTime {     
    lastRefresh.text = [NSString stringWithFormat:@"%@: %@", 
                        NSLocalizedString(@"Last Update", @"last update"),
                        [SFVUtil relativeTime:lastRefreshTime]];
}

- (void)stopLoadingComplete:(NSString *)animationID finished:(NSNumber *)finished context:(void *)context {
    // Reset the header
    refreshLabel.text = PULLTEXT;
    refreshArrow.hidden = NO;
    [refreshSpinner stopAnimating];
}

- (void)refresh {
    // This is just a demo. Override this method with your custom reload action.
    // Don't forget to call stopLoading at the end.
    //[self performSelector:@selector(stopLoading) withObject:nil afterDelay:2.0];
    if( self.tableView.dataSource != self ) {
        if( [self.tableView.dataSource respondsToSelector:@selector(refresh:)] )
            [self.tableView.dataSource performSelector:@selector(refresh:) withObject:[NSNumber numberWithBool:YES]];
        else if( [self.tableView.dataSource respondsToSelector:@selector(refresh)] )
            [self.tableView.dataSource performSelector:@selector(refresh)];
    }
}

- (void)dealloc {
    [refreshHeaderView release];
    [refreshLabel release];
    [refreshArrow release];
    [refreshSpinner release];
    [lastRefresh release];
    [lastRefreshTime release];
    updateTimer = nil;
    
    [super dealloc];
}

@end
