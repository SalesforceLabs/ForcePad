/***
 * Excerpted from "iOS Recipes",
 * published by The Pragmatic Bookshelf.
 * Copyrights apply to this code. It may not be used to create training material, 
 * courses, books, articles, and the like. Contact us if you are in doubt.
 * We make no guarantees that this code is fit for any purpose. 
 * Visit http://www.pragmaticprogrammer.com/titles/cdirec for more book information.
***/
//
//  SlideInView.m
//  SlideInView
//
//  Created by Paul Warren on 11/19/09.
//  Copyright 2009 Primitive Dog Software. All rights reserved.
//

#import "SlideInView.h"

@implementation SlideInView

@synthesize adjustY;
@synthesize adjustX;
@synthesize imageSize;



+ (id)viewWithImage:(UIImage *)SlideInImage {
	
   SlideInView *SlideIn = [[[SlideInView alloc] init] autorelease];
   SlideIn.imageSize = SlideInImage.size;
   SlideIn.layer.bounds = CGRectMake(0, 0, SlideIn.imageSize.width,
                                           SlideIn.imageSize.height);
   SlideIn.layer.anchorPoint = CGPointMake(0, 0);
   SlideIn.layer.position = CGPointMake(-SlideIn.imageSize.width, 0);	
   SlideIn.layer.contents = (id)SlideInImage.CGImage;	
   return SlideIn;
}

- (void)awakeFromNib {
	
   self.imageSize = self.frame.size;
   self.layer.bounds = CGRectMake(0, 0, self.imageSize.width, 
                                        self.imageSize.height);
   self.layer.anchorPoint = CGPointMake(0, 0);
   self.layer.position = CGPointMake(-self.imageSize.width, 0);
}

- (void)showWithTimer:(CGFloat)timer inView:(UIView *)view 
				 from:(SlideInViewSide)side bounce:(BOOL)bounce {
	
    self.adjustX = 0;
    self.adjustY = 0;
    CGPoint fromPos;
    switch (side) {              //  align view and set adjustment value
      case SlideInViewTop:
        self.adjustY = self.imageSize.height;
        fromPos = CGPointMake(view.frame.size.width/2-self.imageSize.width/2,
                               -self.imageSize.height);
        break;
      case SlideInViewBot:
         self.adjustY = -self.imageSize.height;
         fromPos = CGPointMake(view.frame.size.width/2-self.imageSize.width/2,
                               view.bounds.size.height);
         break;
      case SlideInViewLeft:
         self.adjustX = self.imageSize.width;
         fromPos = CGPointMake(-self.imageSize.width, 
                            view.frame.size.height/2-self.imageSize.height/2);
			break;
      case SlideInViewRight:
         self.adjustX = -self.imageSize.width;
         fromPos = CGPointMake(view.bounds.size.width, 
                            view.frame.size.height/2-self.imageSize.height/2);
      break;
      default:
         return;
	}
	
    if (bounce) {
        
        CGPoint toPos = fromPos;
        CGPoint bouncePos = fromPos;
        bouncePos.x += (adjustX*1.2);
        bouncePos.y += (adjustY*1.2);
        toPos.x += adjustX;
        toPos.y	+= adjustY;
		
        CAKeyframeAnimation *keyFrame = [CAKeyframeAnimation 
                                         animationWithKeyPath:@"position"];
        keyFrame.values  =  [NSArray arrayWithObjects:
                            [NSValue valueWithCGPoint:fromPos],
                            [NSValue valueWithCGPoint:bouncePos],
                            [NSValue valueWithCGPoint:toPos],
                            [NSValue valueWithCGPoint:bouncePos],
                            [NSValue valueWithCGPoint:toPos],
                            nil];
        keyFrame.keyTimes = [NSArray arrayWithObjects:
                            [NSNumber numberWithFloat:0],
                            [NSNumber numberWithFloat:.18],
                            [NSNumber numberWithFloat:.5],
                            [NSNumber numberWithFloat:.75],
                            [NSNumber numberWithFloat:1],
                            nil];
		
        keyFrame.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        
        keyFrame.duration = .75;          // Use a longer duration to allow for bounce time
        self.layer.position = toPos;      // ensures that the layer stays in it's final position
        
        [self.layer addAnimation:keyFrame forKey:@"keyFrame"];
        
    } else {                              // Use implicit animation to slide in image
        
        CGPoint toPos = fromPos;
        toPos.x += adjustX;
        toPos.y	+= adjustY;
        
        CABasicAnimation *basic = [CABasicAnimation animationWithKeyPath:@"position"];
        basic.fromValue = [NSValue valueWithCGPoint:fromPos];
        basic.toValue = [NSValue valueWithCGPoint:toPos];
        self.layer.position = toPos;
        [self.layer addAnimation:basic forKey:@"basic"];		
	}

    popInTimer = [NSTimer scheduledTimerWithTimeInterval:timer 
                                                  target:self 
                                                selector:@selector(popIn) 
                                                userInfo:nil 
                                                 repeats:NO];
	
    [view addSubview:self];
}


-(void)popIn {                            // Use explicit animation to slide out image

	[UIView beginAnimations:@"slideIn" context:nil];
	self.frame = CGRectOffset(self.frame, -adjustX, -adjustY);
	[UIView commitAnimations];
		
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[popInTimer invalidate];
	[self popIn];
}

- (void)dealloc {
    [super dealloc];
}


@end




