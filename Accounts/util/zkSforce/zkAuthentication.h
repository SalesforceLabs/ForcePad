// Copyright (c) 2011 Simon Fell
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

#import "zkBaseClient.h"

@class ZKLoginResult;
@class ZKBaseClient;

@protocol ZKAuthenticationInfo 

-(NSString *)sessionId;     // return an API Session ID.
-(NSURL *)instanceUrl;      // return the full URL to the soap endpoint for the authentication user.
-(void)refresh;             // force the sessionId to be refreshed.
-(BOOL)refreshIfNeeded;     // refresh the sesion if its needed. (this gets called before every soap call)
                            // return true if the session was refreshed.

@end

// base class with common auth code in.
@interface ZKAuthInfoBase : NSObject <ZKAuthenticationInfo> {
    NSURL  *instanceUrl;
    NSDate *sessionExpiresAt;
    NSString *sessionId;
    NSString *clientId;
}

@end

// Impl of ZKAuthenticationInfo that uses an OAuth2 refresh token to generate new session Ids.
@interface ZKOAuthInfo : ZKAuthInfoBase {
    NSString *refreshToken;
    NSURL *authUrl;
    int apiVersion;
}

+(id)oauthInfoFromCallbackUrl:(NSURL *)callbackUrl clientId:(NSString *)cid;
+(id)oauthInfoWithRefreshToken:(NSString *)tkn authHost:(NSURL *)auth clientId:(NSString *)cid;
+(id)oauthInfoWithRefreshToken:(NSString *)tkn authHost:(NSURL *)auth sessionId:(NSString *)sid instanceUrl:(NSURL *)inst clientId:(NSString *)cid;

-(id)initWithRefreshToken:(NSString *)tkn authHost:(NSURL *)authUrl sessionId:(NSString *)sid instanceUrl:(NSURL *)inst clientId:(NSString *)cid;

@property (assign) int apiVersion;
@property (readonly) NSURL *authHostUrl;
@property (readonly) NSString *refreshToken;
@end


// Impl of ZKAuthenticationInfo that uses Soap Login calls to generate new session Ids.
@interface ZKSoapLogin : ZKAuthInfoBase {
    NSString *username, *password;
    ZKBaseClient *client;
}

+(id)soapLoginWithUsername:(NSString *)un password:(NSString *)pwd authHost:(NSURL *)auth apiVersion:(int)v clientId:(NSString *)cid;

-(ZKLoginResult *)login;

@end