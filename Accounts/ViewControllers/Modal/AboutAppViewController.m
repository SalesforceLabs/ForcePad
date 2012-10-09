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

#import "AboutAppViewController.h"
#import "SFVUtil.h"

@implementation AboutAppViewController

@synthesize aboutScrollView;

static float width = 540.0f;
static float height = 575.0f;

static NSString *sfvSourceURL = @"http://her.sh/sfvsource";

- (id) init {
    if((self = [super init])) {
        if( !self.aboutScrollView ) {
            self.aboutScrollView = [[[UIScrollView alloc] initWithFrame:CGRectMake(0, 0, width, height)] autorelease];
            self.aboutScrollView.showsVerticalScrollIndicator = YES;
            
            [self.view addSubview:self.aboutScrollView];
        }
    }
    
    return self;
}

- (id) initWithAboutPage {
    if((self = [self init])) {
        self.title = [NSString stringWithFormat:@"About %@", [SFVUtil appFullName]];        
        
        UIImage *flaskImage = [UIImage imageNamed:@"flask.png"];
        
        // flask image
        UIImageView *flask = [[[UIImageView alloc] initWithImage:flaskImage] autorelease];
        [flask setFrame:CGRectMake( 10, 10, flaskImage.size.width, flaskImage.size.height)];
        [self.aboutScrollView addSubview:flask];
        
        // about text
        UILabel *aboutText = [[self class] bodyTextLabelWithText:[NSString stringWithFormat:@"%@ is a free open-source app from %@. %@ is the easiest way to browse your data from any Salesforce environment.",
                                                                  [SFVUtil appFullName],
                                                                  LabsOrgName,
                                                                  [SFVUtil appFullName]]
                                                          width:( width - 30 - flaskImage.size.width )];
                
        [aboutText setFrame:CGRectMake( flaskImage.size.width + 20, 10, aboutText.frame.size.width, aboutText.frame.size.height )];            
        
        [self.aboutScrollView addSubview:aboutText];
        
        // Additional text
        UILabel *moreText = [[self class] bodyTextLabelWithText:[NSString stringWithFormat:@"%@ is a program that enables salesforce.com engineers, professional services staff, and other salesforce.com employees to share applications they've created with the salesforce.com customer community. Inspired by employees' work with customers of all sizes and industries, these apps range from simple utilities to entire vertical solutions.\n\n%@ applications are free to use, but are not official salesforce.com products, and should be considered community projects - these apps are not officially tested or documented. For support on any %@ app please consult the Successforce message boards - salesforce.com support is not available for these applications.",
                                                                 LabsOrgName,
                                                                 LabsOrgName,
                                                                 LabsOrgName]
                                                          width:width - 20];
        
        [moreText setFrame:CGRectMake( 10, flaskImage.size.height + 20, moreText.frame.size.width, moreText.frame.size.height )];            
        
        [self.aboutScrollView addSubview:moreText];
        
        // Github button
        UIButton *gitHubButton = [UIButton buttonWithType:UIButtonTypeRoundedRect];
            
        [gitHubButton setTitle:[NSString stringWithFormat:@"%@ on GitHub", [SFVUtil appFullName]] forState:UIControlStateNormal];
        [gitHubButton addTarget:self
                              action:@selector(tappedGitHubButton:)
                    forControlEvents:UIControlEventTouchUpInside];
        
        CGPoint origin = CGPointCenteredOriginPointForRects( aboutScrollView.frame, CGRectMake(0, 0, floorf( width / 2.0f ), 35));
        
        [gitHubButton setFrame:CGRectMake( origin.x, CGRectGetMaxY(moreText.frame) + 10, floorf( width / 2.0f ), 35 )];
        
        [self.aboutScrollView addSubview:gitHubButton];
        
        // attribution
        UILabel *attributionLabel = [[[UILabel alloc] init] autorelease];
        attributionLabel.numberOfLines = 0;
        attributionLabel.text = @"© 2012 Salesforce.com\na @jhersh production";
        attributionLabel.textAlignment = UITextAlignmentCenter;
        attributionLabel.shadowColor = [UIColor whiteColor];
        attributionLabel.shadowOffset = CGSizeMake( 0, 1 );
        attributionLabel.backgroundColor = [UIColor clearColor];
        [attributionLabel setFont:[UIFont boldSystemFontOfSize:13]];
        attributionLabel.textColor = RGB( 57.0f, 85.0f, 135.0f );
        
        [attributionLabel sizeToFit];
        origin = CGPointCenteredOriginPointForRects(aboutScrollView.frame, attributionLabel.frame);
        
        [attributionLabel setFrame:CGRectMake( origin.x, CGRectGetMaxY(aboutScrollView.frame) - CGRectGetHeight(attributionLabel.frame), 
                                              CGRectGetWidth(attributionLabel.frame), CGRectGetHeight(attributionLabel.frame) )];
        
        [self.aboutScrollView addSubview:attributionLabel];
    }
    
    [self.aboutScrollView setContentSize:CGSizeMake( width, height + 1)];
    [self.aboutScrollView setContentOffset:CGPointZero animated:NO];
    
    return self;
}

- (id) initWithFAQ {
    if((self = [self init])) {
        self.title = [NSString stringWithFormat:@"%@ FAQ", [SFVUtil appFullName]];
        
        float curY = 10.0f;
        
        NSArray *questions = [NSArray arrayWithObjects:
                              [NSString stringWithFormat:@"Is there support for %@?", [SFVUtil appFullName]],
                              @"How is my data secured?",
                              @"Where does the news and map data come from?",
                              [NSString stringWithFormat:@"Can I connect %@ to my Sandbox, Pre-release environment, or other custom host?", [SFVUtil appFullName]],
                              @"I have a feature request!",
                              nil];
        
        NSArray *answers = [NSArray arrayWithObjects:
                            [NSString stringWithFormat:@"%@, like other %@ apps, is free, unofficial, and unsupported. If you have questions, comments, or bug reports, see %@ on GitHub, ask a question of the customer community at success.salesforce.com/answers, or email the developer at jhersh@salesforce.com.", 
                             [SFVUtil appFullName],
                             LabsOrgName,
                             [SFVUtil appFullName]],
                            [NSString stringWithFormat:@"Neither Salesforce records nor your login credentials are ever stored on the device. %@ connects to Salesforce securely with OAuth.",
                                [SFVUtil appFullName]],
                            @"News results are powered by Google News and addresses are geocoded with Google's geocoding service. Record names and addresses are always encrypted over HTTPS.",
                            @"Absolutely! On the login window, tap the gear icon to select Production or Sandbox as your login host or enter your own custom host.",
                            [NSString stringWithFormat:@"We're always interested in your feature requests and ideas for %@ and other Mobile Appexchange Labs apps. Voice your opinion on success.salesforce.com/answers and let us know! You can also contact the developer at jhersh@salesforce.com, or @jhersh on Twitter.",
                                [SFVUtil appFullName]],
                            nil];
        
        for( int x = 0; x < [questions count]; x++ ) {
            UILabel *qtitle = [[self class] headerTextLabelWithText:[questions objectAtIndex:x] width:width - 20];
            [qtitle setFrame:CGRectMake( 10, curY, qtitle.frame.size.width, qtitle.frame.size.height )];
            
            [self.aboutScrollView addSubview:qtitle];
            
            curY += qtitle.frame.size.height + 5.0f;
            
            UILabel *qbody = [[self class] bodyTextLabelWithText:[answers objectAtIndex:x] width:width - 20];
            [qbody setFrame:CGRectMake( 10, curY, qbody.frame.size.width, qbody.frame.size.height )];
            
            [self.aboutScrollView addSubview:qbody];
            
            curY += qbody.frame.size.height + 10.0f;
        }
        
        [self.aboutScrollView setContentSize:CGSizeMake( width, MAX( curY, height + 1 ) )];
        [self.aboutScrollView setContentOffset:CGPointZero animated:NO];
    }
    
    return self;
}

- (id) initWithEULA {
    if((self = [self init])) {
        self.title = [NSString stringWithFormat:@"%@ EULA", [SFVUtil appFullName]];
        
        NSString *eulapath = [[NSBundle mainBundle] pathForResource:@"eula" ofType:@"txt"];
        NSString *eulastr = [NSString stringWithContentsOfFile:eulapath encoding:NSUTF8StringEncoding error:nil];
        
        UILabel *eulaLabel = [[self class] bodyTextLabelWithText:eulastr width:(width - 20)];
        
        [eulaLabel setFrame:CGRectMake( 10, 10, eulaLabel.frame.size.width, eulaLabel.frame.size.height )];
        
        [self.aboutScrollView addSubview:eulaLabel];
        [self.aboutScrollView setContentOffset:CGPointZero animated:NO];
        [self.aboutScrollView setContentSize:CGSizeMake( width, eulaLabel.frame.size.height + 20 )];
    }
    
    return self;
}

- (void) tappedGitHubButton:(id)sender {    
    [[UIApplication sharedApplication] openURL:[NSURL URLWithString:sfvSourceURL]];
}

+ (UILabel *) bodyTextLabelWithText:(NSString *)text width:(float)width {
    UILabel *label = [[UILabel alloc] init];
    label.numberOfLines = 0;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor darkTextColor];
    [label setFont:[UIFont fontWithName:@"Verdana" size:15]];
    
    label.text = text;
    
    CGSize s = [text sizeWithFont:label.font constrainedToSize:CGSizeMake( width, 9999 )];
    
    [label setFrame:CGRectMake(0, 0, s.width, s.height )];    
    
    return [label autorelease];
}

+ (UILabel *) headerTextLabelWithText:(NSString *)text width:(float)width {
    UILabel *label = [[UILabel alloc] init];
    label.numberOfLines = 0;
    label.backgroundColor = [UIColor clearColor];
    label.textColor = [UIColor darkGrayColor];
    label.shadowColor = [UIColor whiteColor];
    label.shadowOffset = CGSizeMake( 0, 1 );
    [label setFont:[UIFont fontWithName:@"HelveticaNeue" size:20]];
    
    label.text = text;
    
    CGSize s = [text sizeWithFont:label.font constrainedToSize:CGSizeMake( width, 9999 )];
    
    [label setFrame:CGRectMake(0, 0, s.width, s.height )];    
    
    return [label autorelease];
}

- (void)dealloc {
    self.aboutScrollView = nil;
    [super dealloc];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark - View lifecycle

- (void)viewDidUnload {
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

@end
