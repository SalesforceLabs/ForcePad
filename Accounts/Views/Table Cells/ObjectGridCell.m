/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh.com
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

#import "ObjectGridCell.h"
#import <QuartzCore/QuartzCore.h>
#import "SFVAppDelegate.h"
#import "SFVUtil.h"

@implementation ObjectGridCell

@synthesize gridLabel, gridImage;

+ (NSString *)cellIdentifier {
    return NSStringFromClass([self class]);
}

+ (id)cellForGridView:(AQGridView *)gridView {
    NSString *cellID = [self cellIdentifier];
    AQGridViewCell *cell = [gridView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[[self alloc] initWithCellIdentifier:cellID] autorelease];
    }
    return cell;    
}

- (id)initWithCellIdentifier:(NSString *)cellID {
    if ((self = [super initWithFrame:CGRectMake( 0, 0, floorf( masterWidth / 2.2f ), floorf( masterWidth / 2.2f ) ) reuseIdentifier:cellID])) {
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundColor = [UIColor clearColor];
        self.selectionStyle = AQGridViewCellSelectionStyleNone;
        
        if( !self.gridLabel ) {
            self.gridLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
            self.gridLabel.backgroundColor = [UIColor clearColor];
            self.gridLabel.textAlignment = UITextAlignmentCenter;
            self.gridLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:13];
            self.gridLabel.textColor = [UIColor whiteColor];
            self.gridLabel.shadowOffset = CGSizeMake( 0, 2 );
            self.gridLabel.shadowColor = [UIColor darkTextColor];
            self.gridLabel.numberOfLines = 3;
            
            [self.contentView addSubview:gridLabel];      
        }
        
        gridImageView = [[UIImageView alloc] initWithFrame: CGRectMake(0.0, 0.0, 32.0, 32.0)];
        gridImageView.backgroundColor = [UIColor clearColor];
        gridImageView.opaque = NO;
        
        [self.contentView addSubview:gridImageView];
        
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundColor = [UIColor clearColor];
        self.contentView.opaque = NO;
        self.opaque = NO;
        
        self.selectionStyle = AQGridViewCellSelectionStyleNone;
        
        UIBezierPath * path = [UIBezierPath bezierPathWithRoundedRect:CGRectInset( self.frame, 3, 3 )
                                                         cornerRadius:18.0];
        
        self.layer.shadowPath = path.CGPath;
        self.layer.shadowOffset = CGSizeMake( 0, -5 );
        self.layer.shadowRadius = 10.0f;
        self.layer.shadowOpacity = 0.3f;
    }
    
    return self;
}

- (UIImage *) icon {
    return gridImageView.image;
}

- (void) setGridImage:(UIImage *)image {
    gridImageView.image = image;
}

- (void) layoutCell {
    float curY = 10.0f;
    
    // Position image
    CGSize s = [self icon].size;
    CGRect fr = self.frame;
    
    [gridImageView setFrame:CGRectMake( lroundf( ( fr.size.width - s.width ) / 2.0f ), curY, s.width, s.height )];   
    
    curY += s.height + 5;
    
    // Position label underneath
    s = [gridLabel.text sizeWithFont:gridLabel.font constrainedToSize:CGSizeMake( fr.size.width - 10, fr.size.height - curY )];
    [gridLabel setFrame:CGRectMake( lroundf( ( fr.size.width - s.width ) / 2.0f ), curY, s.width, s.height )];
}

- (void) dealloc {
    [gridLabel release];
    [gridImage release];
    [super dealloc];
}

@end