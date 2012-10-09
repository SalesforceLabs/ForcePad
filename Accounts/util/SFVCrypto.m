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

#import "SFVCrypto.h"

@implementation SFVCrypto

/**
 Encrypts/decrypts the supplied data based on the operation using the key and initialization vector.
 @param dataIn  data to encrypt
 @param key     key to use for encryption
 @param iv      initialization vector (`nil` will automatically produce an all zero IV)
 */
+ (NSData *) crypt:(NSData *)dataIn operation:(CryptOperation)operation {
    if (nil == dataIn) return nil;
    
    NSData *key = [self cryptKeyWithSalt:[kSFSalt dataUsingEncoding:NSUTF8StringEncoding]];
    
    if ([key length] == 0) {
        NSLog(@"Invalid key.");
        return nil;
    }
    
    size_t dataInLength = (size_t)[dataIn length];
    char * dataOut = NULL;
    size_t dataOutLength;
    size_t dataOutMoved = 0;
    CCCryptorStatus status;
    
    do {
        if (dataOutMoved) {
            dataOutLength = dataOutMoved;
        } else {
            // set output length to the input length rounded up to the nearest key length multiple
            dataOutLength = ((dataInLength + [key length] - 1) / [key length]) * [key length]; 
        }
        if (dataOut) free(dataOut);
        dataOut = malloc(dataOutLength);
        status = CCCrypt(operation, kCryptAlgorithm, kCCOptionPKCS7Padding,
                         [key bytes], [key length], 0, 
                         [dataIn bytes], [dataIn length],
                         dataOut, dataOutLength, &dataOutMoved);
    } while (kCCBufferTooSmall == status && dataOutLength < dataOutMoved);
    
    if (kCCSuccess == status) {
        return [NSData dataWithBytesNoCopy:dataOut length:dataOutMoved freeWhenDone:YES];
    } else {
        free(dataOut);
        return nil;
    }
}

/**
 @return An encryption key derived using the supplied salt and a concatenation of some other strings.
 */
+ (NSData *) cryptKeyWithSalt:(NSData *)salt {
    NSMutableString *s = [NSMutableString string];
    [s appendFormat:@"%@", @"IamIamIamSooooooperman."];
    [s appendFormat:@"%@", [self macAddress]];
    [s appendFormat:@"%@", NSStringFromClass([self class])];
    return [self AESKeyForPassword:s salt:salt];
}

/**
 Derives an encryption key based on a shared password and the supplied salt.
 @param password    The shared password form which to derive the key. This password must be produced using the same 
 encoding and normalization each time in order to derive the same key.
 @param salt        Random salt data to use to derive the key.
 @return AES encryption key for the supplied password and salt or `nil` if an error occurs.
 */
+ (NSData *)AESKeyForPassword:(NSString *)password salt:(NSData *)salt {
    NSMutableData *derivedKey = [NSMutableData dataWithLength:kCryptKeySize];
    int result = CCKeyDerivationPBKDF(kCCPBKDF2,                    // algorithm
                                      [password UTF8String],        // password as c string
                                      [password length],            // passwordLength
                                      [salt bytes],                 // salt
                                      [salt length],                // saltLen
                                      kCCPRFHmacAlgSHA1,            // pseudo random algorithm (prf)
                                      kCryptPBKDFRounds,            // rounds
                                      [derivedKey mutableBytes],    // derivedKey
                                      [derivedKey length]);         // derivedKeyLen
    if (result != kCCSuccess) {
        NSLog(@"Failed to create AES key for password (err = %d)", result); // don't log the password
        return nil;
    }
    return derivedKey;
}

/**
 @return The specified number of random bytes or `nil` if an error occurs.
 */
+ (NSData *) randomDataOfLength:(size_t)length {
    NSMutableData *data = [NSMutableData dataWithLength:length];
    int result = SecRandomCopyBytes(kSecRandomDefault, length, [data mutableBytes]);
    if (result != 0) {
        NSLog(@"Failed to generate random bytes (errno = %d)", errno);
        return nil;
    }
    return data;
}

/**
 Return the en0 network interface MAC address.
 
 Original from UIDevice-Hardware.m: iPhone Developer's Cookbook, 5.0 Edition, Erica Sadun <http://ericasadun.com>
 based on an implementation found on the FreeBSD hackers email list.
 */
+ (NSString *)macAddress {
    int                     mib[6];
    size_t                  len;
    char *                  buf;
    unsigned char *         ptr;
    struct if_msghdr *      ifm;
    struct sockaddr_dl *    sdl;
    
    mib[0] = CTL_NET;
    mib[1] = AF_ROUTE;
    mib[2] = 0;
    mib[3] = AF_LINK;
    mib[4] = NET_RT_IFLIST;
    
    if ((mib[5] = if_nametoindex("en0")) == 0) {
        NSLog(@"%@:macAddress: Error: Failed to convert interface name to index", NSStringFromClass(self));
        return nil;
    }
    
    if (sysctl(mib, 6, NULL, &len, NULL, 0) < 0) {
        NSLog(@"%@:macAddress: Error: Failed to retrieve required buffer size for the MAC address (%d)",
              NSStringFromClass(self), errno);
        return nil;
    }
    
    if ((buf = malloc(len)) == NULL) {
        NSLog(@"%@:macAddress: Error: Failed to allocate the buffer to store the MAC address",
              NSStringFromClass(self));
        return nil;
    }
    
    if (sysctl(mib, 6, buf, &len, NULL, 0) < 0) {
        NSLog(@"%@:macAddress: Error: Failed to copy the MAC address to the allocated buffer (%d)",
              NSStringFromClass(self), errno);
        return nil;
    }
    
    ifm = (struct if_msghdr *)buf;
    sdl = (struct sockaddr_dl *)(ifm + 1);
    ptr = (unsigned char *)LLADDR(sdl); // dig the MAC address out of the sock_addr
    NSString *outstring = [NSString stringWithFormat:@"%02X:%02X:%02X:%02X:%02X:%02X",
                           *ptr, *(ptr+1), *(ptr+2), *(ptr+3), *(ptr+4), *(ptr+5)];
    free(buf);
    
    return outstring;
}

@end
