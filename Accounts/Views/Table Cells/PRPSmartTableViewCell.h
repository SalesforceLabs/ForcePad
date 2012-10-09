// From @drance's most excellent iOS Recipes book.

#import <UIKit/UIKit.h>

@interface PRPSmartTableViewCell : UITableViewCell {}

+ (NSString *)cellIdentifier;
+ (id)cellForTableView:(UITableView *)tableView;

- (id)initWithCellIdentifier:(NSString *)cellID;

@end