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
#import "ObjectLookupController.h"
#import "TextCell.h"

// Fields used in the post
#define kBodyField      @"body"
#define kLinkField      @"linkUrl"
#define kTitleField     @"title"
#define kParentField    @"parentId"
#define kParentName     @"parentName"
#define kParentType     @"parentType"

@protocol ChatterPostDelegate;

@interface ChatterPostController : UIViewController <UITableViewDelegate, UITableViewDataSource, ObjectLookupDelegate, UIPopoverControllerDelegate, TextCellDelegate> {
}

@property (nonatomic, retain) UIBarButtonItem *postButton;
@property (nonatomic, retain) UITableView *postTable;
@property (nonatomic, retain) NSMutableDictionary *postDictionary;
@property (nonatomic, retain) UIPopoverController *searchPopover;

@property (nonatomic, assign) id <ChatterPostDelegate> delegate;

typedef enum PostTableRows {
    PostParent = 0,
    PostLink,
    PostTitle,
    PostBody,
    PostTableNumRows
} PostTableRow;

// This uses a dictionary with these key-value pairs:
// "link" : "URL of the post to share" - REQUIRED
// "title" : "title of the article" - REQUIRED
// "parentId" : id of the parent object for this post
// "parentName" : name of the parent object for this post
// "body" : "post body"
- (id) initWithPostDictionary:(NSDictionary *)dict;

- (void) updatePostDictionary:(NSDictionary *)dict;
- (void) submitPost;
- (void) cancel;
- (BOOL) canSubmitPost;

- (void) rotationEvent;

// return true if the user has changed any value in this post.
// if so, we prevent them from accidentally tapping to close
- (BOOL) isDirty;

@end

// START:Delegate
@protocol ChatterPostDelegate <NSObject>

@required

// called when we have successfully inserted a chatter post
- (void) chatterPostDidPost:(ChatterPostController *)chatterPostController;

// called when the cancel button is pressed
- (void) chatterPostDidDismiss:(ChatterPostController *)chatterPostController;

@optional

// called if there's any error when creating a chatter post
- (void) chatterPostDidFailWithError:(ChatterPostController *)chatterPostController error:(NSError *)e;

@end
// END:Delegate