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

#import "SFVUtil.h"
#import "AQGridView.h"
#import "AccountGridCell.h"

@implementation AccountGridCell

@synthesize gridLabel, gridButton;

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
    if ((self = [super initWithFrame:CGRectZero reuseIdentifier:cellID])) {
        self.selectionStyle = AQGridViewCellSelectionStyleNone;
        self.contentView.backgroundColor = [UIColor clearColor];
        self.backgroundColor = [UIColor clearColor];
        
        if( !self.gridLabel ) {
            self.gridLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
            self.gridLabel.backgroundColor = [UIColor clearColor];
            self.gridLabel.textAlignment = UITextAlignmentLeft;
            self.gridLabel.font = [UIFont fontWithName:@"HelveticaNeue-Bold" size:13];
            self.gridLabel.textColor = [UIColor lightGrayColor];
            
            [self.contentView addSubview:gridLabel];      
        }
    }
    
    return self;
}

- (void) setupCellWithButton:(NSString *)label buttonType:(enum FieldType)buttonType buttonText:(NSString *)buttonText detailText:(NSString *)detailText {
    self.gridLabel.text = label;
    
    if( self.gridButton ) {
        [self.gridButton removeFromSuperview];
        self.gridButton = nil;
    }
    
    if( ![SFVUtil isEmpty:buttonText] ) {
        self.gridButton = [FieldPopoverButton buttonWithText:( buttonType == URLField ? [SFVUtil truncateURL:buttonText] : buttonText )
                                                   fieldType:buttonType 
                                                  detailText:detailText];
        self.gridButton.titleLabel.numberOfLines = 2;
        self.gridButton.titleLabel.textAlignment = UITextAlignmentLeft;
        [self.gridButton.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:16]];
        [self.gridButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
        [self.contentView addSubview:self.gridButton];
    }
}

- (void) layoutCell {
    CGRect r;
    
    [self.gridLabel sizeToFit];
    r = self.gridLabel.frame;
    
    r.origin.x = 10;
    r.origin.y = 5;
    [self.gridLabel setFrame:r];
    
    FieldPopoverButton *gb = (FieldPopoverButton *)self.gridButton;
    
    if( gb ) {
        [gb sizeToFit];

        r = gb.frame;    
        r.origin.x = 10;
        r.origin.y = CGRectGetMaxY(self.gridLabel.frame) + 10;

        CGSize s = [[gb titleForState:UIControlStateNormal] sizeWithFont:gb.titleLabel.font constrainedToSize:CGSizeMake( self.contentView.frame.size.width - 15, 25)];
        
        if( s.width < 10 )
            s.width = self.contentView.frame.size.width - 15;
        
        r.size.height = floorf( s.height );
        r.size.width = floorf( s.width );
                
        [gb setFrame:r];
    }
}

- (void) dealloc {
    [gridLabel release];
    [super dealloc];
}

@end