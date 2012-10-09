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

// given a JSON response from google news, this cell can configure itself to display that article
// and an associated image

#import "NewsTableViewCell.h"
#import "SFVUtil.h"
#import "RecordNewsViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "UIImage+ImageUtils.h"

@implementation NewsTableViewCell

@synthesize articleBrief, headline, articleJSON, articleImageView, articleSource, recordNewsViewController;

- (id)initWithCellIdentifier:(NSString *)cellID {
    if ((self = [super initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellID])) {
        self.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        
        // article image
        articleImageView = [[UIImageView alloc] initWithFrame:CGRectZero];
        articleImageView.layer.borderColor = UIColorFromRGB(0x999999).CGColor;
        articleImageView.layer.borderWidth = 1.0f;

        [self.contentView addSubview:articleImageView];
        
        // headline
        headline = [[UILabel alloc] init];
        headline.numberOfLines = 2;
        headline.backgroundColor = [UIColor clearColor];
        [headline setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:22]];
        headline.textColor = [UIColor darkTextColor];
        [self.contentView addSubview:headline];
        
        // article source
        articleSource = [[UILabel alloc] init];
        articleSource.backgroundColor = [UIColor clearColor];
        [articleSource setFont:[UIFont fontWithName:@"ArialHebrew" size:15]];
        articleSource.textColor = UIColorFromRGB(0x666666);
        articleSource.numberOfLines = 1;
        [self.contentView addSubview:articleSource];
        
        // article brief
        articleBrief = [[UILabel alloc] init];
        articleBrief.backgroundColor = [UIColor clearColor];
        articleBrief.textColor = UIColorFromRGB(0x333333);
        [articleBrief setFont:[UIFont fontWithName:@"HelveticaNeue" size:14]];
        articleBrief.numberOfLines = 4;
        articleBrief.adjustsFontSizeToFitWidth = NO;
        [self.contentView addSubview:articleBrief];
        
        self.selectedBackgroundView = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"leftgradient.png"]] autorelease];
    }
    
    return self;
}

- (void) setCellWidth:(float)width {
    cellWidth = width;
}

- (void) setArticleImage:(UIImage *)image {    
    if( !image ) {
        [articleImageView setImage:nil];
        articleImageView.hidden = YES;
        return;
    }
        
    CGSize size = image.size, maxSize = [recordNewsViewController maxImageSize];
    
    float imgMaxDim = MAX( size.width, size.height ), targetMaxDim = MAX( maxSize.width, maxSize.height );
    float scale = 1.0;
    CGSize targetSize = CGSizeZero;
    
    if( imgMaxDim > targetMaxDim ) {
        scale = targetMaxDim / imgMaxDim;
        targetSize = CGSizeMake( scale * size.width, scale * size.height );
    }
    
    if( !CGSizeEqualToSize( targetSize, CGSizeZero ) )
        image = [image imageResizedToSize:targetSize];
    
    [articleImageView setImage:image];
    articleImageView.hidden = NO;
}

- (void) setArticle:(NSDictionary *)article {    
    self.articleJSON = [article retain];
    
    // headline
    headline.text = [SFVUtil stringByDecodingEntities:[articleJSON objectForKey:@"titleNoFormatting"]];
    
    // article source
    NSDateFormatter *dateFormat = [[NSDateFormatter alloc] init];
    [dateFormat setLocale:[NSLocale currentLocale]];
    [dateFormat setDateFormat:@"EEE, dd MMM yyyy H:m:s Z"];
    
    NSDate *date = [dateFormat dateFromString:[articleJSON objectForKey:@"publishedDate"]];
    [dateFormat release];
    
    NSString *pubTime = [SFVUtil relativeTime:date];
    
    articleSource.text = [NSString stringWithFormat:@"%@ — %@", [articleJSON objectForKey:@"publisher"], pubTime];
    
    // article brief
    articleBrief.text = [articleJSON objectForKey:@"content"];
    articleBrief.text = [SFVUtil stripHTMLTags:articleBrief.text];
    articleBrief.text = [SFVUtil stringByDecodingEntities:articleBrief.text];
}

- (void) layoutCell {
    float curY = 10, curX = 15, availableWidth = cellWidth - curX;
    
    // Article headline  
    CGSize s = [headline.text sizeWithFont:headline.font
                         constrainedToSize:CGSizeMake(availableWidth, 50)
                             lineBreakMode:UILineBreakModeWordWrap];
    [headline setFrame:CGRectMake( curX, lroundf(curY), s.width, s.height)];
    
    curY += headline.frame.size.height + 5;
    
    // Article source
    [articleSource setFrame:CGRectMake( curX, lroundf(curY), availableWidth, 20)];
    
    curY += articleSource.frame.size.height;
    
    // Article Image
    if( !articleImageView.hidden ) { 
        CGRect imageRect = CGRectMake( curX, lroundf(curY + 5), articleImageView.image.size.width, articleImageView.image.size.height );
        
        if( self.tag % 2 == 0 ) {
            imageRect.origin.x = curX;
            curX += articleImageView.image.size.width + 15;
        } else
            imageRect.origin.x = cellWidth - articleImageView.image.size.width;
        
        availableWidth -= imageRect.size.width + 15;
        [articleImageView setFrame:imageRect];
    }
    
    // Article brief    
    s = [articleBrief.text sizeWithFont:articleBrief.font
                      constrainedToSize:CGSizeMake(availableWidth, 80)
                          lineBreakMode:UILineBreakModeWordWrap];
    [articleBrief setFrame:CGRectMake( curX, lroundf(curY), s.width, s.height )];
}

- (void) dealloc {
    [headline release];
    [articleBrief release];
    [articleImageView release];
    [articleSource release];
    [articleJSON release];
    [super dealloc];
}

@end