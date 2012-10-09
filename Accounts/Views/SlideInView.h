/***
 * Excerpted from "iOS Recipes",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material, 
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose. 
 * Visit http://www.pragmaticprogrammer.com/titles/cdirec for more book information.
***/
//
//  SlideInView.h
//  SlideInView
//
//  Created by Paul Warren on 11/19/09.
//  Copyright 2009 Primitive Dog Software. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <QuartzCore/QuartzCore.h>

typedef enum {	
	SlideInViewTop,
	SlideInViewBot, 
	SlideInViewLeft, 
	SlideInViewRight, 
} SlideInViewSide;

@interface SlideInView : UIView {
	
	NSTimer *popInTimer;

}

@property CGFloat adjustY;
@property CGFloat adjustX;
@property CGSize imageSize;

+ (id)viewWithImage:(UIImage *)SlideInImage;

- (void)showWithTimer:(CGFloat)timer inView:(UIView *)view from:(SlideInViewSide)side bounce:(BOOL)bounce;

@end





