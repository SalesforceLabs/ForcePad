//
//  PRPConnection.h
//  NetworkActivityCenter
//
//  Created by Matt Drance on 3/1/10.
//  Copyright 2010 Bookhouse Software, LLC. All rights reserved.
//

#import <UIKit/UIKit.h>

@class PRPConnection;

// START:BlockDefines
typedef void (^PRPConnectionProgressBlock)(PRPConnection *connection);
typedef void (^PRPConnectionCompletionBlock)(PRPConnection *connection, 
                                             NSError *error);
// END:BlockDefines

@interface PRPConnection : NSObject {}

// START:PRPConnectionProperties
@property (nonatomic, copy, readonly)   NSURL *url;
@property (nonatomic, retain, readonly) NSURLRequest *urlRequest;

@property (nonatomic, assign, readonly) NSInteger contentLength;
@property (nonatomic, retain, readonly) NSMutableData *downloadData;
@property (nonatomic, assign, readonly) float percentComplete;
@property (nonatomic, assign) NSUInteger progressThreshold;

// END:PRPConnectionProperties

// START:Creation
+ (id)connectionWithURL:(NSURL *)requestURL
          progressBlock:(PRPConnectionProgressBlock)progress
        completionBlock:(PRPConnectionCompletionBlock)completion;

+ (id)connectionWithRequest:(NSURLRequest *)request
              progressBlock:(PRPConnectionProgressBlock)progress
            completionBlock:(PRPConnectionCompletionBlock)completion;
// END:Creation

- (id)initWithURL:(NSURL *)requestURL
    progressBlock:(PRPConnectionProgressBlock)progress
  completionBlock:(PRPConnectionCompletionBlock)completion;

- (id)initWithRequest:(NSURLRequest *)request
        progressBlock:(PRPConnectionProgressBlock)progress
      completionBlock:(PRPConnectionCompletionBlock)completion;

- (void)start;
- (void)stop;

@end