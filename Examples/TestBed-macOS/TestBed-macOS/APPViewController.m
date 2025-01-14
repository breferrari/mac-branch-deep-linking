//
//  APPViewController.m
//  TestBed-Mac
//
//  Created by Edward Smith on 5/15/18.
//  Copyright © 2018 Edward Smith. All rights reserved.
//

#import "APPViewController.h"
#import "APPActionItemView.h"
#import <Branch/Branch.h>
#import "Branch/BNCApplication.h"
#import "Branch/BranchMainClass+Private.h"

@interface NSTextView (TestBedMac)
@property (atomic, copy) NSAttributedString *placeholderAttributedString;
@end

#pragma mark APPViewController

@interface APPViewController () <NSCollectionViewDelegate, NSCollectionViewDataSource>
@property (weak) IBOutlet NSCollectionView *actionItemCollection;
@property (strong) NSArray<NSDictionary*> *actionItems;
@property (strong) IBOutlet NSWindow *v2EventsSelectionWindow;
@property (strong) IBOutlet NSComboBox *v2EventsComboBox;

@end

#pragma mark - APPViewController

@implementation APPViewController

+ (APPViewController*) loadController {
    APPViewController*controller = [[APPViewController alloc] init];
    BOOL loaded =
        [[NSBundle mainBundle]
            loadNibNamed:NSStringFromClass(self)
            owner:controller
            topLevelObjects:nil];
    return (loaded) ? controller : nil;
}

- (NSAttributedString*) attributedString:(NSString*)string {
    return [[NSAttributedString alloc] initWithString:string attributes:@{
        NSForegroundColorAttributeName:  [NSColor lightGrayColor]
    }];
}

- (void) awakeFromNib {
    self.actionItems = @[@{
            @"title":       @"Show Configuration",
            @"detail":      @"Show the current Branch configuration.",
            @"selector":    @"showConfiguration:",
        },@{
            @"title":       @"Set Identity",
            @"detail":      @"Set the current user's identity to a developer friendly value.",
            @"selector":    @"setIdentity:",
        },@{
            @"title":       @"Log User Out",
            @"detail":      @"Log the current user out.",
            @"selector":    @"logUserOut:",
        },@{
            @"title":       @"Send Event",
            @"detail":      @"Select and send a V2 event.",
            @"selector":    @"sendV2Event:",
        },@{
            @"title":       @"Create Short Link",
            @"detail":      @"Create a Branch short link.",
            @"selector":    @"createShortLink:",
        },@{
            @"title":       @"Create Long Link",
            @"detail":      @"Create a Branch long link.",
            @"selector":    @"createLongLink:",
        },@{
            @"title":       @"Open Last Link",
            @"detail":      @"Open the link the was just created.",
            @"selector":    @"openLink:",
        },@{
            @"title":       @"Create QR Code",
            @"detail":      @"Generate a new QR code.",
            @"selector":    @"getQRCode:",
        },
    ];
    NSNib*nib = [[NSNib alloc] initWithNibNamed:@"APPActionItemView" bundle:[NSBundle mainBundle]];
    [self.actionItemCollection registerNib:nib
        forItemWithIdentifier:NSStringFromClass(APPActionItemView.class)];
    self.trackingDisabled.state =
        [Branch sharedInstance].userTrackingIsDisabled ? NSControlStateValueOn : NSControlStateValueOff;
    self.limitFacebookTracking.state =
        [Branch sharedInstance].limitFacebookTracking ? NSControlStateValueOn : NSControlStateValueOff;
    self.requestTextView.placeholderAttributedString = [self attributedString:@"< Server Request >"];
    self.responseTextView.placeholderAttributedString = [self attributedString:@"< Server Response >"];
    self.dataTextView.placeholderAttributedString = [self attributedString:@"< Data >"];
}

- (void) clearUIFields {
    self.stateField.stringValue = @"";
    self.urlField.stringValue = @"";
    self.errorField.stringValue = @"";
    self.dataTextView.string = @"";
    self.requestTextView.string = @"";
    self.responseTextView.string = @"";
}

- (NSString*) errorMessage:(NSError*)error {
    if (error) {
        NSString*a = error.localizedDescription ?: @"";
        NSString*b = error.localizedFailureReason ?: @"";
        return [NSString stringWithFormat:@"%@ %@", a, b];
    }
    return @"< None >";
}

#pragma mark - Action Item Collection

- (NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 1;
}

- (NSInteger)collectionView:(NSCollectionView *)collectionView
     numberOfItemsInSection:(NSInteger)section {
     return self.actionItems.count;
}

- (NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView
    itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    APPActionItemView*view =
        [self.actionItemCollection makeItemWithIdentifier:NSStringFromClass(APPActionItemView.class)
            forIndexPath:indexPath];
    NSDictionary*d = self.actionItems[indexPath.item];
    view.textField.stringValue = d[@"title"];
    view.detailTextField.stringValue = d[@"detail"];
    return view;
}

- (void)collectionView:(NSCollectionView *)collectionView
didSelectItemsAtIndexPaths:(NSSet<NSIndexPath *> *)indexPaths {
    NSIndexPath*indexPath = [indexPaths anyObject];
    if (!indexPath) return;
    NSString*s = self.actionItems[indexPath.item][@"selector"];
    if (!s) return;
    SEL selector = NSSelectorFromString(s);
    [self performSelectorOnMainThread:selector withObject:self waitUntilDone:NO];
    [self.actionItemCollection deselectAll:nil];
}

#pragma mark - Actions

- (IBAction) showConfiguration:(id)sender {
    [self clearUIFields];
    BranchConfiguration*configuration = [Branch sharedInstance].configuration;
    NSString*string =
        [NSString stringWithFormat:@"      Key: %@\n  Server: %@\n Service: %@\nScheme: %@",
            configuration.key,
            configuration.branchAPIServiceURL,
            configuration.networkServiceClass,
            [BNCApplication currentApplication].defaultURLScheme];
    self.dataTextView.string = string;
}

- (IBAction) setIdentity:(id)sender {
    [self clearUIFields];
    [[Branch sharedInstance] setUserIdentity:@"Bob" completion:^ (BranchSession*session, NSError*error) {
        self.stateField.stringValue =
            [NSString stringWithFormat:@"Set Identity: '%@'", session.userIdentityForDeveloper];
        self.errorField.stringValue = [self errorMessage:error];
    }];
}

- (IBAction) logUserOut:(id)sender {
    BNCLogMethodName();
    [self clearUIFields];
    [[Branch sharedInstance] logoutWithCompletion:^ (NSError*error) {
        self.stateField.stringValue = @"Log User Out";
        self.errorField.stringValue = [self errorMessage:error];
    }];
}

- (IBAction) sendPurchaseEvent:(id)sender {
    // Set up the Branch Universal Object --
    BranchUniversalObject *buo = [BranchUniversalObject new];
    buo.canonicalIdentifier = @"item/12345";
    buo.canonicalUrl        = @"https://branch.io/deepviews";
    buo.title               = @"My Content Title";
    buo.contentDescription  = @"my_product_description1";
    buo.imageUrl            = @"https://test_img_url";
    buo.keywords            = @[ @"My_Keyword1", @"My_Keyword2"];
    buo.creationDate        = [NSDate dateWithTimeIntervalSince1970:1501869445321.0/1000.0];
    buo.expirationDate      = [NSDate dateWithTimeIntervalSince1970:212123232544.0/1000.0];
    buo.locallyIndex        = YES;
    buo.publiclyIndex       = NO;

    buo.contentMetadata.contentSchema    = BranchContentSchemaCommerceProduct;
    buo.contentMetadata.quantity         = 2;
    buo.contentMetadata.price            = [NSDecimalNumber decimalNumberWithString:@"23.2"];
    buo.contentMetadata.currency         = BNCCurrencyUSD;
    buo.contentMetadata.sku              = @"1994320302";
    buo.contentMetadata.productName      = @"my_product_name1";
    buo.contentMetadata.productBrand     = @"my_prod_Brand1";
    buo.contentMetadata.productCategory  = BNCProductCategoryBabyToddler;
    buo.contentMetadata.productVariant   = @"3T";
    buo.contentMetadata.condition        = BranchConditionFair;

    buo.contentMetadata.ratingAverage    = 5;
    buo.contentMetadata.ratingCount      = 5;
    buo.contentMetadata.ratingMax        = 7;
    buo.contentMetadata.rating           = 6;
    buo.contentMetadata.addressStreet    = @"Street_name1";
    buo.contentMetadata.addressCity      = @"city1";
    buo.contentMetadata.addressRegion    = @"Region1";
    buo.contentMetadata.addressCountry   = @"Country1";
    buo.contentMetadata.addressPostalCode= @"postal_code";
    buo.contentMetadata.latitude         = 12.07;
    buo.contentMetadata.longitude        = -97.5;
    buo.contentMetadata.imageCaptions    = (id) @[@"my_img_caption1", @"my_img_caption_2"];
    buo.contentMetadata.customMetadata   = (NSMutableDictionary*) @{
        @"Custom_Content_metadata_key1": @"Custom_Content_metadata_val1",
        @"Custom_Content_metadata_key2": @"Custom_Content_metadata_val2"
    };

    // Set up the event properties --
    BranchEvent *event    = [BranchEvent standardEvent:BranchStandardEventPurchase];
    event.transactionID   = @"12344555";
    event.currency        = BNCCurrencyUSD;
    event.revenue         = [NSDecimalNumber decimalNumberWithString:@"1.5"];
    event.shipping        = [NSDecimalNumber decimalNumberWithString:@"10.2"];
    event.tax             = [NSDecimalNumber decimalNumberWithString:@"12.3"];
    event.coupon          = @"test_coupon";
    event.affiliation     = @"test_affiliation";
    event.eventDescription= @"Event _description";
    event.searchQuery     = @"Query";
    event.customData      = (NSMutableDictionary*) @{
        @"Custom_Event_Property_Key1": @"Custom_Event_Property_val1",
        @"Custom_Event_Property_Key2": @"Custom_Event_Property_val2"
    };
    event.contentItems = (NSMutableArray*) @[ buo ];
    [self clearUIFields];
    [[Branch sharedInstance] logEvent:event completion:^(NSError * _Nullable error) {
        self.stateField.stringValue = event.eventName;
        self.errorField.stringValue = (error) ? error.localizedDescription : @"< None >";
    }];
}

- (NSArray *) v2Events
{
    NSMutableArray *eventNames = [NSMutableArray arrayWithArray:[BranchEvent standardEvents]];
    [eventNames addObject:@"Custom Event"];
    
    return  eventNames;
}

- (IBAction) sendV2Event:(id)sender {
    
    if (!self.v2EventsSelectionWindow){
        [NSBundle.mainBundle loadNibNamed:@"APPV2EventSelectionWindow" owner:self topLevelObjects:NULL];
        [self.v2EventsComboBox addItemsWithObjectValues:[self v2Events]];
    }
    
    [[NSApp mainWindow] beginSheet:self.v2EventsSelectionWindow completionHandler:^(NSModalResponse returnCode) {
        [self sendV2EventWithName:self.v2EventsComboBox.stringValue ];
    }];
}
- (void)sendV2EventWithName:(NSString *)eventName {

    // standard events with data requirements
    if ([eventName isEqualToString:BranchStandardEventInvite]) {
        [self sendInviteEvent];
    } else if ([eventName isEqualToString:BranchStandardEventLogin]) {
        [self sendLoginEvent];
    } else if ([eventName isEqualToString:BranchStandardEventSubscribe]) {
        [self sendSubscribeEvent];
    } else if ([eventName isEqualToString:BranchStandardEventStartTrial]) {
        [self sendStartTrialEvent];
    } else if ([eventName isEqualToString:BranchStandardEventClickAd]) {
        [self sendClickAdEvent];
    } else if ([eventName isEqualToString:BranchStandardEventViewAd]) {
        [self sendViewAdEvent];
    } else if ([eventName isEqualToString:BranchStandardEventPurchase]) {
        [self sendPurchaseEvent:nil];
    } else if ([[BranchEvent standardEvents] containsObject:eventName]) {     // other standard events
        [self sendStandardV2Event:eventName];
    } else {  // custom events
        [self sendCustomV2Event:eventName];
    }
}

- (void)sendInviteEvent {
    BranchEvent *event = [BranchEvent standardEvent:BranchStandardEventInvite];
    [self logEvent:event];
}

- (void)sendLoginEvent {
    BranchEvent *event = [BranchEvent standardEvent:BranchStandardEventLogin];
    [self logEvent:event];
}

- (void)sendSubscribeEvent {
    BranchEvent *event = [BranchEvent standardEvent:BranchStandardEventSubscribe];
    event.currency = BNCCurrencyUSD;
    event.revenue = [NSDecimalNumber decimalNumberWithString:@"1.0"];
    [self logEvent:event];
}

- (void)sendStartTrialEvent {
    BranchEvent *event = [BranchEvent standardEvent:BranchStandardEventStartTrial];
    event.currency = BNCCurrencyUSD;
    event.revenue = [NSDecimalNumber decimalNumberWithString:@"1.0"];
    [self logEvent:event];
}

- (void)sendClickAdEvent {
    BranchEvent *event = [BranchEvent standardEvent:BranchStandardEventClickAd];
    event.adType = BranchEventAdTypeBanner;
    [self logEvent:event];
}

- (void)sendViewAdEvent {
    BranchEvent *event = [BranchEvent standardEvent:BranchStandardEventClickAd];
    event.adType = BranchEventAdTypeBanner;
    [self logEvent:event];
}

- (void)sendStandardV2Event:(BranchStandardEvent)event {
    [self sendGenericV2EventWithName:event isStandardEvent:YES];
}

- (void)sendCustomV2Event:(NSString *)eventName {
    [self sendGenericV2EventWithName:eventName isStandardEvent:NO];
}

- (void) sendGenericV2EventWithName:(NSString*)eventName isStandardEvent:(BOOL)isStandardEvent {
    BranchUniversalObject *buo = [BranchUniversalObject new];

    buo.contentMetadata.contentSchema    = BranchContentSchemaCommerceProduct;
    buo.contentMetadata.quantity         = 2;
    buo.contentMetadata.price            = [NSDecimalNumber decimalNumberWithString:@"23.20"];
    buo.contentMetadata.currency         = BNCCurrencyUSD;
    buo.contentMetadata.sku              = @"1994320302";
    buo.contentMetadata.productName      = @"my_product_name1";
    buo.contentMetadata.productBrand     = @"my_prod_Brand1";
    buo.contentMetadata.productCategory  = BNCProductCategoryBabyToddler;
    buo.contentMetadata.productVariant   = @"3T";
    buo.contentMetadata.condition        = BranchConditionFair;

    buo.contentMetadata.ratingAverage    = 5;
    buo.contentMetadata.ratingCount      = 5;
    buo.contentMetadata.ratingMax        = 7;
    buo.contentMetadata.rating           = 6;
    buo.contentMetadata.addressStreet    = @"Street_name1";
    buo.contentMetadata.addressCity      = @"city1";
    buo.contentMetadata.addressRegion    = @"Region1";
    buo.contentMetadata.addressCountry   = @"Country1";
    buo.contentMetadata.addressPostalCode= @"postal_code";
    buo.contentMetadata.latitude         = 12.07;
    buo.contentMetadata.longitude        = -97.5;
    buo.contentMetadata.imageCaptions    = (id) @[@"my_img_caption1", @"my_img_caption_2"];
    buo.contentMetadata.customMetadata   = (id) @{
        @"Custom_Content_metadata_key1": @"Custom_Content_metadata_val1",
        @"Custom_Content_metadata_key2": @"Custom_Content_metadata_val2",
        @"~campaign": @"My campaign"
    };
    buo.title                       = @"My Title";
    buo.canonicalIdentifier         = @"item/12345";
    buo.canonicalUrl                = @"https://branch.io/deepviews";
    buo.keywords                    = @[@"My_Keyword1", @"My_Keyword2"];
    buo.contentDescription          = @"my_product_description1";
    buo.imageUrl                    = @"https://test_img_url";
    buo.expirationDate              = [NSDate dateWithTimeIntervalSinceNow:24*60*60];
    buo.publiclyIndex               = NO;
    buo.locallyIndex                = YES;
    buo.creationDate                = [NSDate date];

    BranchEvent *event;
    if (isStandardEvent) {
        event = [BranchEvent standardEvent:eventName];
    } else {
        event = [BranchEvent customEventWithName:eventName];
    }
    event.transactionID   = @"12344555";
    event.currency        = BNCCurrencyUSD;
    event.revenue         = [NSDecimalNumber decimalNumberWithString:@"1.5"];
    event.shipping        = [NSDecimalNumber decimalNumberWithString:@"10.2"];
    event.tax             = [NSDecimalNumber decimalNumberWithString:@"12.3"];
    event.coupon          = @"test_coupon";
    event.affiliation     = @"test_affiliation";
    event.eventDescription= @"Event _description";
    event.customData      = (NSMutableDictionary*) @{
        @"Custom_Event_Property_Key1": @"Custom_Event_Property_val1",
        @"Custom_Event_Property_Key2": @"Custom_Event_Property_val2"
    };
    event.contentItems = (id) @[ buo ];
    //ND event.alias = @"event alias";
    
    [self logEvent:event];
}

-(void)logEvent:(BranchEvent *)event{
    [[Branch sharedInstance] logEvent:event completion:^(NSError * _Nullable error) {
        self.stateField.stringValue = event.eventName;
        self.errorField.stringValue = (error) ? error.localizedDescription : @"< None >";
    }];
}

- (IBAction)closev2EventsSelectionWindow:(id)sender {
    [self.window endSheet:self.v2EventsSelectionWindow ];
}

- (BranchUniversalObject*) createUniversalObject {
    NSString *canonicalIdentifier = @"item/12345";
    NSString *canonicalUrl = @"https://dev.branch.io/getting-started/deep-link-routing/guide/ios/";
    NSString *contentTitle = @"Content Title";
    NSString *contentDescription = @"My Content Description";
    NSString *imageUrl =
        @"http://a57.foxnews.com/images.foxnews.com/content/fox-news/science/2018/03/20/"
         "first-day-spring-arrives-5-things-to-know-about-vernal-equinox/_jcr_content/"
         "par/featured_image/media-0.img.jpg/1862/1048/1521552912093.jpg?ve=1&tl=1";

    BranchUniversalObject *buo =
        [[BranchUniversalObject alloc] initWithCanonicalIdentifier:canonicalIdentifier];
    buo.canonicalUrl = canonicalUrl;
    buo.title = contentTitle;
    buo.contentDescription = contentDescription;
    buo.imageUrl = imageUrl;
    buo.contentMetadata.price = [NSDecimalNumber decimalNumberWithString:@"1000.00"];
    buo.contentMetadata.currency = @"$";
    buo.contentMetadata.contentSchema = BranchContentSchemaTextArticle;
    buo.contentMetadata.customMetadata[@"deeplink_text"] =
        [NSString stringWithFormat:
            @"This text was embedded as data in a Branch link with the following characteristics:\n\n"
             "canonicalUrl: %@\n  title: %@\n  contentDescription: %@\n  imageUrl: %@\n",
                canonicalUrl, contentTitle, contentDescription, imageUrl];
    return buo;
}

- (BranchLinkProperties*) createLinkProperties {
    NSString *feature = @"Sharing Feature";
    NSString *channel = @"Distribution Channel";
    NSString *desktop_url = @"http://branch.io";
//    NSString *ios_url = @"https://dev.branch.io/getting-started/sdk-integration-guide/guide/ios/";

    BranchLinkProperties *linkProperties = [[BranchLinkProperties alloc] init];
    linkProperties.tags = @[ @"tag1", @"tag2" ];
    linkProperties.feature = feature;
    linkProperties.channel = channel;
    linkProperties.stage = @"stage four";
    linkProperties.campaign = @"some campaign";
    linkProperties.matchDuration = 18000;
    
    linkProperties.controlParams[@"$desktop_url"] = desktop_url;
    
    // TODO: Control params:
//    [linkProperties addControlParam:@"$desktop_url" withValue: desktop_url];
//    [linkProperties addControlParam:@"$ios_url" withValue: ios_url];
    return linkProperties;
}

static NSURL*lastCreatedLink = nil;

- (IBAction) createShortLink:(id)sender {
    [self clearUIFields];
    BranchLinkProperties *linkProperties = [self createLinkProperties];
    BranchUniversalObject *buo = [self createUniversalObject];
    buo.creationDate = [NSDate date];
    [[Branch sharedInstance]
        branchShortLinkWithContent:buo
        linkProperties:linkProperties
        completion:^(NSURL * _Nullable shortURL, NSError * _Nullable error) {
            self.errorField.stringValue = [self errorMessage:error];
            self.dataTextView.string = shortURL.absoluteString ?: @"";
            lastCreatedLink = shortURL;
        }];
}

- (IBAction) createLongLink:(id)sender {
    [self clearUIFields];
    BranchLinkProperties *linkProperties = [self createLinkProperties];
    BranchUniversalObject *buo = [self createUniversalObject];
    buo.creationDate = [NSDate date];
    NSURL*url = [[Branch sharedInstance] branchLongLinkWithContent:buo linkProperties:linkProperties];
    self.errorField.stringValue = [self errorMessage:nil];
    self.dataTextView.string = url.absoluteString;
    lastCreatedLink = url;
}

- (IBAction) openLink:(id)sender {
    [[Branch sharedInstance] openURL:lastCreatedLink];
}

- (IBAction) getQRCode:(id)sender {
    BranchLinkProperties *linkProperties = [self createLinkProperties];
    BranchUniversalObject *buo = [self createUniversalObject];
    BranchQRCode *qrCode = [BranchQRCode new];
    qrCode.codeColor = NSColor.blueColor;
    qrCode.width = @300;
    
    [qrCode getQRCodeAsImage:buo linkProperties:linkProperties completion:^(CIImage * _Nullable qrCodeImage, NSError * _Nullable error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.errorField.stringValue = [self errorMessage:error];
            self.dataTextView.string = @"";
            
            NSCIImageRep *rep = [NSCIImageRep imageRepWithCIImage:qrCodeImage];
            NSImage *nsImage = [[NSImage alloc] initWithSize:rep.size];
            [nsImage addRepresentation:rep];
        
            NSTextAttachment *attachment = [NSTextAttachment new];
            attachment.image = nsImage;
            NSAttributedString *imageString = [NSAttributedString attributedStringWithAttachment:attachment];
            [self.dataTextView.textStorage insertAttributedString:imageString atIndex:0];
 
        });
    }];
}

- (IBAction)trackingDisabledAction:(id)sender {
    [Branch sharedInstance].userTrackingDisabled = (self.trackingDisabled.state == NSControlStateValueOn);
}

- (IBAction)limitFacebookTrackingAction:(id)sender {
    [Branch sharedInstance].limitFacebookTracking = (self.limitFacebookTracking.state == NSControlStateValueOn);
}

@end
