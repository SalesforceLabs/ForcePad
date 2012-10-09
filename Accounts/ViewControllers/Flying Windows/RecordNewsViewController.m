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

#import "RecordNewsViewController.h"
#import "RootViewController.h"
#import "DetailViewController.h"
#import "WebViewController.h"
#import "NewsTableViewCell.h"
#import "SBJson.h"
#import <QuartzCore/QuartzCore.h>
#import "DSActivityView.h"
#import "ListOfRelatedListsViewController.h"
#import "SFVAppCache.h"

@implementation RecordNewsViewController

@synthesize newsTableViewController, newsConnection, jsonArticles, noNewsView, newsSearchTerm, sourceLabel;

#pragma mark - init, layout, setup

- (id) initWithFrame:(CGRect)frame {
    if((self = [super initWithFrame:frame])) { 
        self.view.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paperbg.png"]];
        
        if( !self.noNewsView ) {
            self.noNewsView = [[[UIView alloc] initWithFrame:CGRectMake( 0, 0, frame.size.width, 300 )] autorelease];
            self.noNewsView.backgroundColor = [UIColor clearColor];
            self.noNewsView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            
            float curY = 0.0f;
            
            UIButton *noNewsButton = [UIButton buttonWithType:UIButtonTypeCustom];
            noNewsButton.titleLabel.numberOfLines = 0;
            noNewsButton.titleLabel.lineBreakMode = UILineBreakModeWordWrap;
            [noNewsButton setTitleColor:[UIColor darkGrayColor] forState:UIControlStateNormal];
            noNewsButton.titleLabel.textAlignment = UITextAlignmentCenter;
            [noNewsButton.titleLabel setFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:28]];
            [noNewsButton setTitle:NSLocalizedString(@"No News — Tap to Refresh", @"No news label") forState:UIControlStateNormal];
            noNewsButton.backgroundColor = [UIColor clearColor];
            [noNewsButton addTarget:self action:@selector(refresh:) forControlEvents:UIControlEventTouchUpInside];
            noNewsButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
            
            CGSize s = [[noNewsButton titleForState:UIControlStateNormal] sizeWithFont:noNewsButton.titleLabel.font
                                                                     constrainedToSize:CGSizeMake( frame.size.width - 20, 999 )];
            s.width = frame.size.width - 20;
            
            [noNewsButton setFrame:CGRectMake( 10, curY, s.width, s.height )];
            [self.noNewsView addSubview:noNewsButton];
            curY += noNewsButton.frame.size.height + 45;
            
            [self.noNewsView setFrame:CGRectMake( 0, lroundf( ( frame.size.height - self.navBar.frame.size.height - curY ) / 2.0f ), 
                                                  frame.size.width, curY )];
                        
            [self.view addSubview:self.noNewsView];
        }
                
        isCompoundNewsView = NO;        
        isLoadingNews = NO;
        resultStart = 0;
    }
    
    return self;
}

- (void) setCompoundNewsView:(BOOL) cnv {
    isCompoundNewsView = cnv;
}

- (void) layoutView {
    if( !self.newsTableViewController )
        return;
            
    for( id cell in [self.newsTableViewController.tableView visibleCells] ) {
        [cell setCellWidth:(self.newsTableViewController.tableView.frame.size.width - 35)];
        [cell layoutCell];
    }
}

- (CGSize) maxImageSize {
    return CGSizeMake( 80, 100 );
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}

- (void) dealloc {
    [self stopLoading];
    
    [jsonArticles release];
    [newsConnection release];
    [newsSearchTerm release];
    [newsTableViewController release];
    [sourceLabel release];
    [noNewsView release];
    [super dealloc];
}

#pragma mark - adding and removing the news table

- (void) addTableView {
    if( !self.newsTableViewController ) {
        PullRefreshTableViewController *ntvc = [[PullRefreshTableViewController alloc] initWithStyle:UITableViewStylePlain useHeaderImage:YES];
        
        ntvc.tableView.delegate = self;   
        ntvc.tableView.dataSource = self;
        ntvc.tableView.delaysContentTouches = YES;
        ntvc.tableView.canCancelContentTouches = YES;
        ntvc.tableView.separatorColor = UIColorFromRGB(0x999999);
        ntvc.tableView.backgroundColor = [UIColor colorWithPatternImage:[UIImage imageNamed:@"paperbg.png"]];
            
        self.newsTableViewController = ntvc;
        [ntvc release];
                
        // Size our tableview        
        [self.newsTableViewController.view setFrame:CGRectMake( 0, 
                                                               self.navBar.frame.size.height,
                                                               self.view.frame.size.width, 
                                                               self.view.frame.size.height - self.navBar.frame.size.height)];
        
        self.sourceLabel = [[[UILabel alloc] initWithFrame:CGRectMake( 0, 0, self.newsTableViewController.view.frame.size.width, 20)] autorelease];
        sourceLabel.text = NSLocalizedString(@"Powered by Google News", @"Google news attribution");
        sourceLabel.backgroundColor = [UIColor clearColor];
        sourceLabel.font = [UIFont fontWithName:@"HelveticaNeue" size:13];
        sourceLabel.textAlignment = UITextAlignmentCenter;
        sourceLabel.textColor = [UIColor darkGrayColor];
        sourceLabel.shadowColor = [UIColor whiteColor];
        sourceLabel.shadowOffset = CGSizeMake(0, 1);
        sourceLabel.numberOfLines = 1;
        
        self.newsTableViewController.tableView.tableHeaderView = sourceLabel;
        
        [self.view addSubview:self.newsTableViewController.view];
    }
    
    resultStart = 0;
    isLoadingNews = NO;
    noNewsView.hidden = YES;
        
    [[NSNotificationCenter defaultCenter] 
     addObserver:self 
     selector:@selector(layoutView)
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
}

- (void) removeTableView {
    if( self.newsTableViewController ) {
        [self.newsTableViewController.view removeFromSuperview];
        self.newsTableViewController = nil;
    }
    
    noNewsView.hidden = NO;
    
    [[NSNotificationCenter defaultCenter]
     removeObserver:self 
     name:UIDeviceOrientationDidChangeNotification 
     object:nil];
}

#pragma mark - performing news search

- (void) setSearchTerm:(NSString *)st {
    if( !st )
        return;
    
    self.newsSearchTerm = st;
    
    resultStart = 0;
    isLoadingNews = NO;

    [self refresh:YES];
}

- (void) stopLoading {
    if( self.newsConnection ) {
        [self.newsConnection stop];
        [[SFVUtil sharedSFVUtil] endNetworkAction];
        self.newsConnection = nil;
    }
}

- (void) refresh:(BOOL)resetRefresh { 
    if( isLoadingNews )
        return;
    
    if( resetRefresh ) {
        resultStart = 0;
        [jsonArticles removeAllObjects];
    }
    
    // Google returns a max of 64 results.
    // http://code.google.com/apis/newssearch/v1/jsondevguide.html#request_format
    if( resultStart >= 64 || ( estimatedArticles > 0 && resultStart >= estimatedArticles ) )
        return;
    
    [self stopLoading];     
    noNewsView.hidden = YES;
    
    if( self.newsTableViewController ) {
        CGRect r = self.newsTableViewController.tableView.tableFooterView.frame;
        r.size.height = 90;
        
        [self.newsTableViewController.tableView.tableFooterView setFrame:r];
    }
    
    [self pushNavigationBarWithTitle:NSLocalizedString(@"Loading...", @"Loading...") animated:NO];
    
    NSString *newsURL = [NEWS_ENDPOINT stringByAppendingFormat:@"&q=%@&rsz=8&userip=%@&hl=%@&start=%i&key=%@%@", 
                           [[[SFVUtil trimWhiteSpaceFromString:newsSearchTerm] stringByAppendingString:@" -CNN -BBC -nytimes -foxnews"] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding],
                           [SFVUtil getIPAddress],
                           [[NSLocale preferredLanguages] objectAtIndex:0],
                           resultStart,
                           NEWS_API_KEY,
                           ( [[[NSUserDefaults standardUserDefaults] stringForKey:@"news_sort_by"] isEqualToString:@"Date"] ? @"&scoring=d" : @"" )
                         ];
    
    NSLog(@"NEWS SEARCH '%@' with URL %@", newsSearchTerm, newsURL);
    
    // Block to be called when we receive a JSON google news response
    PRPConnectionCompletionBlock complete = ^(PRPConnection *connection, NSError *error) {
        [[SFVUtil sharedSFVUtil] endNetworkAction];
        [self.newsTableViewController stopLoading];
        isLoadingNews = NO;
        
        if( ![self isViewLoaded] ) 
            return;
        
        NSString *title = [NSString stringWithFormat:@"%@ %@", 
                           ( isCompoundNewsView ? [[SFVAppCache sharedSFVAppCache] labelForSObject:@"Account" usePlural:NO] : newsSearchTerm ),
                           NSLocalizedString(@"News", @"News")];
        
        [self pushNavigationBarWithTitle:title
                                animated:NO];
        
        if (error) {
            [self removeTableView];          
            return;
        } else {
            NSString *responseStr = [[NSString alloc] initWithData:connection.downloadData encoding:NSUTF8StringEncoding];
            
            //NSLog(@"received response %@", responseStr);
            
            SBJsonParser *jp = [[SBJsonParser alloc] init];
            NSDictionary *json = [jp objectWithString:responseStr];
            [responseStr release];
            [jp release];
            
            if( !json || [[json objectForKey:@"responseData"] isMemberOfClass:[NSNull class]] || [[json valueForKeyPath:@"responseData.results"] isMemberOfClass:[NSNull class]] ) {
                [self removeTableView];
                return;
            }
            
            NSArray *articles = [json valueForKeyPath:@"responseData.results"];
            
            if( jsonArticles )
                [jsonArticles addObjectsFromArray:articles];
            else                        
                jsonArticles = [[NSMutableArray arrayWithArray:articles] retain];
            
            [[SFAnalytics sharedInstance] tagEventOfType:SFVUserViewedNews
                                              attributes:[NSDictionary dictionaryWithObjectsAndKeys:
                                                          newsSearchTerm, @"Search Term",
                                                          [SFAnalytics bucketStringForNumber:[NSNumber numberWithInt:[jsonArticles count]]
                                                                                  bucketSize:5], @"Article Count",
                                                          nil]];
            
            if( !jsonArticles || [jsonArticles count] == 0 ) {
                [self removeTableView];
            } else {
                [self addTableView];
                
                NSString *est = [json valueForKeyPath:@"responseData.cursor.estimatedResultCount"];
                
                if( est )
                    estimatedArticles = [est intValue];
                
                resultStart = [jsonArticles count];

                [self.newsTableViewController.tableView reloadData];
            }
        }
    }; // END JSON response block
    
    // Initiate the download
    NSMutableURLRequest *req = [NSMutableURLRequest requestWithURL:[NSURL URLWithString:newsURL]];
    [req addValue:[NSString stringWithFormat:@"%@ for iPad", [SFVUtil appFullName]] forHTTPHeaderField:@"Referer"];
    
    self.newsConnection = [PRPConnection connectionWithRequest:req
                                             progressBlock:nil
                                           completionBlock:complete];
    [self.newsConnection start];
    isLoadingNews = YES;
    
    [[SFVUtil sharedSFVUtil] startNetworkAction];       
}

#pragma mark - table view setup

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [jsonArticles count];
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *article = [jsonArticles objectAtIndex:indexPath.row];
    
    if( [article valueForKeyPath:@"image.url"] )
        [[SFVUtil sharedSFVUtil] loadImageFromURL:[article valueForKeyPath:@"image.url"]
                                            cache:YES
                                     maxDimension:175
                                    completeBlock:^(UIImage *img, BOOL wasLoadedFromCache) {
                                        if( ![self isViewLoaded] )
                                            return;
                                        
                                        if( !wasLoadedFromCache )
                                            [tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:indexPath]
                                                             withRowAnimation:UITableViewRowAnimationFade];
                                    }];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NewsTableViewCell *cell = [NewsTableViewCell cellForTableView:tableView];
    
    cell.recordNewsViewController = self;
    cell.tag = indexPath.row;
    
    [cell setCellWidth:(tableView.frame.size.width - 35.0f)];
    
    NSDictionary *article = [jsonArticles objectAtIndex:indexPath.row];
    [cell setArticle:article];
    [cell setArticleImage:nil];
    
    // If we have cached an image for this article, set it here
    if( [article valueForKeyPath:@"image.url"] )
        [cell setArticleImage:[[SFVUtil sharedSFVUtil] userPhotoFromCache:[article valueForKeyPath:@"image.url"]]];

    [cell layoutCell];    
        
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
    NSString *articleURL = [[jsonArticles objectAtIndex:indexPath.row] objectForKey:@"unescapedUrl"];
        
    [self.detailViewController tearOffFlyingWindowsStartingWith:self inclusive:NO];
    [self.detailViewController addFlyingWindow:FlyingWindowWebView withArg:articleURL];
}

- (CGFloat) tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {    
    float curY = 10, availableWidth = tableView.frame.size.width - 45;
    
    NSDictionary *article = [jsonArticles objectAtIndex:indexPath.row];
    UIImage *img = nil;
    NSString *bits = nil;
    CGSize s, imgSize, maxSize = [self maxImageSize];
    
    // headline
    bits = [article objectForKey:@"titleNoFormatting"];
    s = [bits sizeWithFont:[UIFont fontWithName:@"HelveticaNeue-Bold" size:22]
         constrainedToSize:CGSizeMake( availableWidth, 50 )
             lineBreakMode:UILineBreakModeWordWrap];
    
    curY += s.height + 5;
    
    // article source
    curY += 20;
    
    // article image
    if( [article objectForKey:@"image"] )
        img = [[SFVUtil sharedSFVUtil] userPhotoFromCache:[article valueForKeyPath:@"image.url"]];
    
    if( img ) {
        imgSize = img.size;
        
        if( imgSize.width > maxSize.width ) {
            double d = maxSize.width / imgSize.width;
            
            imgSize.width = maxSize.width;
            imgSize.height *= d;
        }
        
        if( imgSize.height > maxSize.height ) {
            double d = maxSize.height / imgSize.height;
            
            imgSize.height = maxSize.height;
            imgSize.width *= d;
        }
        
        availableWidth -= imgSize.width + 15;
    }
    
    // article content
    bits = [article objectForKey:@"content"];
    bits = [SFVUtil stripHTMLTags:bits];
    bits = [SFVUtil stringByDecodingEntities:bits];
    s = [bits sizeWithFont:[UIFont fontWithName:@"HelveticaNeue" size:14]
         constrainedToSize:CGSizeMake( availableWidth, 80 )
             lineBreakMode:UILineBreakModeWordWrap];
    
    curY += s.height + 10;  
    
    if( img && curY < 115 + imgSize.height )
        curY = imgSize.height + 115;
        
    return lroundf(curY);
}

- (void) scrollViewDidScroll:(UIScrollView *)scrollView {
    [self.newsTableViewController scrollViewDidScroll:scrollView];
    [self flyingWindowDidTap:nil];
    
    if ( !isLoadingNews && ([scrollView contentOffset].y + scrollView.frame.size.height) >= [scrollView contentSize].height )    
        [self refresh:NO];
}

- (void) scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.newsTableViewController scrollViewWillBeginDragging:scrollView];
}

- (void) scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate {
    [self.newsTableViewController scrollViewDidEndDragging:scrollView willDecelerate:decelerate];
}

@end