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

#import "SFVUtil.h"
#import "SynthesizeSingleton.h"
#import "zkSforce.h"
#import "zkParser.h"
#import "PRPAlertView.h"
#include <ifaddrs.h>
#include <arpa/inet.h>
#import "PRPConnection.h"
#import "FieldPopoverButton.h"
#import "RootViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "SFVAsync.h"
#import "SFVAppCache.h"
#import <objc/runtime.h>
#import "NSData+Base64.h"
#import "UIImage+ImageUtils.h"

@implementation SFVUtil

SYNTHESIZE_SINGLETON_FOR_CLASS(SFVUtil);

#define LOADVIEWBOXSIZE 100
#define LOADINGVIEWTAG -11

// Maximum number of recent records to store
static int const kMaxRecentRecords = 250;

// Size of a userphoto for field layouts
static CGFloat const kUserPhotoSize = 26.0f;

// Character used to save completion blocks in an array on each image load request
static char imageLoadCompleteBlockArray;

BOOL chatterEnabled = NO;

@synthesize client, eventStore;

+ (NSString *) appFullName {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleNameKey];
}

+ (NSString *) appVersion {
    return [[NSBundle mainBundle] objectForInfoDictionaryKey:(NSString *)kCFBundleVersionKey];
}

#pragma mark - caching functions

- (void) emptyCaches:(BOOL)emptyAll {
    NSLog(@"*** WIPE CACHES *** All: %i", emptyAll);
    
    activityCount = 0;
    [geoLocationCache removeAllObjects];
    [userPhotoCache removeAllObjects];
    self.eventStore = nil;
    
    if( emptyAll ) {
        [layoutCache removeAllObjects];
    }
}

- (EKEventStore *)sharedEventStore {
    if( !self.eventStore )
        self.eventStore = [[[EKEventStore alloc] init] autorelease];
    
    return self.eventStore;
}

- (void) addCoordinatesToCache:(CLLocationCoordinate2D)coordinates accountId:(NSString *)accountId {
    if( !geoLocationCache )
        geoLocationCache = [[NSMutableDictionary dictionary] retain];
        
    [geoLocationCache setObject:[NSArray arrayWithObjects:[NSNumber numberWithDouble:coordinates.latitude], [NSNumber numberWithDouble:coordinates.longitude], nil]
                         forKey:accountId];        
}

- (NSArray *)coordinatesFromCache:(NSString *)accountId {
    if( !geoLocationCache )
        geoLocationCache = [[NSMutableDictionary dictionary] retain];
    
    // nil or an array
    return [geoLocationCache objectForKey:accountId];
}

- (void) addUserPhotoToCache:(UIImage *)photo forURL:(NSString *)photoURL {
    if( !userPhotoCache )
        userPhotoCache = [[NSMutableDictionary dictionary] retain];
    
    if( !photo )
        return;
        
    [userPhotoCache setObject:photo forKey:photoURL];
}

- (UIImage *) userPhotoFromCache:(NSString *)photoURL {
    if( !userPhotoCache )
        userPhotoCache = [[NSMutableDictionary dictionary] retain];
    
    id cached = [userPhotoCache objectForKey:photoURL];
    
    if( cached && [cached isKindOfClass:[UIImage class]] )
        return [(UIImage *)cached imageAtScale];
    
    return nil;
}

#pragma mark - rendering an account layout

+ (UIView *)createViewForSection:(NSString *)section maxWidth:(float)maxWidth {
    UIView *sectionView = [[UIView alloc] init];
    
    UILabel *sectionLabel = [[UILabel alloc] init];
    sectionLabel.backgroundColor = [UIColor clearColor];
    sectionLabel.textColor = [UIColor darkTextColor];
    sectionLabel.text = section;
    sectionLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:20];
    sectionLabel.numberOfLines = 0;
    CGSize s = [sectionLabel.text sizeWithFont:sectionLabel.font constrainedToSize:CGSizeMake( maxWidth - 35, 999 )];
    [sectionLabel setFrame:CGRectMake( 25, 0, s.width, s.height )];
    
    [sectionView addSubview:sectionLabel];
    [sectionLabel release];    
    
    UIImage *u = [UIImage imageNamed:@"sectionLine.png"];
    
    // Underline to the left of the text
    UIImageView *underlineLeft = [[UIImageView alloc] initWithImage:u];
    [underlineLeft setFrame:CGRectMake(0, s.height + 3, 25, 3)];
    [sectionView addSubview:underlineLeft];
    [underlineLeft release];
    
    // Blue text underline, sized to the section
    UIView *blueBG = [[UIView alloc] initWithFrame:CGRectMake( 25, s.height + 3, s.width, 3 )];
    blueBG.backgroundColor = AppLinkColor;
    [sectionView addSubview:blueBG];
    [blueBG release];
    
    // Underline to the right of the text
    UIImageView *underlineRight = [[UIImageView alloc] initWithImage:u];
    [underlineRight setFrame:CGRectMake( 25 + s.width, s.height + 3, 700, 3)];
    [sectionView addSubview:underlineRight];
    [underlineRight release];
    
    [sectionView setFrame:CGRectMake(0, 0, maxWidth, s.height + u.size.height + 3 )];
    
    return [sectionView autorelease];
}

- (UIView *)createViewForLayoutItem:(ZKDescribeLayoutItem *)item withRecord:(NSDictionary *)dict withTarget:(id)target {   
    // -1. The constructed view we'll be returning
    UIView *fieldView = [[[UIView alloc] init] autorelease];
    
    // 0. label and object name
    NSString *label = [SFVUtil stringByDecodingEntities:[item label]];
    NSString *sObjectName = [dict objectForKey:kObjectTypeKey];
    
    // 1. Label for this field
    UILabel *fieldLabel = [[[UILabel alloc] initWithFrame:CGRectZero] autorelease];
    fieldLabel.textColor = [UIColor lightGrayColor];
    fieldLabel.backgroundColor = [UIColor clearColor];
    fieldLabel.textAlignment = UITextAlignmentRight;
    fieldLabel.text = label;
    fieldLabel.numberOfLines = 0;
    fieldLabel.adjustsFontSizeToFitWidth = NO;
    fieldLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:16];
    
    CGSize s = [fieldLabel.text sizeWithFont:fieldLabel.font
                           constrainedToSize:CGSizeMake( FIELDLABELWIDTH, FIELDVALUEHEIGHT )
                               lineBreakMode:UILineBreakModeWordWrap];
    
    if( s.width < FIELDLABELWIDTH )
        s.width = FIELDLABELWIDTH;
    
    [fieldLabel setFrame:CGRectMake(0, 0, s.width, s.height)];
    [fieldView addSubview:fieldLabel];
    
    // 2. loop through all the components inside this layout item and build an output string
    
    enum FieldType ft = -1;
    UIImage *fieldImage = nil;
    BOOL fieldHasUserPhoto = NO;
    BOOL layoutItemHasValue = NO;
    BOOL showEmptyFields = [[NSUserDefaults standardUserDefaults] boolForKey:emptyFieldsKey];
    
    // ultimate text to output as the value for this component
    NSMutableString *itemText = [NSMutableString string];
    NSMutableDictionary *relatedRecord = nil;
        
    for( ZKDescribeLayoutComponent *comp in [item layoutComponents] ) {
        switch( [comp type] ) {
            case zkComponentTypeSeparator:
                // We use newlines instead of commas for lastmod/createdby
                if( ft == UserField )
                    [itemText appendString:@"\n"];
                else
                    [itemText appendString:[comp value]];
                break;
                
            case zkComponentTypeField: {
                NSString *field = [comp value];
                NSString *fieldType = [[SFVAppCache sharedSFVAppCache] field:field
                                                                    onObject:sObjectName
                                                              stringProperty:FieldType];
                NSString *relationshipName = [[SFVAppCache sharedSFVAppCache] field:field
                                                                           onObject:sObjectName
                                                                     stringProperty:FieldRelationshipName];
                
                if( ft == -1 ) {
                    if( [fieldType isEqualToString:@"email"] )
                        ft = EmailField;
                    else if( [fieldType isEqualToString:@"url"] )
                        ft = URLField;
                    else if( [fieldType isEqualToString:@"reference"] && ![SFVUtil isEmpty:[dict objectForKey:field]] ) {
                        NSDictionary *ref = [[SFVAppCache sharedSFVAppCache] describeGlobalsObject:[[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[dict objectForKey:field]]];
                        
                        if( !ref )
                            ft = TextField;
                        else if( [[ref objectForKey:@"name"] isEqualToString:@"User"] )
                            ft = UserField;
                        else if( [[SFVAppCache sharedSFVAppCache] doesGlobalObject:[ref objectForKey:@"name"] haveProperty:GlobalObjectIsLayoutable] )
                            ft = RelatedRecordField;
                        else
                            ft = TextField;
                    } else if( [field rangeOfString:@"Street"].location != NSNotFound || [field isEqualToString:@"Address"] )
                        ft = AddressField;
                    else if( [fieldType isEqualToString:@"phone"] || [field isEqualToString:@"Phone"] || [field isEqualToString:@"Fax"] )
                        ft = PhoneField;
                    else if( [fieldType isEqualToString:@"textarea"] && [[SFVAppCache sharedSFVAppCache] doesField:field
                                                                                                          onObject:sObjectName
                                                                                                      haveProperty:FieldIsHTML] ) {
                        ft = WebviewField;
                    } else
                        ft = TextField;
                }
                    
                // Get the properly formatted text contents of this field
                NSString *value = [self textValueForField:field withDictionary:dict];
                
                // Special handling for certain fields based on their field type.
                
                // First, trim formula fields
                if( [[SFVAppCache sharedSFVAppCache] doesField:field
                                                      onObject:sObjectName
                                                  haveProperty:FieldIsFormulaField] && 
                    ![SFVUtil isEmpty:value] )
                    value = [SFVUtil stripHTMLTags:value];
                else if( [fieldType isEqualToString:@"boolean"] ) {
                    // boolean fields have checkbox images
                    if( [value isEqualToString:@"Yes"] )
                        fieldImage = [UIImage imageNamed:@"check_yes.png"];
                    else
                        fieldImage = [UIImage imageNamed:@"check_no.png"];
                     
                    value = @"";
                } else if( ft == UserField && 
                         ![SFVUtil isEmpty:[dict objectForKey:relationshipName]] ) {
                    // related user.
                    relatedRecord = [NSMutableDictionary dictionaryWithDictionary:[dict objectForKey:relationshipName]];
                    [relatedRecord setObject:[dict objectForKey:field] forKey:@"Id"];
                 
                    if( [[SFVAppCache sharedSFVAppCache] isChatterEnabled] ) {
                        NSString *smallDestURL = [relatedRecord objectForKey:@"SmallPhotoUrl"];
                     
                        // Try our userphoto cache first
                        if( ![SFVUtil isEmpty:smallDestURL] ) {
                             fieldHasUserPhoto = YES;
                             
                             NSString *imageURL = [NSString stringWithFormat:@"%@?oauth_token=%@",
                                                     smallDestURL,
                                                     [[SFVUtil sharedSFVUtil] sessionId]];
                             
                             [[SFVUtil sharedSFVUtil] loadImageFromURL:imageURL
                                                                 cache:YES
                                                          maxDimension:kUserPhotoSize
                                                         completeBlock:^(UIImage *img, BOOL wasLoadedFromCache) {          
                                                             UIImageView *photoView = [[UIImageView alloc] initWithImage:img];
                                                             [photoView setFrame:CGRectMake( CGRectGetMaxX(fieldLabel.frame) + 10, 
                                                                                     0 + ( img.size.height > 22 ? -2 : 2 ), 
                                                                                     img.size.width, img.size.height)];
                                                             photoView.layer.cornerRadius = 5.0f;
                                                             photoView.layer.masksToBounds = YES;
                                                             
                                                             [fieldView addSubview:photoView];
                                                             [photoView release];
                             }];
                        }
                    }
                 } else if( ft == RelatedRecordField &&
                             ![SFVUtil isEmpty:[dict objectForKey:relationshipName]] ) {
                     relatedRecord = [NSMutableDictionary dictionaryWithDictionary:[dict objectForKey:relationshipName]];
                     [relatedRecord setObject:[dict objectForKey:field] forKey:@"Id"];
                 }
                
                if( !layoutItemHasValue )
                    layoutItemHasValue = ![SFVUtil isEmpty:value];
                
                // Append to our output value
                [itemText appendString:value];
                    
                break;
            }
            default:
                NSLog(@"UNRECOGNIZED COMPONENT %@", [comp typeName]);
                break;
        }
    }
    
    // 3. All field components are now parsed. Did we actually add anything?
    NSString *finalStr = nil;
    
    if( layoutItemHasValue )
        finalStr = [SFVUtil trimWhiteSpaceFromString:itemText];
    
    if( !showEmptyFields && !fieldImage && [SFVUtil isEmpty:finalStr] )
        return nil;
            
    // 4. Create the button to hold our output
    FieldPopoverButton *fieldValue = [FieldPopoverButton buttonWithText:finalStr fieldType:ft detailText:finalStr];
    fieldValue.detailViewController = target;
    [fieldValue setFieldRecord:relatedRecord];
    [fieldValue setFrame:CGRectMake( floorf( 10 + fieldLabel.frame.size.width ), 0, FIELDVALUEWIDTH, 35)];
    
    // 5. If there is an image associated with this field, display it
    
    if( fieldImage ) {
        // Add the imageview to our view
        UIImageView *photoView = [[UIImageView alloc] initWithImage:fieldImage];
        [photoView setFrame:CGRectMake(fieldValue.frame.origin.x, fieldValue.frame.origin.y - 1, fieldImage.size.width, fieldImage.size.height)];
        
        [fieldView addSubview:photoView];
        
        // Shift the text field over
        CGRect rect = fieldValue.frame;
        rect.origin.x += floorf( photoView.frame.size.width + 5 );
        rect.size.width -= photoView.frame.size.width + 5;
        [fieldValue setFrame:rect];
        [photoView release];
    } else if( fieldHasUserPhoto ) {
        CGRect rect = fieldValue.frame;
        rect.origin.x += floorf( kUserPhotoSize + 5 );
        rect.size.width -= kUserPhotoSize + 5;
        [fieldValue setFrame:rect];
    }
    
    // Resize the value to fit its text
    CGRect frame = [fieldValue frame];
    CGSize size;
    
    if( ![finalStr isEqualToString:@""] )
        size = [fieldValue.titleLabel.text sizeWithFont:fieldValue.titleLabel.font
                                      constrainedToSize:CGSizeMake(FIELDVALUEWIDTH, FIELDVALUEHEIGHT)
                                          lineBreakMode:UILineBreakModeWordWrap];
    else {
        size = CGSizeMake( 10, fieldLabel.frame.size.height );
        fieldValue.hidden = YES;
    }
    
    frame.size = size;
    [fieldValue setFrame:frame];
    
    // Final sizing and return    
    [fieldView addSubview:fieldValue];
    
    frame = fieldView.frame;
    
    frame.size = CGSizeMake( floorf( fieldLabel.frame.size.width + fieldValue.frame.size.width ), 
                             floorf( MAX( fieldLabel.frame.size.height, fieldValue.frame.size.height ) ) );
    
    [fieldView setFrame:frame];
    
    return fieldView;
}

- (UIView *) layoutViewForsObject:(NSDictionary *)sObject withTarget:(id)target singleColumn:(BOOL)singleColumn {
    int curY = 5, fieldCount = 0, sectionCount = 0;
    
    UIView *view = [[[UIView alloc] initWithFrame:CGRectZero] autorelease];
    
    view.autoresizingMask = UIViewAutoresizingNone;
    view.backgroundColor = [UIColor clearColor];
    
    // Get the  layout for this object.
    ZKDescribeLayout *layout = [self layoutForRecord:sObject];
    
    if( !layout )
        return view;
    
    // 1. Loop through all sections in this page layout
    for( ZKDescribeLayoutSection *section in [layout detailLayoutSections] ) {
        if( [section useHeading] ) {
            UIView *sectionHeader = [SFVUtil createViewForSection:[section heading] maxWidth:( singleColumn ? 400 : 800 )];
            sectionHeader.tag = sectionCount;
            
            [sectionHeader setFrame:CGRectMake(0, curY, sectionHeader.frame.size.width, sectionHeader.frame.size.height)];
            
            curY += sectionHeader.frame.size.height + SECTIONSPACING;
            
            [view addSubview:sectionHeader];   
        }
        
        int sectionFields = 0;
        
        // 2. Loop through all rows within this section
        for( ZKDescribeLayoutRow *dlr in [section layoutRows]) {
            float rowHeight = 0, curX = 5;
            
            // 3. Each individual item on this row
            for ( ZKDescribeLayoutItem *item in [dlr layoutItems] ) {                
                if( [item placeholder] || [[item layoutComponents] count] == 0 )
                    continue;  
                
                if( ![item label] )
                    continue;
                                
                UIView *itemView = [self createViewForLayoutItem:item
                                                      withRecord:sObject
                                                      withTarget:target];
                
                if( !itemView )
                    continue;
                
                // Position this item within our scrollview, alternating left and right sides
                rowHeight = MAX( rowHeight, itemView.frame.size.height );
                sectionFields++;
                itemView.tag = fieldCount;
                
                [itemView setFrame:CGRectMake( curX, curY, CGRectGetWidth(itemView.frame), CGRectGetHeight(itemView.frame))];
                
                if( !singleColumn )
                    curX = 345;
                else
                    curY += CGRectGetHeight(itemView.frame) + FIELDSPACING;
                
                [view addSubview:itemView];                
                
                fieldCount++;
            }
            
            if( !singleColumn )
                curY += rowHeight + FIELDSPACING;
        }
        
        // This is a little janky; we remove the section header view retroactively if there were no fields in it
        if( [section useHeading] && sectionFields == 0 ) {
            UIView *sectionView = [[view subviews] lastObject];
            curY -= sectionView.frame.size.height + SECTIONSPACING;
            [sectionView removeFromSuperview];
            
            continue;
        }
        
        sectionCount++;
        
        curY += SECTIONSPACING;
    }
    
    if( fieldCount == 0 ) {        
        /*[PRPAlertView showWithTitle:NSLocalizedString(@"Alert", @"Alert")
                            message:NSLocalizedString(@"Failed to load this account.", @"Account query failed")
                        cancelTitle:NSLocalizedString(@"Cancel", @"Cancel")
                        cancelBlock:nil
                         otherTitle:NSLocalizedString(@"Retry", @"Retry")
                         otherBlock:^(void) {
                             if( [target respondsToSelector:@selector(loadAccount)] )
                                 [target performSelector:@selector(loadAccount)];
                         }];*/
        return nil;
    }
    
    [view setFrame:CGRectMake(0, 0, 0, curY)];
    
    return view;
}

#pragma mark - sObject functions

+ (NSString *) cityStateForsObject:(NSDictionary *)sObject {
    NSString *ret = @"";
    
    if( ![self isEmpty:[sObject objectForKey:@"City"]] ) {
        ret = [sObject objectForKey:@"City"];
        
        if( ![self isEmpty:[sObject objectForKey:@"State"]] )
            ret = [ret stringByAppendingFormat:@", %@", [sObject objectForKey:@"State"]];
    } else if( ![self isEmpty:[sObject objectForKey:@"BillingCity"]] ) {
        ret = [sObject objectForKey:@"BillingCity"];
        
        if( ![self isEmpty:[sObject objectForKey:@"BillingState"]] )
            ret = [ret stringByAppendingFormat:@", %@", [sObject objectForKey:@"BillingState"]];
    } else if( ![self isEmpty:[sObject objectForKey:@"ShippingCity"]] ) {
        ret = [sObject objectForKey:@"ShippingCity"];
        
        if( ![self isEmpty:[sObject objectForKey:@"ShippingState"]] )
            ret = [ret stringByAppendingFormat:@", %@", [sObject objectForKey:@"ShippingState"]];
    }
        
    return ret;
}

+ (NSString *) addressForsObject:(NSDictionary *)sObject useBillingAddress:(BOOL)useBillingAddress {
    NSString *addressStr = @"";
    NSString *fieldPrefix = @"";
    
    if( [[sObject allKeys] containsObject:@"Street"] )
        fieldPrefix = @"";
    else if( useBillingAddress )
        fieldPrefix = @"Billing";
    else if( [sObject objectForKey:@"ShippingStreet"] )
        fieldPrefix = @"Shipping";
    else
        fieldPrefix = @"Mailing";
    
    for( NSString *field in [NSArray arrayWithObjects:@"Street", @"City", @"State", @"PostalCode", @"Country", nil] ) {        
        if( ![addressStr isEqualToString:@""] && ( [field isEqualToString:@"City"] || [field isEqualToString:@"Country"] ) )
            addressStr = [addressStr stringByAppendingString:@"\n"];
        else if( ![addressStr isEqualToString:@""] && [field isEqualToString:@"State"] )
            addressStr = [addressStr stringByAppendingString:@", "];
        else if( ![addressStr isEqualToString:@""] && [field isEqualToString:@"PostalCode"] )
            addressStr = [addressStr stringByAppendingString:@" "];
        
        NSString *fname = [fieldPrefix stringByAppendingString:field];
        
        if( ![[self class] isEmpty:[sObject objectForKey:fname]] && ![[sObject objectForKey:fname] isEqualToString:@"null"] )
            addressStr = [addressStr stringByAppendingString:[sObject objectForKey:fname]];
    }
         
    return addressStr;
}

+ (NSString *)wildAssedGuessAtStringifyingObject:(id)result {    
    if( !result || [result isKindOfClass:[NSNull class]] )
        return @"";
    else if( [result isKindOfClass:[NSDictionary class]] )
        return [[SFVAppCache sharedSFVAppCache] nameForSObject:result];
    else if( [result isKindOfClass:[NSString class]] )
        return (NSString *)result;
    else if( [result respondsToSelector:@selector(stringValue)] )
        return [result stringValue];
    else if( [result respondsToSelector:@selector(boolValue)] )
        return ( [result boolValue] ? NSLocalizedString(@"Yes", @"Yes") : NSLocalizedString(@"No", @"No") );
    
    return (NSString *)result;
}

- (NSString *)textValueForField:(NSString *)fieldName withDictionary:(NSDictionary *)sObject {
    NSString *sObjectName = nil;
    
    if( !fieldName )
        return @"";
    
    if( ![SFVUtil isEmpty:[sObject valueForKeyPath:@"attributes.type"]] )
        sObjectName = [sObject valueForKeyPath:@"attributes.type"];
    else if( ![SFVUtil isEmpty:[sObject objectForKey:kObjectTypeKey]] )
        sObjectName = [sObject objectForKey:kObjectTypeKey];
    else
        sObjectName = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[sObject objectForKey:@"Id"]];
    
    // JANKY HACK ALERT
    if( [sObjectName isEqualToString:@"ActivityHistory"] || [sObjectName isEqualToString:@"OpenActivity"] ) {
        if( [[sObject objectForKey:@"IsTask"] boolValue] )
            sObjectName = @"Task";
        else
            sObjectName = @"Event";
    }
    
    //NSLog(@"value for %@ on a %@", fieldName, sObjectName);
        
    // if this is a field on a related object, parse it out
    if( [fieldName rangeOfString:@"."].location != NSNotFound ) {
        NSArray *bits = [fieldName componentsSeparatedByString:@"."];
        id related = [sObject objectForKey:[bits objectAtIndex:0]];
        
        //NSLog(@"IS RELATED via %@", related);
        
        if( !related || [related isMemberOfClass:[NSNull class]] )
            return @"";
        
        NSString *field = nil;
        
        if( [bits count] > 2 ) {
            field = [bits objectAtIndex:2];
            related = [related objectForKey:[bits objectAtIndex:1]];
        } else
            field = [bits objectAtIndex:1]; 
        
        if( [related isKindOfClass:[ZKSObject class]] )
            related = [(ZKSObject *)related fields];
        else if( [related isKindOfClass:[NSString class]] )
            return related;
        
        return [self textValueForField:field 
                        withDictionary:(NSDictionary *)related];
    }
    
    NSString *fieldType = [[SFVAppCache sharedSFVAppCache] field:fieldName
                                                        onObject:sObjectName
                                                  stringProperty:FieldType];
    
    if( !fieldType ) { // some knucklehead forgot to describe this object
        id result = [sObject objectForKey:fieldName];
        
        //NSLog(@"** UNDESCRIBED FIELD %@ on %@ : %@", fieldName, sObjectName, result );
        
        if( [fieldName isEqualToString:@"IsTask"] ) {
            if( [result boolValue] )
                return NSLocalizedString(@"Yes",@"Yes");
            
            return NSLocalizedString(@"No", @"No");
        }
        
        return [[self class] wildAssedGuessAtStringifyingObject:result];
    }
            
    // if it's a related object's name (as opposed to above, a field on related object)
    if( [fieldType isEqualToString:@"reference"] ) {   
        NSString *relationshipName = [[SFVAppCache sharedSFVAppCache] field:fieldName
                                                                   onObject:sObjectName
                                                             stringProperty:FieldRelationshipName];
        
        id related = [sObject objectForKey:relationshipName];
        
        //NSLog(@"IS A REFERENCE to: %@", related);
        
        if( [SFVUtil isEmpty:related] )
            return @"";
        else if( [related isKindOfClass:[ZKSObject class]] )
            return [[SFVAppCache sharedSFVAppCache] nameForSObject:[related fields]];
        else if( [related isKindOfClass:[NSDictionary class]] )
            return [[SFVAppCache sharedSFVAppCache] nameForSObject:related];
        
        return @"";
    }
    
    // We should now have just a field from a regular dictionary. Extract the field value and format properly
    NSString *value = [[self class] wildAssedGuessAtStringifyingObject:[sObject objectForKey:fieldName]];
    NSNumberFormatter *nformatter = [[NSNumberFormatter alloc] init];  
    NSDateFormatter *dformatter = [[NSDateFormatter alloc] init];
    NSNumber *num;
    
    [dformatter setLocale:[NSLocale currentLocale]];
    [nformatter setLocale:[NSLocale currentLocale]];
        
    if( [SFVUtil isEmpty:value] || [value isEqualToString:@"null"] )
        value = @"";
    else if( [fieldType isEqualToString:@"currency"] ) {
        [nformatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        
        if( ![SFVUtil isEmpty:[sObject objectForKey:@"CurrencyIsoCode"]] )
              [nformatter setCurrencyCode:[sObject objectForKey:@"CurrencyIsoCode"]];
              
        num = [NSNumber numberWithDouble:[value doubleValue]];
        value = [nformatter stringFromNumber:num];
    } else if( [fieldType isEqualToString:@"boolean"] ) {
        if( [value boolValue] )
            value = @"Yes";
        else
            value = @"No";
    } else if( [fieldType isEqualToString:@"date"] || [fieldType isEqualToString:@"datetime"] ) {
        [dformatter setDateStyle:NSDateFormatterShortStyle];
                
        if( [fieldType isEqualToString:@"date"] 
            || ( [sObjectName isEqualToString:@"Event"] 
                 && [[sObject objectForKey:@"IsAllDayEvent"] boolValue]
                 && [[NSArray arrayWithObjects:@"StartDateTime", @"EndDateTime", nil] containsObject:fieldName] ) )
            [dformatter setTimeStyle:NSDateFormatterNoStyle];
        else
            [dformatter setTimeStyle:NSDateFormatterShortStyle];
        
        value = [dformatter stringFromDate:[[self class] dateFromSOQLDatetime:value]];
    } else if( [fieldType isEqualToString:@"percent"] ) {
        [nformatter setNumberStyle:NSNumberFormatterPercentStyle];
        
        num = [NSNumber numberWithDouble:( [value doubleValue] / 100 )];
        value = [nformatter stringFromNumber:num];
    } else if( [fieldType isEqualToString:@"double"] ) {
        // 'Precision' is the total number of decimal digits (left and right of the decimal)
        // 'Scale' is the number of digits to the right of the decimal
        // No direct means of getting the number of digits to the left of the decimal, so we just subtract them
        [nformatter setNumberStyle:NSNumberFormatterDecimalStyle];
        
        NSInteger precision = [[SFVAppCache sharedSFVAppCache] field:fieldName
                                                            onObject:sObjectName
                                                      numberProperty:FieldPrecision];
        NSInteger scale = [[SFVAppCache sharedSFVAppCache] field:fieldName
                                                        onObject:sObjectName
                                                  numberProperty:FieldScale];
        
        [nformatter setMinimumFractionDigits:scale];
        [nformatter setMaximumFractionDigits:scale];
        [nformatter setMaximumIntegerDigits:( precision - scale )];
        
        num = [NSNumber numberWithDouble:[value doubleValue]];
        value = [nformatter stringFromNumber:num];
    } else if( [fieldType isEqualToString:@"url"] ) {
        // make sure this URL has a protocol prefix
        NSString *urlLC = [value lowercaseString];
        
        if( ![urlLC hasPrefix:@"http://"] && ![urlLC hasPrefix:@"https://"] )
            value = [NSString stringWithFormat:@"http://%@", value];
    } else if( [fieldType isEqualToString:@"textarea"] )
        value = [[self class] trimWhiteSpaceFromString:value];

    [nformatter release];
    [dformatter release];
    
    return value;
}

- (NSArray *) filterGlobalObjectArray:(NSArray *)objectArray {
    if( !objectArray )
        return nil;
    
    NSMutableArray *ret = [NSMutableArray array];
    
    for( NSString *sObject in objectArray ) {        
        // the knowledge objects have various query restrictions and will eventually
        // need special support if we're to include them
        if( [sObject rangeOfString:@"__ka" options:NSCaseInsensitiveSearch].location != NSNotFound )
            continue;
        
        if( [sObject isEqualToString:@"KnowledgeArticleVersion"] )
            continue;
                
        if( ![[SFVAppCache sharedSFVAppCache] doesGlobalObject:sObject haveProperty:GlobalObjectIsLayoutable] )
            continue;
        
        [ret addObject:sObject];
    }
    
    return [[NSSet setWithArray:ret] allObjects];
}

+ (NSArray *) mergeObjectArray:(NSArray *)objectArray withArray:(NSArray *)array {
    if( !objectArray )
        return nil;
    
    if( !array )
        return objectArray;
    
    NSMutableArray *ret = [NSMutableArray arrayWithArray:objectArray];
    
    for( NSString *ob in array )
        if( ![ret containsObject:ob] )
            [ret addObject:ob];
    
    return ret;
}

- (NSArray *) sortGlobalObjectArray:(NSArray *)objectArray {
    if( !objectArray )
        return nil;
    
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[objectArray count]];
    NSMutableDictionary *nameDict = [NSMutableDictionary dictionary];
    
    for( NSString *ob in objectArray ) {
        NSString *label = [[SFVAppCache sharedSFVAppCache] labelForSObject:ob usePlural:YES];
        
        if( [nameDict objectForKey:label] )
            [nameDict setObject:ob forKey:[label stringByAppendingString:ob]];
        else
            [nameDict setObject:ob forKey:label];
    }
        
    for( NSString *label in [SFVUtil sortArray:[nameDict allKeys]] )
        [ret addObject:[nameDict objectForKey:label]];
    
    return ret;
}

- (void) describeLayoutForsObject:(NSString *)sObject completeBlock:(void (^)(ZKDescribeLayoutResult * layoutDescribe))completeBlock {
    if( !layoutCache )
        layoutCache = [[NSMutableDictionary alloc] init];
    
    if( !sObject )
        return;
    
    if( [layoutCache objectForKey:sObject] ) {
        completeBlock([layoutCache objectForKey:sObject]);
        return;
    }
        
    NSLog(@"DESCRIBE LAYOUT: %@", sObject);
    
    [SFVAsync performSFVAsyncRequest:(id)^{
                                return [[[SFVUtil sharedSFVUtil] client] describeLayout:sObject recordTypeIds:nil];
                            }
                           failBlock:^(NSException *e) {
                               
                           }
                       completeBlock:^(id result) {
                           if( result ) {
                               [layoutCache setObject:result forKey:sObject];
                               completeBlock( result );
                           }
                       }];
}

- (NSString *) sObjectFromLayoutId:(NSString *)layoutId {
    for( NSString *sObject in [layoutCache allKeys] )
        for( ZKDescribeLayout *layout in [[layoutCache objectForKey:sObject] layouts] )
            if( [[layout Id] isEqualToString:layoutId] )
                return sObject;

    return nil;
}

- (NSString *) sObjectFromRecordTypeId:(NSString *)recordTypeId {
    for( NSString *sObject in [layoutCache allKeys] )
        for( ZKRecordTypeMapping *mapping in [[layoutCache objectForKey:sObject] recordTypeMappings] )
            if( [[mapping recordTypeId] isEqualToString:recordTypeId] )
                return sObject;
    
    return nil;
}

- (NSString *)layoutIDForRecord:(NSDictionary *)record {
    if( !layoutCache || !record )
        return nil;
    
    NSString *type = [record objectForKey:kObjectTypeKey];
    
    if( !type )
        type = [[SFVAppCache sharedSFVAppCache] sObjectFromRecordId:[record objectForKey:@"Id"]];
    
    if( !type || [SFVUtil isEmpty:[layoutCache objectForKey:type]] )
        return nil;
    
    ZKDescribeLayoutResult *result = [layoutCache objectForKey:type];
    NSString *layoutId = nil;
    
    if( result ) {
        // First attempt to pick the proper layout for this record type, if there is a record type
        if( ![SFVUtil isEmpty:[record objectForKey:kRecordTypeIdField]] ) {
            for( ZKRecordTypeMapping *rt in [result recordTypeMappings] )
                if( [[rt recordTypeId] isEqualToString:[record objectForKey:kRecordTypeIdField]] )
                    layoutId = [rt layoutId];
        }
        
        // Next attempt to pick the default layout for this object
        if( !layoutId )
            for( ZKRecordTypeMapping *rt in [result recordTypeMappings] )
                if( [rt defaultRecordTypeMapping] ) {
                    layoutId = [rt layoutId];
                    break;
                }
        
        // If all else fails, just choose the first available layout
        if( !layoutId && [[result layouts] count] > 0 )
            layoutId = [[[result layouts] objectAtIndex:0] Id];
    }
    
    return ( layoutId ? [[layoutId copy] autorelease] : nil );
}

- (NSDictionary *)availableRecordTypesForObject:(NSString *)object {
    if( !layoutCache || !object )
        return nil;

    if( [SFVUtil isEmpty:[layoutCache objectForKey:object]] )
        return nil;
    
    ZKDescribeLayoutResult *result = [layoutCache objectForKey:object];
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    for( ZKRecordTypeMapping *mapping in [result recordTypeMappings] )
        if( [mapping available] )
            [ret setObject:[mapping name]
                    forKey:[mapping recordTypeId]];
    
    return ret;
}

- (NSDictionary *)defaultRecordTypeForObject:(NSString *)object {
    if( !layoutCache || !object )
        return nil;
        
    if( [SFVUtil isEmpty:[layoutCache objectForKey:object]] )
        return nil;
    
    ZKDescribeLayoutResult *result = [layoutCache objectForKey:object];
    
    for( ZKRecordTypeMapping *mapping in [result recordTypeMappings] )
        if( [mapping defaultRecordTypeMapping] )
            return [NSDictionary dictionaryWithObject:[mapping name]
                                               forKey:[mapping recordTypeId]];
    
    return nil;
}

- (NSDictionary *)picklistValuesForObject:(NSString *)object recordTypeId:(NSString *)recordTypeId {
    if( !layoutCache || !object )
        return nil;
        
    if( [SFVUtil isEmpty:[layoutCache objectForKey:object]] )
        return nil;
    
    ZKDescribeLayoutResult *result = [layoutCache objectForKey:object];
    NSArray *arr = nil;
    
    // First try to find this exact recordtypeId
    for( ZKRecordTypeMapping *mapping in [result recordTypeMappings] )
        if( recordTypeId && [[mapping recordTypeId] isEqualToString:recordTypeId] ) {
            arr = [mapping picklistsForRecordType];
            break;
        }
    
    // Fallback on the default mapping
    if( !arr )
        for( ZKRecordTypeMapping *mapping in [result recordTypeMappings] )
            if( [mapping defaultRecordTypeMapping] ) {
                arr = [mapping picklistsForRecordType];
                break;
            }
    
    if( !arr ) // merde.
        return nil;
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    for( ZKPicklistForRecordType *picklist in arr )
        [ret setObject:[picklist picklistValues]
                forKey:[picklist picklistName]];
    
    return ret;
}

+ (BOOL)testBitAtIndex:(int)index byteData:(Byte *)byteData {
    if( !byteData )
        return NO;
    
    return ( byteData[index >> 3] & (0x80 >> index % 8)) != 0;
}

- (NSArray *)picklistValuesForField:(NSString *)field onObject:(NSDictionary *)object filterByRecordType:(BOOL)filterByRecordType {
    NSString *sObjectType = [object objectForKey:kObjectTypeKey];    
        
    // All picklist options for this field, across all record types
    NSArray *picklistOptions = [[SFVAppCache sharedSFVAppCache] field:field
                                                             onObject:sObjectType
                                                        arrayProperty:FieldPicklistValues];
        
    // All picklist options for this field, for this particular record type
    NSArray *recordTypePicklistOptions = [[self picklistValuesForObject:sObjectType
                                                           recordTypeId:[object objectForKey:kRecordTypeIdField]] 
                                          objectForKey:field];
            
    NSMutableArray *rtOptions = [NSMutableArray array];
    
    for( ZKPicklistEntry *entry in recordTypePicklistOptions )
        [rtOptions addObject:[entry value]];
        
    // The controlling field for this picklist
    NSString *controllingField = nil;
    NSInteger indexOfSelectedControllingValue = -1;
    
    if( [[SFVAppCache sharedSFVAppCache] doesField:field
                                          onObject:sObjectType
                                      haveProperty:FieldIsDependentPicklist] ) {
        controllingField = [[SFVAppCache sharedSFVAppCache] field:field
                                                         onObject:sObjectType
                                                   stringProperty:FieldControllingFieldName];
        
        // If the controlling field is a boolean, the index is 0 or 1
        if( [[[SFVAppCache sharedSFVAppCache] field:controllingField
                                           onObject:sObjectType
                                     stringProperty:FieldType] isEqualToString:@"boolean"] )
            indexOfSelectedControllingValue = [[object objectForKey:controllingField] boolValue];
        else {
            NSArray *controllingOptions = [self picklistValuesForField:controllingField
                                                              onObject:object 
                                                    filterByRecordType:NO];
                        
            for( int i = 0; i < [controllingOptions count]; i++ ) {
                if( [[[controllingOptions objectAtIndex:i] objectForKey:@"value"] isEqualToString:[object objectForKey:controllingField]] ) {
                    indexOfSelectedControllingValue = i;
                    break;
                }
            }
        }
    }
            
    NSMutableArray *ret = [NSMutableArray array];
    
    for( int i = 0; i < [picklistOptions count]; i++ ) {
        NSDictionary *entry = [picklistOptions objectAtIndex:i];
        
        // skip if not an active value
        if( ![[entry objectForKey:@"active"] boolValue] )
            continue;
        
        // skip if not valid for this RT
        if( [rtOptions count] > 0
            && filterByRecordType
            && ![rtOptions containsObject:[entry objectForKey:@"value"]] )
            continue;
        
        if( controllingField ) {
            if( [SFVUtil isEmpty:[entry objectForKey:@"validFor"]] )       
                continue;
            
            NSData *data = [NSData dataFromBase64String:[entry objectForKey:@"validFor"]];
            NSUInteger len = [data length];
            Byte *byteData = (Byte*)malloc(len);
            memcpy(byteData, [data bytes], len);

            if( ![[self class] testBitAtIndex:indexOfSelectedControllingValue 
                                     byteData:byteData] ) {
                free(byteData);
                continue;     
            }
            
            free(byteData);
        }
        
        // valid.
        [ret addObject:[NSDictionary dictionaryWithObjectsAndKeys:
                        [entry objectForKey:@"value"], @"value",
                        [entry objectForKey:@"label"], @"label",
                        nil]];
    }
    
    return ret;
}

- (BOOL)isValue:(NSString *)value inPicklist:(NSString *)picklist onObject:(NSString *)object {
    if( !value )
        return NO;
    
    NSArray *values = [self picklistValuesForField:picklist onObject:[NSDictionary dictionaryWithObject:object forKey:kObjectTypeKey] filterByRecordType:YES];
    
    for( NSDictionary *dict in values )
        if( [[dict objectForKey:@"label"] isEqualToString:value]
            || [[dict objectForKey:@"value"] isEqualToString:value] )
            return YES;
    
    return NO;
}
 
- (ZKDescribeLayout *) layoutForRecord:(NSDictionary *)record {
    return [self layoutWithLayoutId:[self layoutIDForRecord:record]];
}

- (ZKDescribeLayout *) layoutWithLayoutId:(NSString *)layoutId {
    if( !layoutCache || [layoutCache count] == 0 || !layoutId )
        return nil;
    
    for( ZKDescribeLayoutResult *result in [layoutCache allValues] )
        for( ZKDescribeLayout *layout in [result layouts] )
            if( [[layout Id] isEqualToString:layoutId] )
                return layout;
    
    return nil;
}

// Returns a list of field names that appear in a given record layout, for use in constructing a query
- (NSArray *)fieldListForLayoutId:(NSString *)layoutId {
    NSMutableArray *ret = [NSMutableArray arrayWithObject:@"Id"];
    
    ZKDescribeLayout *layout = [self layoutWithLayoutId:layoutId];
    NSString *sObject = [self sObjectFromLayoutId:layoutId];
    
    if( !layout ) 
        return ret;
        
    // 1. Loop through all sections in this page layout
    for( ZKDescribeLayoutSection *section in [layout detailLayoutSections] ) {
        
        // 2. Loop through all rows within this section
        for( ZKDescribeLayoutRow *dlr in [section layoutRows]) {
            
            // 3. Each individual item on this row
            for ( ZKDescribeLayoutItem *item in [dlr layoutItems] ) {
                
                // If this item is blank or a placeholder, we ignore it
                if( [item placeholder] || [[item layoutComponents] count] == 0 )
                    continue;
                
                for( ZKDescribeLayoutComponent *dlc in [item layoutComponents] ) {                    
                    if( ![[dlc typeName] isEqualToString:@"Field"] )
                        continue;
                    
                    NSString *fname = [dlc value];
                    NSString *fieldType = [[SFVAppCache sharedSFVAppCache] field:fname
                                                                        onObject:sObject
                                                                  stringProperty:FieldType];
                    
                    if( !fieldType )
                        continue;
                    
                    if( [fieldType isEqualToString:@"reference"] ) {        
                        NSString *relationshipName = [[SFVAppCache sharedSFVAppCache] field:fname
                                                                                   onObject:sObject 
                                                                             stringProperty:FieldRelationshipName];
                        NSArray *referenceTo = [[SFVAppCache sharedSFVAppCache] field:fname
                                                                             onObject:sObject
                                                                        arrayProperty:FieldReferenceTo];
                        
                        // Special handling for the 'What' and 'Who' fields on Task, which can refer to just about anything                        
                        if( [relationshipName isEqualToString:@"What"] )
                            [ret addObject:@"What.Name"];
                        else if( [relationshipName isEqualToString:@"Who"] )
                            [ret addObject:@"Who.Name"];
                        else if( [referenceTo count] == 1 && [referenceTo containsObject:@"User"] ) {
                            // Special handling for Task/Event, as they use the Name field for owner (sigh)
                            if( ( [sObject isEqualToString:@"Task"] || [sObject isEqualToString:@"Event"] ) && [relationshipName isEqualToString:@"Owner"] )
                                [ret addObject:[NSString stringWithFormat:@"%@.%@", relationshipName, @"Name"]];
                            else if( ![SFVUtil isEmpty:relationshipName] ) {
                                NSArray *newFields = [NSArray arrayWithObjects:@"Name", @"email", @"title", @"phone", 
                                                                @"mobilephone", @"city", @"state", @"department", nil];
                                
                                if( [[SFVAppCache sharedSFVAppCache] isChatterEnabled] )
                                    newFields = [newFields arrayByAddingObjectsFromArray:[NSArray arrayWithObjects:@"smallphotourl", @"fullphotourl", @"aboutme", nil]];
                                
                                for( NSString *s in newFields ) 
                                    [ret addObject:[NSString stringWithFormat:@"%@.%@", relationshipName, s]];
                            }
                        } else if( ![SFVUtil isEmpty:relationshipName] ) {
                            [ret addObject:[NSString stringWithFormat:@"%@.Id", relationshipName]];
                            
                            for( NSString *refTo in referenceTo ) {
                                [ret addObject:[NSString stringWithFormat:@"%@.%@",
                                                                relationshipName,
                                                                [[SFVAppCache sharedSFVAppCache] nameFieldForsObject:refTo]]];
                                
                                if( [[SFVAppCache sharedSFVAppCache] doesObject:refTo haveProperty:ObjectIsRecordTypeEnabled] )
                                    [ret addObject:[NSString stringWithFormat:@"%@.%@",
                                                    relationshipName,
                                                    kRecordTypeIdField]];
                            }
                        }
                    } else if( [fieldType isEqualToString:@"currency"] && [[SFVAppCache sharedSFVAppCache] isMultiCurrencyEnabled] )
                        [ret addObject:@"CurrencyIsoCode"];                        
                    
                    [ret addObject:fname];
                }     
            }
        }
    }
    
    // Ensure that header fields are included in the query for accounts
    if( [sObject isEqualToString:@"Account"] ) 
        for( NSString *headerField in [NSArray arrayWithObjects:@"Name", @"Phone", @"Industry", @"Website", nil] ) {
            NSDictionary *desc = [[SFVAppCache sharedSFVAppCache] describeForField:headerField onObject:@"Account"];
            
            // access check for this field. even though it's a standard field, some users may not have access
            if( desc )
                [ret addObject:headerField];
        }
    
    if( [sObject isEqualToString:@"Lead"] ) {
        [ret addObject:@"IsUnreadByOwner"];
        [ret addObject:@"IsConverted"];
    }
    
    if( [[SFVAppCache sharedSFVAppCache] doesObject:sObject haveProperty:ObjectIsRecordTypeEnabled] ) {
        [ret addObject:kRecordTypeIdField];
        [ret addObject:@"RecordType.Name"];
    }
    
    // Handle person accounts
    if( [[SFVAppCache sharedSFVAppCache] isPersonAccountEnabled] && [sObject isEqualToString:@"Account"] )
        [ret addObjectsFromArray:[NSArray arrayWithObjects:@"PersonContactId", @"IsPersonAccount", nil]];
    
    // Also, some page layouts don't include the record name so we must be sure to include it
    [ret addObject:[[SFVAppCache sharedSFVAppCache] nameFieldForsObject:sObject]];
    
    return [[NSSet setWithArray:ret] allObjects];
}

#pragma mark - network activity indicator management

- (void) refreshNetworkIndicator {
    [UIApplication sharedApplication].networkActivityIndicatorVisible = activityCount > 0;
}

- (void) startNetworkAction {
    // Start the network activity spinner
    if( !activityCount )
        activityCount = 0;
    
    activityCount++;

    [self refreshNetworkIndicator];
}

- (void) endNetworkAction {
    if( activityCount > 0 )
        activityCount--;
    else
        activityCount = 0;
    
    [self refreshNetworkIndicator];
}

+ (BOOL) isConnected {
    NSURL *url = [NSURL URLWithString:@"http://www.google.com"];
    NSURLRequest *request = [NSMutableURLRequest requestWithURL:url];
    NSHTTPURLResponse *response = nil;
    [NSURLConnection sendSynchronousRequest:request
                          returningResponse:&response error:NULL];
    return (response != nil);
}

#pragma mark - Error and alert functions

- (void) receivedException:(NSException *)e {
    NSLog(@"*** Exception *** %@", e );
    
    /*[PRPAlertView showWithTitle:@"Error"
                        message:( description ? description : [NSString stringWithFormat:@"%@", e])
                    buttonTitle:@"OK"];*/
}

// Handle displaying an error as a result of an API call to SFDC
- (void) receivedAPIError:(NSError *)error {
    NSLog(@"*** API ERROR *** %@", error);
    
    //[PRPAlertView showWithTitle:@"API Error" message:[error localizedDescription] buttonTitle:@"OK"];
}

// Handle any other kind of internal error and hard crash if necessary
- (void) internalError:(NSError *)error {
    NSLog(@"*** Unresolved error %@, %@", error, [error userInfo]);
}

#pragma mark - Misc utility functions

- (NSString *)currentUserId {
    return [[[self client] currentUserInfo] userId];
}

- (NSString *)sessionId {
    return [[self client] sessionId];
}

- (NSString *)currentOrgName {
    NSString *name = [[[self client] currentUserInfo] organizationName];
    
    return ( [SFVUtil isEmpty:name] ? @"salesforce.com" : name );
}

- (NSString *)currentUserName {
    return [[[self client] currentUserInfo] fullName];
}

+ (NSString *) truncateURL:(NSString *)url {
    NSMutableString *ret = [url mutableCopy];
    
    for( NSString *prefix in [NSArray arrayWithObjects:@"http://", @"https://", @"www.", nil] )
        if( [ret hasPrefix:prefix] )
            [ret deleteCharactersInRange:NSMakeRange( 0, [prefix length] )];
    
    if( [ret hasSuffix:@"/"] )
        [ret deleteCharactersInRange:NSMakeRange( [ret length] - 1, 1 )];
    
    return [ret autorelease];
}

+ (NSString *) trimWhiteSpaceFromString:(NSString *)source {
    NSCharacterSet *whitespaces = [NSCharacterSet whitespaceCharacterSet];
    NSPredicate *noEmptyStrings = [NSPredicate predicateWithFormat:@"SELF != ''"];
    
    NSArray *parts = [source componentsSeparatedByCharactersInSet:whitespaces];
    NSArray *filteredArray = [parts filteredArrayUsingPredicate:noEmptyStrings];
    
    source = [filteredArray componentsJoinedByString:@" "];
    
    while( [source rangeOfString:@"\n \n"].location != NSNotFound )
        source = [source stringByReplacingOccurrencesOfString:@"\n \n" withString:@"\n"];
    
    return source;
}

// Take an array of records, ordered by date, and break them into 1d, 1w, 1m, 3, 6, 6+ months
+ (NSDictionary *) dictionaryFromRecordsGroupedByDate:(NSArray *)records dateField:(NSString *)dateField {
    if( !records )
        return nil;
    
    NSMutableArray *arrays = [NSMutableArray arrayWithCapacity:GroupNumDateGroups];
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    
    for( int i = 0; i < GroupNumDateGroups; i++ )
        [arrays addObject:[NSMutableArray array]];
    
    for( id ob in records ) {
        NSDictionary *record;
        
        // Live query?
        if( [ob isMemberOfClass:[ZKSObject class]] )
            record = [ob fields];
        else
            record = ob;
        
        double timeAgo = fabs( [[SFVUtil dateFromSOQLDatetime:[record objectForKey:dateField]] timeIntervalSinceNow] );
                
        if( timeAgo < 60 * 60 * 24 )
            [[arrays objectAtIndex:GroupOneDay] addObject:record];
        else if( timeAgo < 60 * 60 * 24 * 7 )
            [[arrays objectAtIndex:GroupOneWeek] addObject:record];
        else if( timeAgo < 60 * 60 * 24 * 7 * 4 )
            [[arrays objectAtIndex:GroupOneMonth] addObject:record];
        else if( timeAgo < 60 * 60 * 24 * 7 * 4 * 3 )
            [[arrays objectAtIndex:GroupThreeMonths] addObject:record];
        else if( timeAgo < 60 * 60 * 24 * 7 * 4 * 6 )
            [[arrays objectAtIndex:GroupSixMonths] addObject:record];
        else
            [[arrays objectAtIndex:GroupSixMonthsPlus] addObject:record];
    }
    
    for( int i = 0; i < [arrays count]; i++ )
        [ret setObject:[arrays objectAtIndex:i] forKey:[NSNumber numberWithInt:i]];
    
    return ret;
}

// Takes an array of dictionaries or sobjects and alphabetizes them into a dictionary
// key is the first letter of the account name, value is an array of accounts starting with that letter
// in alphabetical order ascending - assumes results were passed to us in alphabetical order
+ (NSDictionary *) dictionaryFromAccountArray:(NSArray *)results {
    if( !results )
        return nil;
    
    NSMutableDictionary *ret = [NSMutableDictionary dictionary];
    NSString *name = nil;
    
    for( id ob in results ) {
        NSDictionary *accountDict = [SFVAsync ZKSObjectToDictionary:ob];
        
        // Leads, Contacts always use lastname
        if( [[NSArray arrayWithObjects:@"Lead", @"Contact", nil] containsObject:[accountDict objectForKey:kObjectTypeKey]] )
            name = [accountDict objectForKey:@"LastName"];
        else
            name = [[SFVAppCache sharedSFVAppCache] nameForSObject:accountDict];
        
        // first char of this account's name
        NSString *index = ( name && [name length] > 0 
                            ? [[name substringToIndex:1] uppercaseString]
                            : @"#" );
        
        if( ![[NSCharacterSet letterCharacterSet] characterIsMember:[index characterAtIndex:0]] )
            index = @"#";
        
        // Add this account to the list of accounts at this position
        if( ![ret objectForKey:index] )
            [ret setObject:[NSArray arrayWithObject:accountDict] forKey:index];
        else {
            NSArray *records = [[ret objectForKey:index] arrayByAddingObject:accountDict];
            
            [ret setObject:records forKey:index];
        }
    }
    
    return ret;
}

// Given a dictionary defined as in dictionaryFromAccountArray, add some new accounts to it
// while maintaining alphabetical order by name
+ (NSDictionary *) dictionaryByAddingAccounts:(NSArray *)accounts toDictionary:(NSDictionary *)allAccounts {
    NSMutableDictionary *newDictionary = [NSMutableDictionary dictionaryWithDictionary:allAccounts];
    
    if( !accounts || [accounts count] == 0 )
        return newDictionary;
    
    for( id a in accounts ) {
        NSDictionary *newAccount = [SFVAsync ZKSObjectToDictionary:a];
        NSString *name = nil;
        
        // Leads, Contacts always use lastname
        if( [[NSArray arrayWithObjects:@"Lead", @"Contact", nil] containsObject:[newAccount objectForKey:kObjectTypeKey]] )
            name = [newAccount objectForKey:@"LastName"];
        else
            name = [[SFVAppCache sharedSFVAppCache] nameForSObject:newAccount];
        
        if( [SFVUtil isEmpty:name] )
            continue;
        
        NSString *index = [[name substringToIndex:1] uppercaseString];
        
        if( ![[NSCharacterSet letterCharacterSet] characterIsMember:[index characterAtIndex:0]] )
            index = @"#";
        
        if( ![newDictionary objectForKey:index] )
            [newDictionary setObject:[NSArray array] forKey:index];
        
        NSMutableArray *indexAccounts = [NSMutableArray arrayWithArray:[newDictionary objectForKey:index]];
        
        if( [indexAccounts count] == 0 )
            [indexAccounts addObject:newAccount];
        else {
            BOOL added = NO;
            
            for( int x = 0; x < [indexAccounts count]; x++ ) {
                NSString *otherName = [[SFVAppCache sharedSFVAppCache] nameForSObject:[indexAccounts objectAtIndex:x]];
                
                if( [name compare:otherName options:NSCaseInsensitiveSearch] != NSOrderedDescending ) {
                    [indexAccounts insertObject:newAccount atIndex:x];
                    added = YES;
                    break;
                }
            }
            
            if( !added )
                [indexAccounts addObject:newAccount];
        }
        
        [newDictionary setObject:indexAccounts forKey:index];
    }
    
    return newDictionary;
}

// Given an index path, get an account from a dictionary defined as in dictionaryFromAccountArray
+ (NSDictionary *) accountFromIndexPath:(NSIndexPath *)ip accountDictionary:(NSDictionary *)allAccounts {
    if( !ip || !allAccounts )
        return nil;
    
    NSArray *sortedKeys = [[self class] sortArray:[allAccounts allKeys]];
    NSString *index = [sortedKeys objectAtIndex:[ip section]];
    NSArray *indexedAccounts = [allAccounts objectForKey:index];
    
    return [indexedAccounts objectAtIndex:ip.row];
}

// Given an account, get an index path for it from a dictionary defined as in dictionaryFromAccountArray
+ (NSIndexPath *) indexPathForAccountDictionary:(NSDictionary *)account allAccountDictionary:(NSDictionary *)allAccounts {
    int section = 0, row = 0;
    
    if( !account || !allAccounts )
        return nil;
    
    NSString *index = nil; 
    NSString *name = [[SFVAppCache sharedSFVAppCache] nameForSObject:account];
    
    if( [SFVUtil isEmpty:name] )
        index = nil;
    else if( ![[NSCharacterSet letterCharacterSet] characterIsMember:[name characterAtIndex:0]] )
        index = @"#";
    else
        index = [[name substringToIndex:1] uppercaseString];
        
    NSArray *keys = [self sortArray:[allAccounts allKeys]];
        
    if( !index ) {
        for( NSString *key in keys ) {
            for( NSDictionary *a in [allAccounts objectForKey:key] ) {                
                if( [[a objectForKey:@"Id"] isEqualToString:[account objectForKey:@"Id"]] )
                    return [NSIndexPath indexPathForRow:row inSection:section];
                else
                    row++;
            }
            
            section++;
            row = 0;
        }
    } else {
        NSArray *accounts = [allAccounts objectForKey:index];
        
        for( NSString *key in keys )
            if( [key isEqualToString:index] )
                break;
            else
                section++;
        
        for( NSDictionary *a in accounts ) {
            if( [[a objectForKey:@"Id"] isEqualToString:[account objectForKey:@"Id"]] )
                return [NSIndexPath indexPathForRow:row inSection:section];
            
            row++;
        }
    }
    
    return nil;    
}

+ (BOOL) isEmpty:(id) thing {
    return thing == nil
    || [thing isKindOfClass:[NSNull class]]
    || ([thing respondsToSelector:@selector(length)]
        && [(NSData *)thing length] == 0)
    || ([thing respondsToSelector:@selector(count)]
        && [(NSArray *)thing count] == 0);
}

+ (NSArray *) randomSubsetFromArray:(NSArray *)original ofSize:(int)size {
    NSMutableSet *names = [NSMutableSet set];
    
    if( !original || [original count] == 0 )
        return [NSArray array];
    
    if( size <= 0 || size >= [original count] )
        return original;
    
    do {
        [names addObject:[original objectAtIndex:( arc4random() % [original count] )]];
    } while( [names count] < size );              
    
    return [names allObjects];
}

+ (NSString *) SOQLDatetimeFromDate:(NSDate *)date isDateTime:(BOOL)isDateTime {
    if( !date )
        date = [NSDate dateWithTimeIntervalSinceNow:0];
    
    // 2011-01-24T17:34:14.000Z
    
    NSDateFormatter *dformatter = [[NSDateFormatter alloc] init];
    [dformatter setLocale:[NSLocale currentLocale]];
    
    if( isDateTime ) {
        [dformatter setDateFormat:@"yyyy'-'MM'-'dd'T'HH':'mm':'ss'.000Z'"];
        NSTimeZone *tz = [NSTimeZone defaultTimeZone];
        NSInteger seconds = -[tz secondsFromGMTForDate:date];
        date = [NSDate dateWithTimeInterval:seconds sinceDate:date];
    } else
        [dformatter setDateFormat:@"yyyy'-'MM'-'dd"];
    
    NSString *format = [dformatter stringFromDate:date];
    [dformatter release];
        
    return format;
}

+ (NSDate *) dateFromSOQLDatetime:(NSString *)datetime {
    // datetime 2011-01-24T17:34:14.000Z
    // date 2011-01-24
    // also date: 4/30/12 ?
    NSDate *date;
    BOOL isDateTime = NO;
        
    if( [SFVUtil isEmpty:datetime] )
        return [NSDate dateWithTimeIntervalSinceNow:0];
        
    datetime = [datetime stringByReplacingOccurrencesOfString:@".000Z" withString:@""];
    datetime = [datetime stringByReplacingOccurrencesOfString:@".000+0000" withString:@""]; // REST
    datetime = [datetime stringByReplacingOccurrencesOfString:@"T" withString:@" "];
    datetime = [self trimWhiteSpaceFromString:datetime];
        
    NSDateFormatter *dformatter = [[NSDateFormatter alloc] init];
    [dformatter setLocale:[NSLocale currentLocale]];
    
    if( [datetime rangeOfString:@"/"].location != NSNotFound )
        [dformatter setDateFormat:@"M/dd/yy"];
    else if( [datetime rangeOfString:@" "].location == NSNotFound )
        [dformatter setDateFormat:@"yyyy-MM-dd"];
    else {
        [dformatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        isDateTime = YES;
    }
    
    date = [dformatter dateFromString:datetime];
    [dformatter release];

    // only do time zone adjustments for datetimes
    if( isDateTime ) {
        NSTimeZone *tz = [NSTimeZone defaultTimeZone];
        NSInteger seconds = [tz secondsFromGMTForDate:date];
        return [NSDate dateWithTimeInterval:seconds sinceDate:date];
    }
    
    return date;
}

+ (NSArray *) filterRecords:(NSArray *)records dateField:(NSString *)dateField withDate:(NSDate *)date createdAfter:(BOOL)createdAfter {
    if( !records || !dateField )
        return nil;
    
    if( !date || [records count] == 0 )
        return records;
    
    NSMutableArray *ret = [NSMutableArray arrayWithCapacity:[records count]];
    
    for( NSDictionary *record in records ) {
        NSComparisonResult result = [date compare:[SFVUtil dateFromSOQLDatetime:[record objectForKey:dateField]]];
        
        if( createdAfter && result == NSOrderedAscending )
            [ret addObject:record];
        else if( !createdAfter && result == NSOrderedDescending )
            [ret addObject:record];
    }
    
    return ret;
}

// Sort an array alphabetically
+ (NSArray *)sortArray:(NSArray *)toSort {
    if( !toSort || [toSort count] == 0 )
        return [NSArray array];
    
    if( [[toSort objectAtIndex:0] isKindOfClass:[NSString class]] )
        return [toSort sortedArrayUsingSelector:@selector(localizedCaseInsensitiveCompare:)];
    
    return [toSort sortedArrayUsingSelector:@selector(compare:)];
}

// Returns a relative amount of time since a date
+ (NSString *)relativeTime:(NSDate *)sinceDate {
    double d = fabs( [sinceDate timeIntervalSinceNow] );
    
    if( d < 2 )
        return NSLocalizedString(@"just now", @"just now relative time");
    else if (d < 60) {
        int diff = round(d);
        return [NSString stringWithFormat:@"%d%@", 
                diff,
                NSLocalizedString(@"s ago", @"seconds ago relative time")];
    } else if (d < 3600) {
        int diff = round(d / 60);
        return [NSString stringWithFormat:@"%d%@", 
                diff,
                NSLocalizedString(@"m ago", @"minutes ago relative time")];
    } else if (d < 86400) {
        int diff = round(d / 60 / 60);
        return [NSString stringWithFormat:@"%d%@", 
                diff,
                NSLocalizedString(@"h ago", @"hours ago relative time")];
    } else if (d < 2629743) {
        int diff = round(d / 60 / 60 / 24);
        return [NSString stringWithFormat:@"%d%@", 
                diff,
                NSLocalizedString(@"d ago", @"days ago relative time")];
    } else {
        int diff = round(d / 60 / 60 / 24 / 30);
        return [NSString stringWithFormat:@"%d%@", 
                diff,
                NSLocalizedString(@"mo ago", @"months ago relative time")];
    }
}

void addRoundedRectToPath(CGContextRef context, CGRect rect, float ovalWidth, float ovalHeight) {
    float fw, fh;
	if (ovalWidth == 0 || ovalHeight == 0) {
		CGContextAddRect(context, rect);
		return;
	}
	CGContextSaveGState(context);
	CGContextTranslateCTM (context, CGRectGetMinX(rect), CGRectGetMinY(rect));
	CGContextScaleCTM (context, ovalWidth, ovalHeight);
	fw = CGRectGetWidth (rect) / ovalWidth;
	fh = CGRectGetHeight (rect) / ovalHeight;
	CGContextMoveToPoint(context, fw, fh/2);
	CGContextAddArcToPoint(context, fw, fh, fw/2, fh, 1);
	CGContextAddArcToPoint(context, 0, fh, 0, fh/2, 1);
	CGContextAddArcToPoint(context, 0, 0, fw/2, 0, 1);
	CGContextAddArcToPoint(context, fw, 0, fw, fh/2, 1);
	CGContextClosePath(context);
	CGContextRestoreGState(context);
}

+ (NSString *) stripHTMLTags:(NSString *)str {
    NSMutableString *html = [NSMutableString stringWithCapacity:[str length]];
    
    NSScanner *scanner = [NSScanner scannerWithString:str];
    NSString *tempText = nil;
    
    while (![scanner isAtEnd]) {
        [scanner scanUpToString:@"<" intoString:&tempText];
        
        if (tempText != nil)
            [html appendString:[NSString stringWithFormat:@" %@", tempText]];
        
        [scanner scanUpToString:@">" intoString:NULL];
        
        if (![scanner isAtEnd])
            [scanner setScanLocation:[scanner scanLocation] + 1];
        
        tempText = nil;
    }
        
    return [self trimWhiteSpaceFromString:html];
}

+ (NSString *)stringByDecodingEntities:(NSString *)str {
    NSUInteger myLength = [str length];
    NSUInteger ampIndex = [str rangeOfString:@"&" options:NSLiteralSearch].location;
    
    // Short-circuit if there are no ampersands.
    if (ampIndex == NSNotFound) {
        return str;
    }
    // Make result string with some extra capacity.
    NSMutableString *result = [NSMutableString stringWithCapacity:(myLength * 1.25)];
    
    // First iteration doesn't need to scan to & since we did that already, but for code simplicity's sake we'll do it again with the scanner.
    NSScanner *scanner = [NSScanner scannerWithString:str];
    
    [scanner setCharactersToBeSkipped:nil];
    
    NSCharacterSet *boundaryCharacterSet = [NSCharacterSet characterSetWithCharactersInString:@" \t\n\r;"];
    
    do {
        // Scan up to the next entity or the end of the string.
        NSString *nonEntityString;
        if ([scanner scanUpToString:@"&" intoString:&nonEntityString]) {
            [result appendString:nonEntityString];
        }
        if ([scanner isAtEnd]) {
            goto finish;
        }
        // Scan either a HTML or numeric character entity reference.
        if ([scanner scanString:@"&amp;" intoString:NULL])
            [result appendString:@"&"];
        else if([scanner scanString:@"&nbsp;" intoString:NULL])
            [result appendString:@" "];
        else if ([scanner scanString:@"&apos;" intoString:NULL])
            [result appendString:@"'"];
        else if ([scanner scanString:@"&quot;" intoString:NULL])
            [result appendString:@"\""];
        else if ([scanner scanString:@"&lt;" intoString:NULL])
            [result appendString:@"<"];
        else if ([scanner scanString:@"&gt;" intoString:NULL])
            [result appendString:@">"];
        else if ([scanner scanString:@"&#" intoString:NULL]) {
            BOOL gotNumber;
            unsigned charCode;
            NSString *xForHex = @"";
            
            // Is it hex or decimal?
            if ([scanner scanString:@"x" intoString:&xForHex]) {
                gotNumber = [scanner scanHexInt:&charCode];
            }
            else {
                gotNumber = [scanner scanInt:(int*)&charCode];
            }
            
            if (gotNumber) {
                [result appendFormat:@"%u", charCode];
                
                [scanner scanString:@";" intoString:NULL];
            }
            else {
                NSString *unknownEntity = @"";
                
                [scanner scanUpToCharactersFromSet:boundaryCharacterSet intoString:&unknownEntity];
                
                
                [result appendFormat:@"&#%@%@", xForHex, unknownEntity];
                
                //[scanner scanUpToString:@";" intoString:&unknownEntity];
                //[result appendFormat:@"&#%@%@;", xForHex, unknownEntity];
                NSLog(@"Expected numeric character entity but got &#%@%@;", xForHex, unknownEntity);
                
            }
            
        }
        else {
            NSString *amp;
            
            [scanner scanString:@"&" intoString:&amp];      //an isolated & symbol
            [result appendString:amp];
            
            /*
             NSString *unknownEntity = @"";
             [scanner scanUpToString:@";" intoString:&unknownEntity];
             NSString *semicolon = @"";
             [scanner scanString:@";" intoString:&semicolon];
             [result appendFormat:@"%@%@", unknownEntity, semicolon];
             NSLog(@"Unsupported XML character entity %@%@", unknownEntity, semicolon);
             */
        }
        
    }
    while (![scanner isAtEnd]);
    
finish:
    return result;
}

+ (NSString *) stringByAppendingSessionIdToURLString:(NSString *)urlstring sessionId:(NSString *)sessionId {
    NSMutableString *ret = [NSMutableString stringWithString:urlstring];
    
    if( [urlstring rangeOfString:@"?"].location == NSNotFound )
        [ret appendString:@"?"];
    else
        [ret appendString:@"&"];
    
    [ret appendFormat:@"oauth_token=%@", sessionId];
    
    return ret;
}

+ (NSString *) stringByAppendingSessionIdToImagesInHTMLString:(NSString *)htmlstring sessionId:(NSString *)sessionId {
    // Quick exit if there are no images    
    if( [htmlstring rangeOfString:@"<img" options:NSCaseInsensitiveSearch].location == NSNotFound ||
        [htmlstring rangeOfString:@"src=" options:NSCaseInsensitiveSearch].location == NSNotFound )
        return htmlstring;
        
    NSMutableString *result = [NSMutableString string];
    NSScanner *scanner = [NSScanner scannerWithString:htmlstring];
    [scanner setCharactersToBeSkipped:nil];
        
    do {
        NSString *nonEntityString;
        if ([scanner scanUpToString:@"<img" intoString:&nonEntityString]) {
            [result appendString:nonEntityString];
                        
            // Scan to the URL marker
            if([scanner scanUpToString:@"src=\"" intoString:&nonEntityString]) {
                [result appendString:nonEntityString];
                            
                if([scanner scanUpToString:@"\"" intoString:&nonEntityString])
                    [result appendString:nonEntityString];
                                
                NSString *urlstring;
                                
                // insert session ID
                if([scanner scanUpToString:@"\">" intoString:&urlstring] &&
                   [urlstring rangeOfString:@"content.force.com" options:NSCaseInsensitiveSearch].location != NSNotFound )
                    [result appendFormat:@"%@&oauth_token=%@",
                        urlstring, sessionId];
                else if( urlstring )
                    [result appendString:urlstring];   
            }
        }
    } while( ![scanner isAtEnd] );
    
    return result;
}

+ (NSString *)getIPAddress {
    NSString *address = @"error";
    struct ifaddrs *interfaces = NULL;
    struct ifaddrs *temp_addr = NULL;
    int success = 0;
    
    // retrieve the current interfaces - returns 0 on success
    success = getifaddrs(&interfaces);
    if (success == 0)
    {
        // Loop through linked list of interfaces
        temp_addr = interfaces;
        while(temp_addr != NULL)
        {
            if(temp_addr->ifa_addr->sa_family == AF_INET)
            {
                // Check if interface is en0 which is the wifi connection on the iPhone
                if([[NSString stringWithUTF8String:temp_addr->ifa_name] isEqualToString:@"en0"])
                {
                    // Get NSString from C String
                    address = [NSString stringWithUTF8String:inet_ntoa(((struct sockaddr_in *)temp_addr->ifa_addr)->sin_addr)];
                }
            }
            
            temp_addr = temp_addr->ifa_next;
        }
    }
    
    // Free memory
    freeifaddrs(interfaces);
    
    return address;
}

#pragma mark - Recent records

- (NSArray *) loadRecentRecords {
    NSArray *records = [[NSUserDefaults standardUserDefaults] arrayForKey:RecentRecords];
    
    if( !records || [records count] == 0 )
        return nil;
    
    return records;
}

- (void) addRecentRecord:(NSString *)recordId {
    NSArray *saved = [self loadRecentRecords];
    NSMutableArray *records = nil;
    
    if( saved )
        records = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:RecentRecords]];
    else
        records = [NSMutableArray array];
    
    if( [records containsObject:recordId] )
        [records removeObject:recordId];
    
    [records insertObject:recordId atIndex:0];
    
    if( [records count] > kMaxRecentRecords )
        [records removeLastObject];
    
    [[NSUserDefaults standardUserDefaults] setObject:records forKey:RecentRecords];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) removeRecentRecordWithId:(NSString *)recordId {
    NSMutableArray *records = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:RecentRecords]];
    
    if( [records containsObject:recordId] )
        [records removeObject:recordId];
    
    [[NSUserDefaults standardUserDefaults] setObject:records forKey:RecentRecords];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) removeRecentRecordsWithIds:(NSArray *)recordIds {
    NSMutableArray *records = [NSMutableArray arrayWithArray:[[NSUserDefaults standardUserDefaults] arrayForKey:RecentRecords]];
    
    for( NSString *recordId in recordIds )
        [records removeObject:recordId];
    
    [[NSUserDefaults standardUserDefaults] setObject:records forKey:RecentRecords];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (NSArray *) recentRecordsForSObject:(NSString *)sObject {
    NSArray *records = [[NSUserDefaults standardUserDefaults] arrayForKey:RecentRecords];
    NSMutableArray *ret = [NSMutableArray array];
    
    NSDictionary *desc = [[SFVAppCache sharedSFVAppCache] describeGlobalsObject:sObject];
    
    if( !desc )
        return nil;
    
    NSString *prefix = [desc objectForKey:@"keyPrefix"];
    
    for( NSString *record in records )
        if( [[record substringToIndex:3] isEqualToString:prefix] )
            [ret addObject:record];
    
    return ret;
}

- (void) clearRecentRecords {
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:RecentRecords];
    [[NSUserDefaults standardUserDefaults] synchronize];
}

- (void) loadImageFromURL:(NSString *)url cache:(BOOL)cache maxDimension:(CGFloat)maxDimension completeBlock:(ImageCompletionBlock)completeBlock {
    if( !url || [url length] == 0 )
        return;
    
    id cached = [userPhotoCache objectForKey:url];
        
    if( cached ) {
        if( [cached isKindOfClass:[UIImage class]] ) {
            //NSLog(@"IMG FROM CACHE: %@", url );
            UIImage *img = [(UIImage *)cached imageAtScale];
            
            if( maxDimension > 0 ) {
                float imgMaxDim = MAX( img.size.width, img.size.height );
                float scale = 1.0;
                CGSize targetSize = CGSizeZero;
                
                if( imgMaxDim > maxDimension ) {
                    scale = maxDimension / imgMaxDim;
                    targetSize = CGSizeMake( scale * img.size.width, scale * img.size.height );
                }
                
                if( !CGSizeEqualToSize( targetSize, CGSizeZero ) )
                    img = [img imageResizedToSize:targetSize];
            }
            
            if( completeBlock )
                completeBlock( img, YES );
        } else if( [cached isKindOfClass:[PRPConnection class]] ) {
            NSLog(@"DUPE IMG LOAD: %@", url );
            
            NSArray *savedBlocks = (NSArray *)objc_getAssociatedObject(cached, &imageLoadCompleteBlockArray);
            
            if( savedBlocks ) {
                NSMutableArray *completionBlocks = [NSMutableArray arrayWithArray:savedBlocks];
                [completionBlocks addObject:[[completeBlock copy] autorelease]];
                
                // Clear out the existing array
                objc_setAssociatedObject( cached, &imageLoadCompleteBlockArray, nil, OBJC_ASSOCIATION_ASSIGN);
                                
                // Save the new array
                objc_setAssociatedObject( cached, &imageLoadCompleteBlockArray, completionBlocks, OBJC_ASSOCIATION_COPY);
            }
        }
        
        return;
    }
    
    PRPConnectionCompletionBlock connCompleteBlock = ^(PRPConnection *connection, NSError *error) {
        [self endNetworkAction];
        
        // Load our complete block(s) for this request
        NSArray *completionBlocks = (NSArray *)objc_getAssociatedObject(connection, &imageLoadCompleteBlockArray);
        
        if( error ) {
            [self receivedAPIError:error];
            
            if( completionBlocks && [completionBlocks count] > 0 )
                for( ImageCompletionBlock block in completionBlocks )
                    if( block )
                        block( nil, NO );
            
            return;
        }
        
        UIImage *img = [[UIImage imageWithData:[connection downloadData]] imageAtScale];
        
        // Remove the blocks stored on this request
        objc_setAssociatedObject( connection, &imageLoadCompleteBlockArray, nil, OBJC_ASSOCIATION_ASSIGN);
        
        // remove this request from the cache
        [userPhotoCache removeObjectForKey:url];
        
        // Cache the image result
        if( img && cache )
            [self addUserPhotoToCache:img forURL:url];
        
        if( maxDimension > 0 ) {
            float imgMaxDim = MAX( img.size.width, img.size.height );
            float scale = 1.0;
            CGSize targetSize = CGSizeZero;
            
            if( imgMaxDim > maxDimension ) {
                scale = maxDimension / imgMaxDim;
                targetSize = CGSizeMake( scale * img.size.width, scale * img.size.height );
            }
                        
            if( !CGSizeEqualToSize( targetSize, CGSizeZero ) )
                img = [img imageResizedToSize:targetSize];
        }
        
        // Fire all completion blocks for this image
        if( completionBlocks && [completionBlocks count] > 0 )
            for( ImageCompletionBlock block in completionBlocks )
                if( block )
                    block( img, NO );
    };
    
    PRPConnection *imgDownload = [PRPConnection connectionWithURL:[NSURL URLWithString:url]
                                                    progressBlock:nil
                                                  completionBlock:connCompleteBlock];
        
    NSLog(@"IMAGE LOAD: %@", url);
    
    // Add our complete block to this request
    if( completeBlock ) {
        NSArray *blockArray = [NSArray arrayWithObject:[[completeBlock copy] autorelease]];
        objc_setAssociatedObject( imgDownload, &imageLoadCompleteBlockArray, blockArray, OBJC_ASSOCIATION_COPY);
    }
    
    // Add the request to the cache
    [userPhotoCache setObject:imgDownload forKey:url];
    
    // Begin the download
    [self startNetworkAction];
    [imgDownload start];
}

@end
