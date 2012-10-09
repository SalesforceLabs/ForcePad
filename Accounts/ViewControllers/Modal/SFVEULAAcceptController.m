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

#import "SFVEULAAcceptController.h"
#import "SFVUtil.h"
#import "AboutAppViewController.h"

@implementation SFVEULAAcceptController

@synthesize delegate;

- (id) init {
    if(( self = [super init] )) {
        self.view.frame = CGRectMake(0, 0, 540, 575);
        
        self.title = @"EULA";
        
        scrollView = [[UIScrollView alloc] initWithFrame:self.view.frame];
        [self.view addSubview:scrollView];
        
        NSString *eulapath = [[NSBundle mainBundle] pathForResource:@"eula" ofType:@"txt"];
        NSString *eulastr = [NSString stringWithContentsOfFile:eulapath encoding:NSUTF8StringEncoding error:nil];
        UILabel *eulaLabel = [AboutAppViewController bodyTextLabelWithText:eulastr width:CGRectGetWidth(self.view.frame) - 20];
        
        CGPoint origin = CGPointCenteredOriginPointForRects(self.view.frame, CGRectMake(0, 0, CGRectGetWidth(eulaLabel.frame), CGRectGetHeight(eulaLabel.frame)));
        
        eulaLabel.frame = CGRectMake( origin.x, 5, CGRectGetWidth(eulaLabel.frame), CGRectGetHeight(eulaLabel.frame));
        [scrollView addSubview:eulaLabel];
        
        [scrollView setContentSize:CGSizeMake( CGRectGetWidth(self.view.frame), CGRectGetMaxY(eulaLabel.frame) + 5)];
        [scrollView setContentOffset:CGPointZero];
    }
    
    return self;
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    
    if( !self.navigationItem.rightBarButtonItem ) {
        UIBarButtonItem *acceptButton = [[[UIBarButtonItem alloc] initWithTitle:NSLocalizedString(@"Accept", @"Accept")
                                                                          style:UIBarButtonItemStyleBordered
                                                                         target:self
                                                                         action:@selector(didAcceptEula:)] autorelease];
        
        [self.navigationItem setRightBarButtonItem:acceptButton animated:YES];
    }
}

- (void) didAcceptEula:(id)sender {
    if( [self.delegate respondsToSelector:@selector(EULADidAccept:)] )
        [self.delegate EULADidAccept:self];
}

- (void) dealloc {
    SFRelease(scrollView);
    delegate = nil;
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
