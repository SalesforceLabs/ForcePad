//
//  PRPConnection.m
//  NetworkActivityCenter
//
//  Created by Matt Drance on 3/1/10.
//  Copyright 2010 Bookhouse Software, LLC. All rights reserved.
//

#import "PRPConnection.h"

@interface PRPConnection ()

@property (nonatomic, retain) NSURLConnection *connection;
@property (nonatomic, copy)   NSURL *url;
@property (nonatomic, retain) NSURLRequest *urlRequest;
@property (nonatomic, retain) NSMutableData *downloadData;
@property (nonatomic, assign) NSInteger contentLength;

@property (nonatomic, assign) float previousMilestone;

@property (nonatomic, copy) PRPConnectionProgressBlock progressBlock;
@property (nonatomic, copy) PRPConnectionCompletionBlock completionBlock;

@end


@implementation PRPConnection

@synthesize url;
@synthesize urlRequest;
@synthesize connection;
@synthesize contentLength;
@synthesize downloadData;
@synthesize progressThreshold;
@synthesize previousMilestone;

@synthesize progressBlock;
@synthesize completionBlock;

- (void)dealloc {
    [url release], url = nil;
    [urlRequest release], urlRequest = nil;
    [connection cancel], [connection release], connection = nil;
    [downloadData release], downloadData = nil;
    [progressBlock release], progressBlock = nil;
    [completionBlock release], completionBlock = nil;
    [super dealloc];
}

+ (id)connectionWithRequest:(NSURLRequest *)request
              progressBlock:(PRPConnectionProgressBlock)progress
            completionBlock:(PRPConnectionCompletionBlock)completion {
    return [[[self alloc] initWithRequest:request
                            progressBlock:progress
                          completionBlock:completion]
            autorelease];
}

+ (id)connectionWithURL:(NSURL *)downloadURL
          progressBlock:(PRPConnectionProgressBlock)progress
        completionBlock:(PRPConnectionCompletionBlock)completion {
    return [[[self alloc] initWithURL:downloadURL
                        progressBlock:progress
                      completionBlock:completion] 
            autorelease];
}

- (id)initWithURL:(NSURL *)requestURL
    progressBlock:(PRPConnectionProgressBlock)progress
  completionBlock:(PRPConnectionCompletionBlock)completion {
    return [self initWithRequest:[NSURLRequest requestWithURL:requestURL]
                   progressBlock:progress
                 completionBlock:completion];
}

- (id)initWithRequest:(NSURLRequest *)request
        progressBlock:(PRPConnectionProgressBlock)progress 
      completionBlock:(PRPConnectionCompletionBlock)completion {
    if ((self = [super init])) {
        self.connection = [[[NSURLConnection alloc] initWithRequest:request delegate:self startImmediately:NO] autorelease];
        self.progressBlock = progress;
        self.completionBlock = completion;
        self.url = [request URL];
        self.progressThreshold = 1.0;
        
        // JH
        //[self.connection scheduleInRunLoop:[NSRunLoop currentRunLoop] forMode:NSRunLoopCommonModes];
    }
    return self;
}

#pragma mark -
#pragma mark 

//START: PPDownloadStartStop
- (void)start {
    [self.connection start];
}

- (void)stop {
    [self.connection cancel];
    self.connection = nil;
    self.downloadData = nil;
    self.contentLength = 0;
}
// END: PPDownloadStartStop

// START:PercentComplete
- (float)percentComplete {
    if (self.contentLength <= 0) return 0;
    return (([self.downloadData length] * 1.0f) / self.contentLength) * 100;
}
// END:PercentComplete

#pragma mark 
#pragma mark NSURLConnectionDelegate
// START:ContentLength
- (void)connection:(NSURLConnection *)connection 
didReceiveResponse:(NSURLResponse *)response {
    if ([response isKindOfClass:[NSHTTPURLResponse class]]) {
        NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
        if ([httpResponse statusCode] == 200) {
            NSDictionary *header = [httpResponse allHeaderFields];
            NSString *contentLen = [header valueForKey:@"Content-Length"];
            self.contentLength = [contentLen integerValue];
            self.downloadData = [NSMutableData dataWithCapacity:self.contentLength];
        }
    }
}
// END:ContentLength

// START:ProgressDelegate
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    [self.downloadData appendData:data];
    float pctComplete = floor([self percentComplete]);
    if ((pctComplete - self.previousMilestone) >= self.progressThreshold) {
        self.previousMilestone = pctComplete;
        if (self.progressBlock) self.progressBlock(self);
    }
}
// END:ProgressDelegate

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"Connection failed");
    if (self.completionBlock) self.completionBlock(self, error);
    [self stop];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    if (self.completionBlock) self.completionBlock(self, nil);
    [self stop];
}

@end