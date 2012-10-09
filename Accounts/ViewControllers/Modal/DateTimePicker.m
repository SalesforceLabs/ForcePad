/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Jonathan Hersh jhersh@salesforce.com
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

#import "DateTimePicker.h"
#import "SFVUtil.h"
#import "SFVAsync.h"
#import "SFVAppCache.h"

@interface DateTimePicker (Private)
- (void) pickerDateChanged:(UIDatePicker *)sender;
- (void) clearDatePicker:(id)sender;
- (void) setTimeToNow:(id)sender;
@end

@implementation DateTimePicker

@synthesize dateTimeDelegate, allowsClearingFieldValue;

+ (DateTimePicker *)dateTimePicker {
    DateTimePicker *pickerVC = [[DateTimePicker alloc] init];
    pickerVC.allowsClearingFieldValue = NO;
    
    UIDatePicker *picker = [[[UIDatePicker alloc] init] autorelease];
    
    [picker addTarget:pickerVC
               action:@selector(pickerDateChanged:)
     forControlEvents:UIControlEventValueChanged];
    
    [picker setDatePickerMode:UIDatePickerModeDate];
    
    pickerVC.view.backgroundColor = [UIColor darkGrayColor];
    pickerVC.contentSizeForViewInPopover = [picker sizeThatFits:CGSizeZero];
    
    pickerVC.picker = picker;
    
    // working around the world's most idiotic bug
    // http://omegadelta.net/2010/06/04/ipad-simulator-crashes-if-a-uidatepicker-is-in-a-uipopovercontroller/
    [pickerVC.view addSubview:picker];
        
    return [pickerVC autorelease];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
        
    if( self.allowsClearingFieldValue )
        self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc]
                                initWithBarButtonSystemItem:UIBarButtonSystemItemTrash
                                                     target:self
                                                     action:@selector(clearDatePicker:)] autorelease];
    
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc]
                                                     initWithTitle:(self.picker.datePickerMode == UIDatePickerModeDate
                                                                    ? NSLocalizedString(@"Today", @"Today")
                                                                    : NSLocalizedString(@"Now", @"Now"))
                                                     style:UIBarButtonItemStyleBordered
                                                     target:self
                                                     action:@selector(setTimeToNow:)] autorelease];
    
    [self pickerDateChanged:self.picker];
}

- (void)dealloc {
    self.dateTimeDelegate = nil;
    self.picker = nil;
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark - picker setup

- (void)setDatePickerDate:(NSDate *)date {
    self.picker.date = date;
    
    [self pickerDateChanged:self.picker];
}

- (void)setDateTimePickerTitle:(NSString *)title {    
    self.title = title;
}

- (void)setDatePickerMode:(UIDatePickerMode)mode {
    self.picker.datePickerMode = mode;
}

#pragma mark - picker action

- (void)setTimeToNow:(id)sender {    
    [self.picker setDate:[NSDate date]
                animated:YES];
    
    [self pickerDateChanged:self.picker];
}

- (void)pickerDateChanged:(UIDatePicker *)sender {
    if( self.dateTimeDelegate && [self.dateTimeDelegate respondsToSelector:@selector(dateTimePicker:didChangeToDate:)] )
        [self.dateTimeDelegate dateTimePicker:self didChangeToDate:[sender date]];
}

- (void)clearDatePicker:(id)sender {
    if( self.dateTimeDelegate && [self.dateTimeDelegate respondsToSelector:@selector(dateTimePickerDidClearFieldValue:)] )
        [self.dateTimeDelegate dateTimePickerDidClearFieldValue:self];
}

@end
