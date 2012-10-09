// Copyright (c) 2006-2011 Simon Fell
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


#import "zkSforceClient.h"
#import "zkPartnerEnvelope.h"
#import "zkQueryResult.h"
#import "zkSaveResult.h"
#import "zkSObject.h"
#import "zkSoapException.h"
#import "zkUserInfo.h"
#import "zkDescribeSObject.h"
#import "zkLoginResult.h"
#import "zkDescribeGlobalSObject.h"
#import "zkParser.h"
#import "ZKDescribeLayoutResult.h"
#import "ZKDescribeTabSetResult.h"

static const int SAVE_BATCH_SIZE = 25;

@interface ZKSforceClient (Private)
- (ZKQueryResult *)queryImpl:(NSString *)value operation:(NSString *)op name:(NSString *)elemName;
- (NSArray *)sobjectsImpl:(NSArray *)objects name:(NSString *)elemName;
- (void)checkSession;
@property (retain, getter=currentUserInfo) ZKUserInfo *userInfo;
@end

@implementation ZKSforceClient

@synthesize preferedApiVersion, updateMru, clientId, cacheDescribes;

- (id)init {
	self = [super init];
	preferedApiVersion = 25;
	[self setLoginProtocolAndHost:@"https://www.salesforce.com"];
	updateMru = NO;
	cacheDescribes = NO;
	return self;
}

- (void)dealloc {
	[authEndpointUrl release];
	[clientId release];
	[userInfo release];
	[describes release];
    [authSource release];
	[super dealloc];
}

- (id)copyWithZone:(NSZone *)zone {
	ZKSforceClient *rhs = [[ZKSforceClient alloc] init];
	[rhs->authEndpointUrl release];
	rhs->authEndpointUrl = [authEndpointUrl copy];
	rhs->endpointUrl = [endpointUrl copy];
	rhs->clientId = [clientId copy];
	rhs->userInfo = [userInfo retain];
	rhs->preferedApiVersion = preferedApiVersion;
    rhs->authSource = [authSource retain];
	[rhs setCacheDescribes:cacheDescribes];
	[rhs setUpdateMru:updateMru];
	return rhs;
}

-(NSObject<ZKAuthenticationInfo> *)authenticationInfo {
    return authSource;
}

-(void)setAuthenticationInfo:(NSObject<ZKAuthenticationInfo> *)authenticationInfo {
    [authSource autorelease];
    authSource = [authenticationInfo retain];
    self.endpointUrl = [authSource instanceUrl];
    self.userInfo = nil;
}

- (void)flushCachedDescribes {
	[describes release];
	describes = nil;
	if (cacheDescribes)
		describes = [[NSMutableDictionary alloc] init];
}

- (void)setLoginProtocolAndHost:(NSString *)protocolAndHost {
	[self setLoginProtocolAndHost:protocolAndHost andVersion:preferedApiVersion];
}

- (void)setLoginProtocolAndHost:(NSString *)protocolAndHost andVersion:(int)version {
	[authEndpointUrl release];
	authEndpointUrl = [[NSString stringWithFormat:@"%@/services/Soap/u/%d.0", protocolAndHost, version] retain];
}

- (NSURL *)authEndpointUrl {
	return [NSURL URLWithString:authEndpointUrl];
}

- (ZKLoginResult *)login:(NSString *)un password:(NSString *)pwd {
    ZKSoapLogin *auth = [ZKSoapLogin soapLoginWithUsername:un password:pwd authHost:[NSURL URLWithString:authEndpointUrl] apiVersion:preferedApiVersion clientId:clientId];
	ZKLoginResult *lr = [auth login];
    [self setAuthenticationInfo:auth];
    self.userInfo = lr.userInfo;
    return lr;
}

- (void)loginFromOAuthCallbackUrl:(NSString *)callbackUrl oAuthConsumerKey:(NSString *)oauthClientId{
    ZKOAuthInfo *auth = [ZKOAuthInfo oauthInfoFromCallbackUrl:[NSURL URLWithString:callbackUrl] clientId:oauthClientId];
    [auth setApiVersion:preferedApiVersion];
    [self setAuthenticationInfo:auth];
}

- (void)loginWithRefreshToken:(NSString *)refreshToken authUrl:(NSURL *)authUrl oAuthConsumerKey:(NSString *)cid {
    ZKOAuthInfo *auth = [[[ZKOAuthInfo alloc] initWithRefreshToken:refreshToken authHost:authUrl sessionId:nil instanceUrl:nil clientId:cid] autorelease];
    [auth setApiVersion:preferedApiVersion];
    [self setAuthenticationInfo:auth];
    [self checkSession];
}

-(void)setUserInfo:(ZKUserInfo *)ui {
    [userInfo autorelease];
    userInfo = [ui retain];
}

- (BOOL)loggedIn {
	return [[authSource sessionId] length] > 0;
}

- (void)checkSession {
    if ([authSource refreshIfNeeded])
        self.endpointUrl = [authSource instanceUrl];
}

- (ZKUserInfo *)currentUserInfo {
	return userInfo;
}

- (NSURL *)serverUrl {
	return endpointUrl;
}

- (NSString *)sessionId {
	[self checkSession];
	return [authSource sessionId];
}

- (void)setPassword:(NSString *)newPassword forUserId:(NSString *)userId {
	if (!authSource) return;
	[self checkSession];
	
	ZKEnvelope * env = [[[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId] autorelease];
	[env startElement:@"setPassword"];
	[env addElement:@"userId" elemValue:userId];
	[env addElement:@"password" elemValue:newPassword];
	[env endElement:@"setPassword"];
	[env endElement:@"s:Body"];
	
	[self sendRequest:[env end]];
}

- (NSArray *)describeGlobal {
	if(!authSource) return NULL;
	[self checkSession];
	if (cacheDescribes) {
		NSArray *dg = [describes objectForKey:@"describe__global"];	// won't be an sfdc object ever called this.
		if (dg != nil) return dg;
	}
	
	ZKEnvelope * env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId];
	[env startElement:@"describeGlobal"];
	[env endElement:@"describeGlobal"];
	[env endElement:@"s:Body"];
	
    zkElement * rr = [self sendRequest:[env end]];
	NSArray *results = [[rr childElement:@"result"] childElements:@"sobjects"];
	NSMutableArray *types = [NSMutableArray arrayWithCapacity:[results count]];
    for (zkElement *res in results) {
		ZKDescribeGlobalSObject * d = [[ZKDescribeGlobalSObject alloc] initWithXmlElement:res];
		[types addObject:d];
		[d release];
	}
	[env release];
	if (cacheDescribes)
		[describes setObject:types forKey:@"describe__global"];
	return types;
}

- (ZKUserInfo *) getUserInfo {
    if( !authSource ) return NULL;
    
    [self checkSession];
    
    ZKEnvelope * env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId];
	[env startElement:@"getUserInfo"];
	[env endElement:@"getUserInfo"];
	[env endElement:@"s:Body"];
    
    zkElement *dr = [self sendRequest:[env end]];
	zkElement *descResult = [dr childElement:@"result"];
	ZKUserInfo *desc = [[[ZKUserInfo alloc] initWithXmlElement:descResult] autorelease];
    [env release];
    
    return desc;
}

- (ZKDescribeSObject *)describeSObject:(NSString *)sobjectName {
	if (!authSource) return NULL;
	if (cacheDescribes) {
		ZKDescribeSObject * desc = [describes objectForKey:[sobjectName lowercaseString]];
		if (desc != nil) return desc;
	}
	[self checkSession];
	
	ZKEnvelope * env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId];
	[env startElement:@"describeSObject"];
	[env addElement:@"SobjectType" elemValue:sobjectName];
	[env endElement:@"describeSObject"];
	[env endElement:@"s:Body"];
	
	zkElement *dr = [self sendRequest:[env end]];
	zkElement *descResult = [dr childElement:@"result"];
	ZKDescribeSObject *desc = [[[ZKDescribeSObject alloc] initWithXmlElement:descResult] autorelease];
	[env release];
	if (cacheDescribes) 
		[describes setObject:desc forKey:[sobjectName lowercaseString]];
	return desc;
}

- (ZKDescribeLayoutResult *)describeLayout:(NSString *)sobjectName recordTypeIds:(NSArray *)recordTypeIds {
	if (!authSource) return nil;
	[self checkSession];
	ZKEnvelope *env = [[[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId] autorelease];
	[env startElement:@"describeLayout"];
	[env addElement:@"sObjectType" elemValue:sobjectName];
	[env addElementArray:@"recordTypeIds" elemValue:recordTypeIds];
	[env endElement:@"describeLayout"];
	[env endElement:@"s:Body"];

	zkElement *dr = [self sendRequest:[env end]];
	zkElement *descResult = [dr childElement:@"result"];
	ZKDescribeLayoutResult *desc = [[[ZKDescribeLayoutResult alloc] initWithXmlElement:descResult] autorelease];
	return desc;
}

- (NSArray *)describeTabs {
    if (!authSource) return nil;
    [self checkSession];
    
    ZKEnvelope *env = [[[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId] autorelease];
    [env startElement:@"describeTabs"];
    [env endElement:@"describeTabs"];
    [env endElement:@"s:Body"];
    zkElement *dr = [self sendRequest:[env end]];

    NSMutableArray *results = [NSMutableArray array];
    for (zkElement *res in [dr childElements:@"result"]) {
        ZKDescribeTabSetResult *dt = [[[ZKDescribeTabSetResult alloc] initWithXmlElement:res] autorelease];

       [results addObject:dt];
    }

    return results;
}

- (NSArray *)search:(NSString *)sosl {
	if (!authSource) return NULL;
	[self checkSession];
	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId];
	[env startElement:@"search"];
	[env addElement:@"searchString" elemValue:sosl];
	[env endElement:@"search"];
	[env endElement:@"s:Body"];
	
	zkElement *sr = [self sendRequest:[env end]];
	zkElement *searchResult = [sr childElement:@"result"];
	NSArray *records = [searchResult childElements:@"searchRecords"];
	NSMutableArray *sobjects = [NSMutableArray arrayWithCapacity:[records count]];
	for (zkElement *soNode in records)
		[sobjects addObject:[ZKSObject fromXmlNode:[soNode childElement:@"record"]]];
	[env release];
	return sobjects;
}

- (NSString *)serverTimestamp {
	if (!authSource) return NULL;
	[self checkSession];
	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId];
	[env startElement:@"getServerTimestamp"];
	[env endElement:@"getServerTimestamp"];
	[env endElement:@"s:Body"];
	
	zkElement *res = [self sendRequest:[env end]];
	zkElement *timestamp = [res childElement:@"result"];
	[env release];
	return [timestamp stringValue];
}

- (ZKQueryResult *)query:(NSString *) soql {
	return [self queryImpl:soql operation:@"query" name:@"queryString"];
}

- (ZKQueryResult *)queryAll:(NSString *) soql {
	return [self queryImpl:soql operation:@"queryAll" name:@"queryString"];
}

- (ZKQueryResult *)queryMore:(NSString *)queryLocator {
	return [self queryImpl:queryLocator operation:@"queryMore" name:@"queryLocator"];
}

- (NSArray *)create:(NSArray *)objects {
	return [self sobjectsImpl:objects name:@"create"];
}

- (NSArray *)update:(NSArray *)objects {
	return [self sobjectsImpl:objects name:@"update"];
}

- (NSArray *)sobjectsImpl:(NSArray *)objects name:(NSString *)elemName {
	if(!authSource) return NULL;
	[self checkSession];
	
	// if more than we can do in one go, break it up.
	if ([objects count] > SAVE_BATCH_SIZE) {
		NSMutableArray *allResults = [NSMutableArray arrayWithCapacity:[objects count]];
		NSRange rng = {0, MIN(SAVE_BATCH_SIZE, [objects count])};
		while (rng.location < [objects count]) {
			[allResults addObjectsFromArray:[self sobjectsImpl:[objects subarrayWithRange:rng] name:elemName]];
			rng.location += rng.length;
			rng.length = MIN(SAVE_BATCH_SIZE, [objects count] - rng.location);
		}
		return allResults;
	}
	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionAndMruHeaders:[authSource sessionId] mru:updateMru clientId:clientId];
	[env startElement:elemName];
    for (ZKSObject *o in objects) 
		[env addElement:@"sobject" elemValue:o];
	[env endElement:elemName];
	[env endElement:@"s:Body"];

	zkElement *cr = [self sendRequest:[env end]];
	NSArray *resultsArr = [cr childElements:@"result"];
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[resultsArr count]];
	for (zkElement *cr in resultsArr) {
		ZKSaveResult * sr = [[ZKSaveResult alloc] initWithXmlElement:cr];
		[results addObject:sr];
		[sr release];
	}
	[env release];
	return results;
}

- (NSDictionary *)retrieve:(NSString *)fields sobject:(NSString *)sobjectType ids:(NSArray *)ids {
	if(!authSource) return NULL;
	[self checkSession];
	
	ZKEnvelope * env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId];
	[env startElement:@"retrieve"];
	[env addElement:@"fieldList" elemValue:fields];
	[env addElement:@"sObjectType" elemValue:sobjectType];
	[env addElementArray:@"ids" elemValue:ids];
	[env endElement:@"retrieve"];
	[env endElement:@"s:Body"];
	
	zkElement *rr = [self sendRequest:[env end]];
	NSMutableDictionary *sobjects = [NSMutableDictionary dictionary]; 
	NSArray *results = [rr childElements:@"result"];
	for (zkElement *res in results) {
		ZKSObject *o = [[ZKSObject alloc] initFromXmlNode:res];
        
        if( !o || ![o id] ) {
            [o release];
            continue;
        }
        
		[sobjects setObject:o forKey:[o id]];
		[o release];
	}
	[env release];
	return sobjects;
}

- (NSArray *)delete:(NSArray *)ids {
	if(!authSource) return NULL;
	[self checkSession];

	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionAndMruHeaders:[authSource sessionId] mru:updateMru clientId:clientId];
	[env startElement:@"delete"];
	[env addElement:@"ids" elemValue:ids];
	[env endElement:@"delete"];
	[env endElement:@"s:Body"];
	
	zkElement *cr = [self sendRequest:[env end]];
	NSArray *resArr = [cr childElements:@"result"];
	NSMutableArray *results = [NSMutableArray arrayWithCapacity:[resArr count]];
	for (zkElement *cr in resArr) {
		ZKSaveResult *sr = [[ZKSaveResult alloc] initWithXmlElement:cr];
		[results addObject:sr];
		[sr release];
	}
	[env release];
	return results;
}

- (ZKQueryResult *)queryImpl:(NSString *)value operation:(NSString *)operation name:(NSString *)elemName {
	if(!authSource) return NULL;
	[self checkSession];

	ZKEnvelope *env = [[ZKPartnerEnvelope alloc] initWithSessionHeader:[authSource sessionId] clientId:clientId];
	[env startElement:operation];
	[env addElement:elemName elemValue:value];
	[env endElement:operation];
	[env endElement:@"s:Body"];
	
	zkElement *qr = [self sendRequest:[env end]];
	ZKQueryResult *result = [[ZKQueryResult alloc] initFromXmlNode:[[qr childElements] objectAtIndex:0]];
	[env release];
	return [result autorelease];
}

@end
