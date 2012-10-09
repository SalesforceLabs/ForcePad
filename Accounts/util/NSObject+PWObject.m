// http://cargocult.squarespace.com/blog/2012/2/23/perform-block-after-delay.html

#import "NSObject+PWObject.h"
#import "SFVUtil.h"

FIX_CATEGORY_BUG(PWObject);

@implementation NSObject (PWObject)

- (void)performBlock:(void (^)(void))block afterDelay:(NSTimeInterval)delay {
    int64_t delta = (int64_t)(1.0e9 * delay);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, delta), dispatch_get_main_queue(), block);
}

@end

