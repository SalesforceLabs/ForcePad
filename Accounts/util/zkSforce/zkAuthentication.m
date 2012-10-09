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

#import "zkAuthentication.h"
#import "ZKPartnerEnvelope.h"
#import "zkParser.h"
#import "zkLoginResult.h"
#import "zkUserInfo.h"

static const int DEFAULT_MAX_SESSION_AGE = 25 * 60; // 25 minutes

@interface ZKAuthInfoBase()
@property (retain) NSString *sessionId;
@property (retain) NSURL *instanceUrl;
@property (retain) NSDate *sessionExpiresAt;
@property (retain) NSString *clientId;
@end

@implementation ZKAuthInfoBase

@synthesize sessionId, instanceUrl, sessionExpiresAt, clientId;

-(void)dealloc {
    [sessionId release];
    [instanceUrl release];
    [sessionExpiresAt release];
    [clientId release];
    [super dealloc];
}

-(void)refresh {
    // override me!
}

-(BOOL)refreshIfNeeded {
	if ((sessionExpiresAt && [sessionExpiresAt timeIntervalSinceNow] < 0) || (sessionId == nil)) {
		[self refresh];    
        return TRUE;
    }
    return FALSE;
}

@end

@implementation ZKOAuthInfo

@synthesize apiVersion, refreshToken, authHostUrl=authUrl;

+(NSDictionary *)decodeParams:(NSString *)params {
    NSMutableDictionary *results = [NSMutableDictionary dictionary];
    for (NSString *param in [params componentsSeparatedByString:@"&"]) {
        NSArray *paramParts = [param componentsSeparatedByString:@"="];
        NSString *name = [[paramParts objectAtIndex:0] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        NSString *val = [paramParts count] == 1 ? @"" : [[paramParts objectAtIndex:1] stringByReplacingPercentEscapesUsingEncoding:NSUTF8StringEncoding];
        [results setObject:val forKey:name];
    }
    if ([results objectForKey:@"error"] != nil)
        @throw [NSException exceptionWithName:@"OAuth Error" 
                                       reason:[NSString stringWithFormat:@"%@ : %@", [results objectForKey:@"error"], [results objectForKey:@"error_description"]]
                                     userInfo:results];
    return results;
}

+(id)oauthInfoFromCallbackUrl:(NSURL *)callbackUrl clientId:(NSString *)cid {
    // callbackUrl will be something:///blah/blah#p=1&q=2&foo=bar
    // we need to get our params out of the callback fragment
    NSDictionary *params = [self decodeParams:[callbackUrl fragment]];

    return [ZKOAuthInfo oauthInfoWithRefreshToken:[params objectForKey:@"refresh_token"]
                                         authHost:[NSURL URLWithString:[params objectForKey:@"id"]]
                                        sessionId:[params objectForKey:@"access_token"]
                                      instanceUrl:[NSURL URLWithString:[params objectForKey:@"instance_url"]]
                                         clientId:cid];
}

+(id)oauthInfoWithRefreshToken:(NSString *)tkn authHost:(NSURL *)auth clientId:(NSString *)cid {
    return [[[ZKOAuthInfo alloc] initWithRefreshToken:tkn authHost:auth sessionId:nil instanceUrl:nil clientId:cid] autorelease];
}

+(id)oauthInfoWithRefreshToken:(NSString *)tkn authHost:(NSURL *)auth sessionId:(NSString *)sid instanceUrl:(NSURL *)inst clientId:(NSString *)cid {
    return [[[ZKOAuthInfo alloc] initWithRefreshToken:tkn authHost:auth sessionId:sid instanceUrl:inst clientId:cid] autorelease];
}

-(id)initWithRefreshToken:(NSString *)tkn authHost:(NSURL *)auth sessionId:(NSString *)sid instanceUrl:(NSURL *)inst clientId:(NSString *)cid {
    self = [super init];
    clientId = [cid retain];
    sessionId = [sid retain];
    refreshToken = [tkn retain];
    instanceUrl = [inst retain];
    authUrl = [[NSURL URLWithString:@"/" relativeToURL:auth] retain];
    self.sessionExpiresAt = [NSDate dateWithTimeIntervalSinceNow:DEFAULT_MAX_SESSION_AGE];
    return self;
}

-(void)dealloc {
    [refreshToken release];
    [authUrl release];
    [super dealloc];
}

-(NSURL *)instanceUrl {
    return [NSURL URLWithString:[NSString stringWithFormat:@"/services/Soap/u/%d.0", apiVersion] relativeToURL:instanceUrl];
}

-(void)refresh {
    NSURL *token = [NSURL URLWithString:@"/services/oauth2/token" relativeToURL:authUrl];
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:token];
    [req setHTTPMethod:@"POST"];
    NSString *params = [NSString stringWithFormat:@"grant_type=refresh_token&refresh_token=%@&client_id=%@&format=urlencoded",
                      [refreshToken stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding], 
                      [clientId stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    [req setHTTPBody:[params dataUsingEncoding:NSUTF8StringEncoding]];
    [req addValue:@"application/x-www-form-urlencoded; charset=UTF-8" forHTTPHeaderField:@"Content-Type"];

 	NSHTTPURLResponse *resp = nil;
	NSError *err = nil;
	NSData *respPayload = [NSURLConnection sendSynchronousRequest:req returningResponse:&resp error:&err];
    NSString *respBody = [[[NSString alloc] initWithBytes:[respPayload bytes] length:[respPayload length] encoding:NSUTF8StringEncoding] autorelease];
    NSDictionary *results = [ZKOAuthInfo decodeParams:respBody];
    
    self.sessionId = [results objectForKey:@"access_token"];
    self.instanceUrl = [NSURL URLWithString:[results objectForKey:@"instance_url"]];
    self.sessionExpiresAt = [NSDate dateWithTimeIntervalSinceNow:DEFAULT_MAX_SESSION_AGE];
}

-(BOOL)refreshIfNeeded {
    BOOL r = [super refreshIfNeeded];
    self.sessionExpiresAt = [NSDate dateWithTimeIntervalSinceNow:DEFAULT_MAX_SESSION_AGE];
    return r;
}

@end

@implementation ZKSoapLogin

-(id)initWithUsername:(NSString *)un password:(NSString *)pwd authHost:(NSURL *)auth apiVersion:(int)v clientId:(NSString *)cid {
    self = [super init];
    username = [un retain];
    password = [pwd retain];
    clientId = [cid retain];
    client = [[ZKBaseClient alloc] init];
	client.endpointUrl = [NSURL URLWithString:[NSString stringWithFormat:@"/services/Soap/u/%d.0", v] relativeToURL:auth];
    return self;
}

-(void)dealloc {
    [username release];
    [password release];
    [client release];
    [super dealloc];
}

-(void)refresh {
    [self login];
}

-(ZKLoginResult *)login {
	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:nil clientId:clientId];
	[env startElement:@"login"];
	[env addElement:@"username" elemValue:username];
	[env addElement:@"password" elemValue:password];
	[env endElement:@"login"];
	[env endElement:@"s:Body"];
	NSString *xml = [env end];
	[env release];
	
	zkElement *resp = [client sendRequest:xml];	
	zkElement *result = [[resp childElements:@"result"] objectAtIndex:0];
	ZKLoginResult *lr = [[[ZKLoginResult alloc] initWithXmlElement:result] autorelease];
	
	self.instanceUrl = [NSURL URLWithString:[lr serverUrl]];
	self.sessionId = [lr sessionId];

	// if we have a sessionSecondsValid in the UserInfo, use that to control when we re-authenticate, otherwise take the default.
	int sessionAge = [[lr userInfo] sessionSecondsValid] > 0 ? [[lr userInfo] sessionSecondsValid] - 60 : DEFAULT_MAX_SESSION_AGE;
	self.sessionExpiresAt = [NSDate dateWithTimeIntervalSinceNow:sessionAge];
	return lr;
}

+(id)soapLoginWithUsername:(NSString *)un password:(NSString *)pwd authHost:(NSURL *)auth apiVersion:(int)v clientId:(NSString *)cid {
    return [[[ZKSoapLogin alloc] initWithUsername:un password:pwd authHost:auth apiVersion:v clientId:cid] autorelease];
}

@end
