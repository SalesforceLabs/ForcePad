/* 
 * Copyright (c) 2011, salesforce.com, inc.
 * Author: Steve Holly
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

// Warning, the following includes for the macAddress method must be in this order
#import <sys/socket.h>      // for MAC address
#import <sys/sysctl.h>      // for MAC address
#import <net/if.h>          // for MAC address
#import <net/if_dl.h>       // for MAC address

#import <Foundation/Foundation.h>
#import <CommonCrypto/CommonCryptor.h>
#import <CommonCrypto/CommonKeyDerivation.h>

static const CCAlgorithm    kCryptAlgorithm         = kCCAlgorithmAES128;
static const NSUInteger     kCryptKeySize           = kCCKeySizeAES256;
static const NSUInteger     kCryptBlockSize         = kCCBlockSizeAES128;
static const NSUInteger     kCryptIVSize            = kCCBlockSizeAES128;
static const NSUInteger     kCryptPBKDFSaltSize     = 8;
static const NSUInteger     kCryptPBKDFRounds       = 10000;

static NSString * const     kSFSalt                 = @"On a dark dessert highway, cool whip in my hair...";

static const NSUInteger kBase64EncodedDataMinimumLength = 4;

typedef NSUInteger CryptOperation;
enum {
    kCryptEncrypt = kCCEncrypt,
    kCryptDecrypt = kCCDecrypt
};

@interface SFVCrypto : NSObject

+ (NSData *) randomDataOfLength:(size_t)length;
+ (NSData *) crypt:(NSData *)dataIn operation:(CryptOperation)operation;
+ (NSData *) cryptKeyWithSalt:(NSData *)salt;
+ (NSData *) AESKeyForPassword:(NSString *)password salt:(NSData *)salt;
+ (NSString *) macAddress;

@end
