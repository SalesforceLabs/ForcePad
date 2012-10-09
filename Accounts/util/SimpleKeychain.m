// http://stackoverflow.com/questions/5247912/saving-email-password-to-keychain-in-ios

#import "SimpleKeychain.h"
#import "SFVCrypto.h"

@implementation SimpleKeychain

+ (NSMutableDictionary *)getKeychainQuery:(NSString *)service {
    return [NSMutableDictionary dictionaryWithObjectsAndKeys:
            (id)kSecClassGenericPassword, (id)kSecClass,
            service, (id)kSecAttrService,
            service, (id)kSecAttrAccount,
            //(id)kSecAttrAccessibleWhenUnlockedThisDeviceOnly, (id)kSecAttrAccessible,
            (id)kSecAttrAccessibleAfterFirstUnlock, (id)kSecAttrAccessible,
            nil];
}

+ (void)save:(NSString *)service data:(id)data {
    if( !data ) return;
        
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service];
    SecItemDelete((CFDictionaryRef)keychainQuery);  
    
    NSData *bits = nil;
    
    if( [data isKindOfClass:[NSString class]] )
        @try {
            bits = [SFVCrypto crypt:[data dataUsingEncoding:NSUTF8StringEncoding]
                          operation:kCryptEncrypt];
        } @catch( NSException *e ) {}
    
    [keychainQuery setObject:[NSKeyedArchiver archivedDataWithRootObject:
                              ( bits ? bits : data )]
                      forKey:(id)kSecValueData];
    
    SecItemAdd((CFDictionaryRef)keychainQuery, NULL);
}

+ (id)load:(NSString *)service {
    id ret = nil;
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service];
    [keychainQuery setObject:(id)kCFBooleanTrue forKey:(id)kSecReturnData];
    [keychainQuery setObject:(id)kSecMatchLimitOne forKey:(id)kSecMatchLimit];
    CFDataRef keyData = NULL;
    if (SecItemCopyMatching((CFDictionaryRef)keychainQuery, (CFTypeRef *)&keyData) == noErr) {
        @try {
            ret = [NSKeyedUnarchiver unarchiveObjectWithData:(NSData *)keyData];
        }
        @catch (NSException *e) {
            NSLog(@"Unarchive of %@ failed: %@", service, e);
        }
        @finally {}
    }
    if (keyData) CFRelease(keyData);
    
    if( ret && [ret isKindOfClass:[NSData class]] ) {
        NSString *str = nil;
        
        @try {
            str = [[[NSString alloc] initWithData:[SFVCrypto crypt:ret
                                                         operation:kCryptDecrypt]
                                         encoding:NSUTF8StringEncoding] autorelease];
            
            return str;
        } @catch( NSException *e ) {}
        
        return nil;
    }
    
    return ret;
}

+ (void)delete:(NSString *)service {
    NSMutableDictionary *keychainQuery = [self getKeychainQuery:service];
    SecItemDelete((CFDictionaryRef)keychainQuery);
}

@end