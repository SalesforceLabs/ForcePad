//
//  PRPAlertView.h
//  PRPAlertView
//
//  Created by Matt Drance on 1/24/11.
//  Copyright 2011 Bookhouse Software LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

// START:PRPAlertBlock
typedef void(^PRPAlertBlock)(void);
// END:PRPAlertBlock

@interface PRPAlertView : UIAlertView {}

// START:ShowNoHandler
+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message
          buttonTitle:(NSString *)buttonTitle;
// END:ShowNoHandler

// START:ShowWithTitle
+ (void)showWithTitle:(NSString *)title
              message:(NSString *)message 
          cancelTitle:(NSString *)cancelTitle 
          cancelBlock:(PRPAlertBlock)cancelBlock
           otherTitle:(NSString *)otherTitle
           otherBlock:(PRPAlertBlock)otherBlock;
// END:ShowWithTitle

@end
