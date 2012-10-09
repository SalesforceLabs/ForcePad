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

#import "AppPickerCell.h"
#import "SFVUtil.h"
#import <QuartzCore/QuartzCore.h>

@implementation AppPickerCell

@synthesize appImageView;

- (id)initWithCellIdentifier:(NSString *)cellID {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID])) {  
        self.textLabel.numberOfLines = 0;
        self.textLabel.font = [UIFont boldSystemFontOfSize:17];
        self.textLabel.textColor = [UIColor whiteColor];
        self.textLabel.shadowColor = [UIColor darkGrayColor];
        self.textLabel.shadowOffset = CGSizeMake(1, 2);
        self.textLabel.textAlignment = UITextAlignmentCenter;
        
        // app image
        self.appImageView = [[[UIImageView alloc] initWithFrame:CGRectZero] autorelease];
        appImageView.layer.cornerRadius = 8.0f;
        appImageView.layer.masksToBounds = YES;
        
        [self.contentView addSubview:appImageView];
    }
    
    return self;
}

- (void) layoutSubviews {  
    [super layoutSubviews];
    
    CGRect b = [self bounds];
    b.origin.x = 0;
    b.size.width -= CGRectGetWidth(self.accessoryView.frame);
    [self.contentView setFrame:b];
        
    // center image
    if( appImageView.image ) {
        CGSize s = appImageView.image.size;
        
        appImageView.frame = CGRectMake( floorf( ( CGRectGetWidth(self.contentView.frame) - s.width ) / 2.0f ), 5, s.width, s.height );       
        [self.contentView addSubview:appImageView];
    } else
        [appImageView removeFromSuperview];
            
    if( appImageView ) {
        CGRect r = self.textLabel.frame;
        r.origin.x = floorf( ( CGRectGetWidth(self.contentView.frame) - r.size.width ) / 2.0f );
        r.origin.y += floorf( CGRectGetMaxY(appImageView.frame) / 2.0f );
        [self.textLabel setFrame:r];
        [self.contentView addSubview:self.textLabel];
    }
}

- (void) dealloc {
    [appImageView release];
    [super dealloc];
}

@end
