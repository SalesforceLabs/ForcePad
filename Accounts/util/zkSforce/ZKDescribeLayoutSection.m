// Copyright (c) 2010 Ron Hess
//
// Permission is hereby granted, free of charge, to any person obtaining a 
// copy of this software and associated documentation files (the "Software"), 
// to deal in the Software without restriction, including without limitation
// the rights to use, copy, modify, merge, publish, distribute, sublicense, 
// and/or sell copies of the Software, and to permit persons to whom the 
// Software is furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included 
// in all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS 
// OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, 
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE 
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER 
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, 
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN 
// THE SOFTWARE.
//

#import "ZKDescribeLayoutSection.h"
#import "ZKDescribeLayoutRow.h"
#import "ZKXmlDeserializer.h"
#import "ZKParser.h"


@implementation ZKDescribeLayoutSection 

-(void)dealloc {
	[layoutRows release];
	[super dealloc];
}

-(BOOL) useCollapsibleSection {
	return [self boolean:@"useCollapsibleSection"];
}

-(BOOL) useHeading {
	return [self boolean:@"useHeading"];
}

-(NSString *) recordTypeId {
	return [self string:@"recordTypeId"];
}

-(NSString *) heading {
	return [self string:@"heading"];
}

-(NSInteger ) columns {
	return [self integer:@"columns"];
}

-(NSInteger ) rows {
	return [self integer:@"rows"];
}

- (NSArray *) layoutRows {
	if (layoutRows == nil) 
		layoutRows = [[self complexTypeArrayFromElements:@"layoutRows" cls:[ZKDescribeLayoutRow class]] retain];
	return layoutRows;
}

@end