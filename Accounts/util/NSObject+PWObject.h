// http://cargocult.squarespace.com/blog/2012/2/23/perform-block-after-delay.html

#import <Foundation/Foundation.h>

@interface NSObject (PWObject)

- (void)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay;

@end