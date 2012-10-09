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
#import "zkSforce.h"
#import "SFVUtil.h"

@protocol FollowButtonDelegate;

@interface FollowButton : UIBarButtonItem <UIActionSheetDelegate> {}

enum FollowButtonState {
    FollowError = 0,
    FollowLoading,
    FollowFollowing,
    FollowNotFollowing,
};

@property enum FollowButtonState followButtonState;

@property (nonatomic, retain) NSString *parentId;
@property (nonatomic, retain) NSString *followId;
@property (nonatomic, retain) UIActionSheet *sheet;

@property (nonatomic, assign) id <FollowButtonDelegate> delegate;

+ (id) followButtonWithParentId:(NSString *)pId;
+ (UIBarButtonItem *) loadingBarButtonItem;

- (void) buttonTapped:(FollowButton *)sender;
- (void) loadTitle;
- (void) loadFollowState;
- (void) toggleFollow;
- (void) changeStateToState:(enum FollowButtonState)state isUserAction:(BOOL)isUserAction;

@end

// START:Delegate
@protocol FollowButtonDelegate <NSObject>

@optional

- (void) followButtonWillChangeState:(FollowButton *)followButton toState:(enum FollowButtonState)state isUserAction:(BOOL)isUserAction;
- (void) followButtonDidChangeState:(FollowButton *)followButton toState:(enum FollowButtonState)state isUserAction:(BOOL)isUserAction;
- (void) followButtonDidReceiveError:(FollowButton *)followButton error:(NSError *)error;

@end
// END:Delegate
