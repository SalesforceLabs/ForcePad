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

#import <UIKit/UIKit.h>
#import "SFVUtil.h"

@protocol ObjectLookupDelegate;

@interface ObjectLookupController : UIViewController <UITableViewDelegate, UITableViewDataSource, UISearchBarDelegate> {
    BOOL searching;
    NSInteger objectsToCheck, objectsChecked;
    UITableView *resultTable;
    NSMutableDictionary *searchResults;
    UILabel *resultLabel;
    UIImageView *searchIcon;
    NSMutableDictionary *searchScope;
}

@property (nonatomic, retain) UISearchBar *searchBar;

@property (nonatomic, assign) id <ObjectLookupDelegate> delegate;

// if YES, only searches chatter-enabled objects
@property (nonatomic) BOOL onlyShowChatterEnabledObjects;

// use nil to search all objects, otherwise a dictionary where key = sObject name, value = NSString for that object's SOSL clause 
// example search clause: @"id, name ORDER BY name asc"
- (id) initWithSearchScope:(NSDictionary *)scope;

// generate generic search scope for an object
+ (NSString *) searchScopeForObject:(NSString *)object;

- (void) search;
- (void) loadNamesForRecords:(NSArray *)records;
- (void) receivedObjectResponse:(NSArray *)records;

- (void) loadRecentRecordsFromMetadata;

@end

// START:Delegate
@protocol ObjectLookupDelegate <NSObject>

@required

// The lookup controller calls this function when the user performs a search and selects a record from the result set.
- (void)objectLookupDidSelectRecord:(ObjectLookupController *)objectLookupController record:(NSDictionary *)record;

@optional

- (void)objectLookupDidSearch:(ObjectLookupController *)objectLookupController search:(NSString *)search;

@end
// END:Delegate