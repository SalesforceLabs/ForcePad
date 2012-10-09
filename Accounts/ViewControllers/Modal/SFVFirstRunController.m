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

#import "SFVFirstRunController.h"
#import "SFVUtil.h"
#import <QuartzCore/QuartzCore.h>
#import "SFVEULAAcceptController.h"

@implementation SFVFirstRunController

@synthesize delegate, pageControl, scrollView;

static CGFloat const kWindowWidth = 540.0f;
static CGFloat const kWindowHeight = 570.0f;

- (id) init {
    if((self = [super init])) {
        self.title = [NSString stringWithFormat:@"%@ %@!", 
                      NSLocalizedString(@"Welcome to", @"Welcome to"),
                      [SFVUtil appFullName]];
        self.view.backgroundColor = UIColorFromRGB(0xdddddd);
        [self.view setFrame:CGRectMake( 0, 0, kWindowWidth, kWindowHeight )];
        
        pageControlBeingUsed = NO;
        
        float curY = 10;
                
        CGRect r;
        CGSize textSize;
        
        UILabel *swipeLabel = [[UILabel alloc] initWithFrame:CGRectZero];
        swipeLabel.backgroundColor = [UIColor clearColor];
        swipeLabel.font = [UIFont boldSystemFontOfSize:17];
        swipeLabel.textColor = [UIColor darkGrayColor];
        swipeLabel.numberOfLines = 0;
        swipeLabel.text = NSLocalizedString(@"FIRSTRUNINTRO", @"firstrun - Swipe left and right intro string");
        swipeLabel.textAlignment = UITextAlignmentCenter;
        
        textSize = [swipeLabel.text sizeWithFont:swipeLabel.font constrainedToSize:CGSizeMake( kWindowWidth - 20, 60 )];
        
        r = swipeLabel.frame;
        r.size = textSize;
        r.origin = CGPointMake( lroundf(( kWindowWidth - r.size.width ) / 2.0f), curY );
        
        [swipeLabel setFrame:r];
        
        [self.view addSubview:swipeLabel];
        [swipeLabel release];
        
        curY += swipeLabel.frame.size.height + 20;
        
        self.scrollView = [[[UIScrollView alloc] initWithFrame:CGRectMake( 0, curY, kWindowWidth, kWindowHeight - curY - 30 )] autorelease];
        self.scrollView.pagingEnabled = YES;
        self.scrollView.delegate = self;
        self.scrollView.showsHorizontalScrollIndicator = NO;
        self.scrollView.showsVerticalScrollIndicator = NO;
        
        [self.view addSubview:self.scrollView];
                
        NSArray *images = [NSArray arrayWithObjects:
                           [UIImage imageNamed:@"firstrun6.png"],
                           [UIImage imageNamed:@"firstrun4.png"],
                           [UIImage imageNamed:@"firstrun5.png"], 
                           [UIImage imageNamed:@"firstrun1.png"], 
                           [UIImage imageNamed:@"firstrun2.png"],
                           [UIImage imageNamed:@"flask.png"],
                           nil];
        NSArray *imageCaptions = [NSArray arrayWithObjects:
                                  NSLocalizedString(@"FIRSTRUN6", @"Editing records"),
                                  NSLocalizedString(@"FIRSTRUN4", @"View full record detail for any Account."),
                                  NSLocalizedString(@"FIRSTRUN5", @"Share links with any user or group in Chatter."),
                                  NSLocalizedString(@"FIRSTRUN1", @"first-run 1"),
                                  NSLocalizedString(@"FIRSTRUN2", @"first-run 2"),
                                  NSLocalizedString(@"FIRSTRUNLABS", @"Labs first-run."),
                                  nil];
        
        CGPoint origin;
        
        for (int i = 0; i < images.count; i++) {
            CGRect frame;
            
            frame.size = ((UIImage *)[images objectAtIndex:i]).size;
            
            origin = CGPointCenteredOriginPointForRects(scrollView.frame, CGRectMake(0, 0, frame.size.width, frame.size.height));
            
            frame.origin.x = ( CGRectGetWidth(scrollView.frame) * i ) + origin.x; 
            frame.origin.y = 0;
            
            UIImageView *imageView = [[UIImageView alloc] initWithImage:[images objectAtIndex:i]];
            [imageView setFrame:frame];
            imageView.layer.cornerRadius = 8.0f;
            imageView.layer.masksToBounds = YES;
            
            [self.scrollView addSubview:imageView];
            
            UILabel *caption = [[UILabel alloc] initWithFrame:CGRectZero];
            caption.backgroundColor = [UIColor clearColor];
            caption.text = [imageCaptions objectAtIndex:i];
            caption.numberOfLines = 0;
            caption.textAlignment = UITextAlignmentCenter;
            caption.textColor = [UIColor darkGrayColor];
            caption.font = [UIFont systemFontOfSize:16];    
            
            textSize = [caption.text sizeWithFont:caption.font constrainedToSize:CGSizeMake( CGRectGetWidth(self.scrollView.frame) - 80, 300 )];
            frame.size = textSize;
            origin = CGPointCenteredOriginPointForRects(self.scrollView.frame, frame);
            
            frame.origin = CGPointMake( ( CGRectGetWidth(self.scrollView.frame) * i ) + origin.x, 
                                   CGRectGetMaxY(imageView.frame) + 5);
            
            [caption setFrame:frame];
            
            [self.scrollView addSubview:caption];
            [imageView release];
            [caption release];
        }
        
        self.scrollView.contentSize = CGSizeMake(self.scrollView.frame.size.width * images.count, self.scrollView.frame.size.height);
        
        self.pageControl = [[[UIPageControl alloc] initWithFrame:CGRectZero] autorelease];
        self.pageControl.currentPage = 0;
        self.pageControl.numberOfPages = [images count];
        [self.pageControl addTarget:self action:@selector(changePage) forControlEvents:UIControlEventValueChanged];
        self.pageControl.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
        
        CGSize pageSize = [self.pageControl sizeForNumberOfPages:pageControl.numberOfPages];
        pageSize.width += 16;
        pageSize.height -= 10;
        
        origin = CGPointCenteredOriginPointForRects(self.view.frame, CGRectMake(0, 0, pageSize.width, pageSize.height));
        
        [self.pageControl setFrame:CGRectMake( origin.x, kWindowHeight - pageSize.height - 10, 
                                              pageSize.width, pageSize.height )];
        
        pageControl.layer.cornerRadius = 6.0f;
        pageControl.backgroundColor = [UIColor lightGrayColor];
        
        [self.view addSubview:self.pageControl];
    }
    
    return self;
}

- (void) viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    // This is kind of a hack to see if we're displaying on first run
    // or instead at a later time, via the settings app, in which case we don't need a done button.
    
    NSArray *vcs = [((UINavigationController *)self.parentViewController) viewControllers];
    
    if( [[vcs objectAtIndex:0] isMemberOfClass:[SFVEULAAcceptController class]] )
        [self.navigationItem setRightBarButtonItem:[[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                                target:self
                                                                                                  action:@selector(completeFirstRun)] autorelease] 
                                          animated:YES];
    else
        self.navigationItem.rightBarButtonItem = nil;
}

- (IBAction)changePage {
    // update the scroll view to the appropriate page
    CGRect frame;
    frame.origin.x = self.scrollView.frame.size.width * self.pageControl.currentPage;
    frame.origin.y = 0;
    frame.size = self.scrollView.frame.size;
    [self.scrollView scrollRectToVisible:frame animated:YES];
}

- (void)scrollViewDidScroll:(UIScrollView *)sender {
	if (!pageControlBeingUsed) {
		// Switch the indicator when more than 50% of the previous/next page is visible
		CGFloat pageWidth = self.scrollView.frame.size.width;
		int page = floor((self.scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
		self.pageControl.currentPage = page;
	}
}

- (void) completeFirstRun {
    if( [self.delegate respondsToSelector:@selector(firstRunDidComplete:)] )
        [self.delegate firstRunDidComplete:self];
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
	pageControlBeingUsed = NO;
}

- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
	pageControlBeingUsed = NO;
}

- (BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation {
    return YES;
}

- (void) viewDidUnload {
    self.pageControl = nil;
    self.scrollView = nil;
    
    [super viewDidUnload];
}

- (void) dealloc {
    [pageControl release];
    [scrollView release];
    delegate = nil;
    
    [super dealloc];
}

@end