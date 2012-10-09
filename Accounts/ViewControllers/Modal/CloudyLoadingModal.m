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

/* Go buy yourself something nice.
 _____________________________________________________________________
 |.============[_F_E_D_E_R_A_L___R_E_S_E_R_V_E___N_O_T_E_]============.|
 ||%&%&%&%_    _        _ _ _   _ _  _ _ _     _       _    _ %&%&%&%&||
 ||%&%&%&/||_||_ | ||\||||_| \ (_ ||\||_(_  /\|_ |\|V||_|)|/ |\ \%&%&%||
 ||&%.--.}|| ||_ \_/| ||||_|_/ ,_)|||||_,_) \/|  ||| ||_|\|\_||{.--.%&||
 ||%/__ _\                ,-----,-'____'-,-----,               /__ _\ ||
 ||||_ / \|              [    .-;"`___ `";-.    ]             ||_ / \|||
 |||  \| || """""""""" 1  `).'.'.'`_ _'.  '.'.(` A 76355942 J |  \| ||||
 |||,_/\_/|                //  / .'    '\    \\               |,_/\_/|||
 ||%\    /   d8888b       //  | /   _  _ |    \\      .-"""-.  \    /%||
 ||&%&--'   8P |) Y8     ||   //;   a \a \     ||    //A`Y A\\  '--'%&||
 ||%&%&|    8b |) d8     ||   \\ '.   _> .|    ||    ||.-'-.||   |&%&%||
 ||%&%&|     Y8888P      ||    `|  `-'_ ` |    ||    \\_/~\_//   |&%&%||
 ||%%%%|                 ||     ;'.  ' ` /     ||     '-...-'    |%&%&||
 ||%&%&|  A 76355942 J  /;\  _.-'. `-..'`>-._  /;\               |%&%&||
 ||&%.--.              (,  ':     \; >-'`    ;` ,)              .--.%&||
 ||%( 50 ) 1  """""""  _( \  ;...---""---...; / )_```"""""""1  ( 50 )%||
 ||&%'--'============\`----------,----------------`/============'--'%&||
 ||%&JGS&%&%&%&%&&%&%&) F I F T Y   D O L L A R S (%&%&%&%&%&%&&%&%&%&||
 '"""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""""`
 */

#import "CloudyLoadingModal.h"
#import "SFVUtil.h"

@implementation CloudyLoadingModal

- (id) init {
    if(( self = [super init] )) {        
        [self.view setFrame:CGRectMake(0, 0, 540, 570 )];
        [self.view addSubview:[[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"cloudybg.png"]] autorelease]];
        self.title = NSLocalizedString(@"Authenticating...", nil);
        
        self.modalPresentationStyle = UIModalPresentationFormSheet;
        self.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
        
        activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
        CGSize s = [activityIndicator sizeThatFits:CGSizeZero];
        CGPoint origin = CGPointCenteredOriginPointForRects(self.view.frame, 
                                                            CGRectMake(0, 0, s.width, s.height));
        [activityIndicator setFrame:CGRectMake( origin.x, origin.y - 22, s.width, s.height )];
        
        loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake( 0, CGRectGetMaxY(activityIndicator.frame) + 5, CGRectGetWidth(self.view.frame), 25)];
        loadingLabel.textColor = [UIColor whiteColor];
        loadingLabel.backgroundColor = [UIColor clearColor];
        loadingLabel.font = [UIFont boldSystemFontOfSize:22];
        loadingLabel.textAlignment = UITextAlignmentCenter;
        loadingLabel.text = @"OHAY";
        [self.view addSubview:loadingLabel];
        
        [self randomizeLoadingLabel];
        
        [self.view addSubview:activityIndicator];
        [activityIndicator startAnimating];
        
        timer = [NSTimer scheduledTimerWithTimeInterval:1.75f
                                                 target:self
                                               selector:@selector(randomizeLoadingLabel)
                                               userInfo:nil
                                                repeats:YES]; 
    }
    
    return self;
}

- (void) randomizeLoadingLabel {
    NSArray *phrases = [NSArray arrayWithObjects:
                       @"Making it rain...",
                       @"Reticulating splines...",
                       @"You look nice today.",
                       @"I'm on a horse.",
                       nil];
    
    NSArray *verbs = [NSArray arrayWithObjects:
                      @"Empowering",
                      @"Engineering",
                      @"Synergizing",
                      @"Leveraging",
                      @"Buffering",
                      @"Distributing",
                      @"Enhancing",
                      @"Optimizing",
                      @"Delivering",
                      @"Energizing",
                      @"Productizing",
                      @"Iterating",
                      @"Parallelizing",
                      @"Configuring",
                      @"Bucketizing",
                      @"Grokking",
                      @"Maximizing",
                      @"Bifurcating",
                      @"Disintermediating",
                      nil];
    
    NSArray *adjectives = [NSArray arrayWithObjects:
                           @"synergized",
                           @"non-volatile",
                           @"inflammable",
                           @"adaptive",
                           @"tertiary",
                           @"didactic",
                           @"dynamic",
                           @"global",
                           @"syncopated",
                           nil];
    
    NSArray *nouns = [NSArray arrayWithObjects:
                      @"synergies",
                      @"leverage",
                      @"complexity",
                      @"paradigms",
                      @"methodologies",
                      @"matrices",
                      @"systems",
                      @"variables",
                      @"practices",
                      nil];
    
    [UIView animateWithDuration:0.1
                     animations:^{
                         loadingLabel.alpha = 0.0f;
                     }
                     completion:^(BOOL finished) {                         
                         if( arc4random() % 10 < 2 )
                             loadingLabel.text = [phrases objectAtIndex:( arc4random() % [phrases count] )];
                         else
                             loadingLabel.text = [NSString stringWithFormat:@"%@ %@ %@...",
                                                     [verbs objectAtIndex:( arc4random() % [verbs count])],
                                                     [adjectives objectAtIndex:( arc4random() % [adjectives count])],
                                                     [nouns objectAtIndex:( arc4random() % [nouns count])]];
                         
                         [UIView animateWithDuration:0.1f
                                          animations:^{
                                              loadingLabel.alpha = 1.0f; 
                                          }];
                     }];
}

- (void) viewDidDisappear:(BOOL)animated {   
    [activityIndicator stopAnimating];
    [timer invalidate];
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void) dealloc {    
    SFRelease(activityIndicator);
    SFRelease(loadingLabel);
    timer = nil;
    [super dealloc];
}

@end
