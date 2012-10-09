// From @drance's most excellent iOS Recipes book.

#import "PRPSmartTableViewCell.h"

@implementation PRPSmartTableViewCell

// START:CellIdentifier
+ (NSString *)cellIdentifier {
    return NSStringFromClass([self class]);
}
// END:CellIdentifier

// START:CellForTableView
+ (id)cellForTableView:(UITableView *)tableView {
    NSString *cellID = [self cellIdentifier];
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellID];
    if (cell == nil) {
        cell = [[[self alloc] initWithCellIdentifier:cellID] autorelease];
    }
    return cell;    
}
// END:CellForTableView


// START:CellInit
- (id)initWithCellIdentifier:(NSString *)cellID {
    if ((self = [super initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:cellID])) {

    }
    return self;
}
// END:CellInit

@end