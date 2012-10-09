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

#import "ZKRelatedList.h"
#import "ZKRelatedListSort.h"
#import "ZKRelatedListColumn.h"
#import "ZKParser.h"


@implementation ZKRelatedList

-(void)dealloc {
	[columns release];
	[sort release];
	[super dealloc];
}

-(BOOL) custom {
	return [self boolean:@"custom"];
}

-(NSString *) field {
	return [self string:@"field"];
}

-(NSString *) name {
	return [self string:@"name"];
}

-(NSString *) label {
	return [self string:@"label"];
}

-(NSString *) sobject {
	return [self string:@"sobject"];
}

- (NSInteger) limitRows {
	return [self integer:@"limitRows"];
}

- (NSArray *) columns {
	if (columns == nil)
		columns = [[self complexTypeArrayFromElements:@"columns" cls:[ZKRelatedListColumn class]] retain];
	return columns;	
}

- (NSArray *) sort {
	if (sort == nil) 
		sort = [[self complexTypeArrayFromElements:@"sort" cls:[ZKRelatedListSort class]] retain];
	return sort;	
}


#pragma mark -
#pragma mark Utility methods

- (NSString *) describe 
{	
	return [NSString stringWithFormat:@"%@ %@ %@ %@ %@",
			[self sobject],
			[self name],
			[self label],
			[self field],
            [self custom] ? @"custom" : @"standard"
		];
}

- (NSString *) removeLastComma :(NSString *) str 
{
	NSRange myRange = {[str length]-1,1};	// remove last comma
	return [str stringByReplacingOccurrencesOfString:@"," withString:@"" options:0 range:myRange ];
}

-(NSString *) normalName: (NSString *) str 
{
	NSRange myRange = {0,[str length]};	
	str = [str stringByReplacingOccurrencesOfString:@"toLabel(" withString:@"" options:0 range:myRange ];
	NSRange bRange = {0,[str length]};
	return [str stringByReplacingOccurrencesOfString:@")" withString:@"" options:0 range:bRange ]; 
}
			
-(NSString *) columnsFieldNames 
{
	NSString *ret = @"";
	for (ZKRelatedListColumn *col in [self columns] ) {
		ret = [ ret stringByAppendingFormat:@"%@,", [self normalName:[col name]] ];
	} 
	return [self removeLastComma:ret];
}

@end