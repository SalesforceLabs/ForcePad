# ForcePad #

ForcePad is a free, unofficial, unsupported, open-source native iPad app from Salesforce Labs. It's the easiest way to browse your apps, tabs, and records in any Salesforce environment. Create, edit, clone, and delete standard and custom records. Supports every page layout, every field, every related list, every Group Edition thru Unlimited Edition org. With ForcePad, you're an unstoppable force for the cloud! 

[![ForcePad is on the App Store!](http://github.com/ForceDotComLabs/ForcePad/raw/master/appstore.png)](http://itunes.apple.com/us/app/forcepad-by-salesforce-labs/id458454196?ls=1&mt=8) &nbsp;&nbsp;&nbsp;&nbsp; [![ForcePad is on the Salesforce Appexchange!](http://github.com/ForceDotComLabs/ForcePad/raw/master/appexchange.png)](http://appexchange.salesforce.com/listingDetail?listingId=a0N300000055lKrEAI)

by Jonathan Hersh ([Email](mailto:jon@her.sh), [GitHub](https://github.com/jhersh), [Twitter](https://twitter.com/jhersh)) with special thanks to Wiebke and Brian in Salesforce UX, Ciara for graphic design and UX, plus Darrell, Eugene, Clarence, Reid, Mike, Simon, Todd, and Kevin.

*Author's Note:* Account Viewer (which became Salesforce Viewer, which became Salesforce for iPad, which became ForcePad) was my first iOS app, developed over more than a year, so files can show significant variation in quality, conciseness, structure, taste, texture, color, and aroma. The app has also been known to take you out to a nice sushi dinner and then not call you the next day. - JH

In this document:

- *Release History*
- *ForcePad License*
- *Getting Started*
- *Authentication, APIs, and Security*
- *App Architecture*
- *External APIs*
- *App Components*
- *Areas for Improvement*

## Release History ##

ForcePad was originally released as 'Account Viewer' in August 2011. Account Viewer is [available on GitHub](https://github.com/ForceDotComLabs/Account-Viewer). In November 2011, Account Viewer was updated and re-released as 'Salesforce Viewer'. In February 2012, I updated it again to Salesforce for iPad. In August 2012 it became ForcePad.

v2.4.1, 2.4.2, 2.4.3 - Released 10/6/2012

- Fixes a crash with date/datetime fields. Third time's a charm? 
- Fixes some rendering issues under iOS 6 

v2.4 - Released 9/5/2012

- Salesforce for iPad is now ForcePad!
- New Save behavior: maintains your window stack after you create or update a record
- New support for Report and Dashboard in-app listviews
- Now displays any errors that occur during login (e.g. if you login with a user who has API disabled)
- Better support for displaying records that do not have record layouts (opens in webview)
- Fixes for rendering dependent picklist values 
- Fixes for displaying currency values in multicurrency orgs
- Fixes for activity related lists on Contact and Lead records
- Fixes for the partner related list
- Other misc. fixes

v2.3 - Released 4/5/2012

- Now requires iOS 5. 
- Retina-fied for the new iPad 
- Many UI updates, bug fixes

v2.2.3 - Released 3/13/2012

- Added an escape hatch to the login screen
- Fix a crasher when tapping into an empty date or datetime field

v2.2.2 - Released 3/6/2012

- Save Salesforce Contacts/Leads to your Address Book
- Save Address Book entries to Salesforce Contacts/Leads
- Save Salesforce Events to your Calendar
- Create Case Comments
- Support for combobox fields
- Bug fixes, UI improvements

v2.2.1 - Released 2/20/2012

- Bug fixes

v2.2 - Released 2/15/2012

- Initial release of Salesforce for iPad
- Create, edit, clone, delete records for (almost all) standard and (all) custom objects
- Bug fixes, UI updates

## ForcePad License ##

Copyright (c) 2012, salesforce.com, inc.
All rights reserved.

Redistribution and use in source and binary forms, with or without modification, are permitted provided 
that the following conditions are met:
 
- Redistributions of source code must retain the above copyright notice, this list of conditions and the following disclaimer.
- Redistributions in binary form must reproduce the above copyright notice, this list of conditions and the following disclaimer in the documentation and/or other materials provided with the distribution. 
- Neither the name of salesforce.com, inc. nor the names of its contributors may be used to endorse or promote products derived from this software without specific prior written permission.
 
THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

## Getting Started ##

1. Grab the ForcePad source code: `git clone https://github.com/ForceDotComLabs/Salesforce-for-iPad.git`
2. ForcePad connects to Salesforce securely with OAuth. If you don't have an OAuth client ID, create a new Remote Access application (Setup -> Develop -> Remote Access). Use the OAuth success endpoint for your callback URL: e.g. `https://login.salesforce.com/services/oauth2/success` for production. Copy your OAuth Client ID into the `OAuthClientID` variable in `OAuthViewController.h`.
3. (Optional) ForcePad connects to environments that are not otherwise API-enabled, like GE and PE orgs, by using a partner token. If you have a Salesforce partner token, paste it into `RootViewController.h` under `PartnerTokenId`.
4. (Optional) If you have a Google API key, paste it into `RecordNewsViewController.h` under `NEWS_API_KEY`.
5. Build and run, and you should be good to go!
6. If you're getting build warnings/errors akin to "Multiple build commands for output file...", you'll need to remove the .git directory from your project. See [this answer](http://stackoverflow.com/questions/2718246/xcode-strange-warning-multiple-build-commands-for-output-file) for more detail.

## Authentication, APIs, and Security ##

ForcePad authenticates to Salesforce with OAuth. The app encrypts your OAuth refresh token in the device's keychain. The app never has access to your username or password. 

After authentication, ForcePad's API calls are about 30% to the [SOAP (Web Services) API](http://www.salesforce.com/us/developer/docs/api/index.htm) and 70% to the [REST](http://www.salesforce.com/us/developer/docs/api_rest/index.htm) APIs. REST is the future for mobile and I'm trying to move as much as possible away from SOAP.

SOAP is used for:

- OAuth
- Page layout describes (Unavailable in REST)
- Describing apps and tabs (Unavailable in REST)
- Retrieving multiple records in a single retrieve call (Unavailable in REST)
- SOQL where querymore is expected (Available in REST, but the Mobile SDK does not yet implement querymore)

REST is used for:

- Retrieving single records
- Create, update, and delete
- Describing global and individual objects
- SOSL
- Non-querymore SOQL

Remote records are never saved locally. Page layouts, sObject describes, and other metadata are cached in-memory and cleared at every logout and refresh.

Some record data (names and addresses) are sent to third-party APIs to provide app functionality, but always over HTTPS. More details below in the External API section.

App preferences (first-run settings, preferences) are stored in `NSUserDefaults`.

## App Architecture ##

When ForcePad first loads, it evaluates whether it has a stored OAuth refresh token from a previous authentication. If so, it attempts to refresh its session with that refresh token. See `appFinishedLaunching` in `RootViewController.m`. If there is no stored refresh token, or if the refresh fails for any reason, the app destroys all session data and shows the OAuth login screen.

The left-side navigation view (in landscape mode, also visible in portrait mode in a popover when you tap the browse button), a.k.a. the Master view, is powered by the `RootViewController` and `SubNavViewController` classes. `RootViewController` handles most of Login/Logout, while `SubNavViewController` powers record browsing, searching, object lists, and displaying favorite objects.

The right-side view is powered by the `DetailViewController`. It serves as a container for the rest of the app's content and is responsible for creating, managing, and destroying Flying Windows and the Flying Window stack. It manages dragging operations on Flying Windows.

The interactive, draggable panes that fill the `DetailViewController` are termed Flying Windows and each is a subclass of the `FlyingWindowController` class. The `FlyingWindowController` base class defines some basics about their look and enables them to be dragged about the screen. 

Behold ye the Flying Windows:

- `RecordOverviewController` is responsible for displaying a record overview, page layout, and rendering the record's location on a map.

- `ListOfRelatedListsViewController` lists all of the related lists on a record. The list ordering as well as which lists appear is determined by your record page layout. This view controller also chains subqueries together to load the number of related records on each list.

- `RecordNewsViewController` is responsible for querying Google News (over HTTPS) and displaying news stories about a single Account. Only available for Account records.

- `WebViewController` is a simple `UIWebView` wrapper with a few added pieces of functionality, like being able to email the link to the open page, copy its URL, open in Safari, and tweet a link.

- `RelatedListGridView` displays a related list for a given record. The columns displayed on the related list grid are determined by the record's page layout. Related record grids have tap-to-sort columns and tapping an individual record's name will open its full detail.

- `RecordEditor` handles creating, editing, cloning, and deleting records, as well as filling values from the local Address Book when editing Contacts and Leads.

- `RecentRecordsController` is the default 'home' flying window, displaying a list of recent records accessed in ForcePad. It allows sorting by record type and removing recent records from the list.

### Modal Windows

`AboutAppViewController`, `SFVEULAAcceptController`, and `SFVFirstRunController` are part of the first-run experience and also power the help pages accessed via the settings window.

`ChatterPostController` is the main interface for posting an article or URL to chatter.

`CloudyLoadingModal` probably doesn't do anything important. Look behind you!

`OAuthCustomHostCreator`, `OAuthLoginHostPicker`, and `OAuthViewController` microwave popcorn. Actually, they microwave burritos. Nah, just kidding, they're the brothers who run that corner convenience store.

`ObjectLookupController` is a lookup box launched when you tap the 'Post To' field in the `ChatterPostController`. It also handles lookup fields on record editing layouts. It can search via SOQL and SOSL for (almost) any standard or custom object.

`PicklistPicker` is a popover tableview for selecting from a picklist, multiselect, or combobox. It also handles picking from lists of record types, for use when editing a record.

### Miscellaneous Views

`FieldPopoverButton` is a generic `UIButton` intended to display the value of an sObject field. All `FieldPopoverButton`s can be tapped to copy the text value of that field, and depending on the field type, some may have additional actions. For example, a `FieldPopoverButton` displaying an address will offer to open the address in Google Maps, phone/email fields will offer to call with Facetime or Skype, and lookups to User will display a full-featured user profile with a photo and other details from the User record.

`FollowButton` is a generic `UIBarButtonItem` intended to make it easy to create a follow/unfollow toggle between the running user and any other chatter-enabled object (User, Account, etc). 

`QCContactMenu` is a subclass of the super-nifty QuadCurveMenu component intended to make it easy to Email, Skype, Facetime, or open the website for any record. If a page layout has three fields of type Phone, for example, a `QCContactMenu`, when tapped, will allow you to choose Skype, then place a Skype call to any of those three phone numbers.

### Caching

The app has a caching layer to hold metadata in-memory, allowing the app to read metadata from cache instead of re-querying the server. This is mostly contained in `SFVAppCache` except for page layouts, which are cached in `SFVUtil`.

### Network Operations

Network operations use the block methods in `SFVAsync` (for SOAP) and the Mobile SDK's `SFRestAPI` blocks (for REST). `SFVUtil` contains the app's image loading block method and cache. I added additional REST API blocks under `SFRestAPI+SFVAdditions`, mostly for the purpose of intercepting object describes and, if cached, immediately returning the cached value.

### Security

`SFCrypto` encrypts and decrypts OAuth session tokens for the device's keychain.

`SimpleKeychain` is a utility class for reading from and writing to the device's keychain.

## External APIs ##

- [Google's Geocoding API](http://code.google.com/apis/maps/documentation/geocoding/) allows ForcePad to convert an record street address into a latitude/longitude coordinate pair for display on a map. 
- [Google's News Search API](http://code.google.com/apis/newssearch/) provides news articles, images, bylines, and article summaries. Google deprecated this API on May 26, 2011, but it will remain operational for at least 2.5-3 years after that date. At some point, ForcePad will need to transition to a different news API.

ForcePad communicates with these APIs over HTTPS.

## App Components ##

ForcePad uses Salesforce components:

- The [Force.com Mobile SDK for iOS](https://github.com/forcedotcom/SalesforceMobileSDK-iOS)
- [zksForce](https://github.com/superfell/zkSforce), a Cocoa library for calling the Salesforce Web Services APIs.

And a number of third-party components:

- Various components from Matt Drance's excellent [iOS Recipes book](http://pragprog.com/book/cdirec/ios-recipes).
- [DSActivityView](http://www.dejal.com/developer/dsactivityview) for loading and authentication indicators.
- [MGSplitViewController](http://mattgemmell.com/2010/07/31/mgsplitviewcontroller-for-ipad), a modified split view that powers the app's main interface.
- [InAppSettingsKit](http://inappsettingskit.com/) for in-app and Settings.app settings.
- [SynthesizeSingleton](http://cocoawithlove.com/2008/11/singletons-appdelegates-and-top-level.html)
- [AQGridView](https://github.com/AlanQuatermain/AQGridView), a grid layout system used in the Account record overview.
- [PullRefreshTableViewController](https://github.com/leah/PullToRefresh)
- [QuadCurveMenu](https://github.com/levey/QuadCurveMenu)

## Areas for Improvement ##

Much is there to do on ForcePad. Some unsolved problems:

- *The Metadata Problem(tm)*. That is, suppose you're editing a record and your admin adds a new required field to that object, or deletes a field, or maybe removes a recordtype, or, heck, deletes the whole object. Maybe the admin switched your profile. Staying in metadata-sync with the server is always a tradeoff with caching. ForcePad currently lands heavily on the side of caching, describing most objects and layouts just once when encountered and never again until next login/refresh.
- *Standard Objects* deserve special handling. Lists of contacts and leads in the should be sorted by last name. Standard objects need additional customized listviews, like My Upcoming Events, My Open Tasks, My Opportunities Closing This Month. How flexible and declaractive can we make in-app list views given we don't have access to standard list views?
- I find the landscape experience to be far superior to portrait. In portrait, navigating down enough levels of windows will keep reassigning your browse button, and you'll have to drag all the way back to the top to access it. In landscape the master navigation and record list is always visible. In short, the app needs a big navigational redesign that works equally well in portrait and landscape.
- Session refresh. This is tricky because SFiPad uses both SOAP and REST, either one of which could expire at any time. When the session refreshes for one, it needs to be updated in the other. See [this issue](https://github.com/ForceDotComLabs/ForcePad/issues/2).

Some other things to do:

- *OpportunityLineItems* and *QuoteLineItems* need special handling (price books, products) and are not available to create or edit in the app today.
- ForcePad doesn't support creating or editing objects that do not have page layouts (e.g. contact roles, account teams, etc) with the exception of Case Comments, for which I added a special hack to support. Nor does the app support viewing objects without page layouts, except in related lists.
- Object list views have an API, but the API requires sysadmin (MAD/VAD). Not workable for normal users.
- Chatter feeds are a popular request. The iOS Chatter team aims to release some reusable components later this year.
- The Account News feature uses Google's News API, which Google deprecated in May 2011. ForcePad will eventually need a replacement news source or I'll have to remove the feature.
- Offline access is a feature that adds convenience at the cost of added complexity (secure storage, record sync, delayed upserts) and security considerations (it allows downloading mass amounts of data)
- PIN lock
- Editing rich text fields
- Displaying images in formula fields
- Displaying in-line Visualforce pages on record page layouts
- Document viewing for Attachments, Content, chatter feed posts, static resources(?)
