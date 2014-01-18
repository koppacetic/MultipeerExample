//
//  ViewController.m
//  MultipeerExample
//
//  Created by Skip Koppenhaver on 1/8/14.
//  Copyright (c) 2014 Skip Koppenhaver. All rights reserved.
//
#import <sys/utsname.h>
#import "ViewController.h"

static NSString * const kServiceType = @"MPExample";

@interface ViewController ()
@property (nonatomic, strong) MCPeerID *myPeerID;
@property (nonatomic, strong) MCSession *session;
@property (nonatomic, strong) MCNearbyServiceAdvertiser *advertiser;
@property (nonatomic, strong) MCNearbyServiceBrowser *browser;

@property (nonatomic, weak) IBOutlet UITableView *myTableView;
@property (nonatomic, weak) IBOutlet UISwitch *browseSwitch;
@property (nonatomic, weak) IBOutlet UISwitch *advertiseSwitch;

@property (nonatomic, assign) BOOL advertising;
@property (nonatomic, assign) BOOL browsing;
@end

@implementation ViewController

#pragma mark - View life cycle

- (void)viewDidLoad {
    [super viewDidLoad];

    // Create myPeerID
    self.myPeerID = [[MCPeerID alloc] initWithDisplayName:[[UIDevice currentDevice] name]];

    [self initializeSession];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(saveState) name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(loadState) name:UIApplicationWillEnterForegroundNotification object:nil];

    self.advertising = YES;
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillResignActiveNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationWillEnterForegroundNotification object:nil];

    [self.advertiser stopAdvertisingPeer];
    NSLog(@"Stopped advertising");
    [self.browser stopBrowsingForPeers];
    NSLog(@"Stopped browsing");
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)saveState {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.advertising) {
        [self.advertiser stopAdvertisingPeer];
        NSLog(@"Stopped advertising");
    }
    if (self.browsing) {
        [self.browser stopBrowsingForPeers];
        NSLog(@"Stopped browsing");
    }
}

- (void)loadState {
    NSLog(@"%s", __PRETTY_FUNCTION__);
    if (self.advertising) {
        [self.advertiser startAdvertisingPeer];
        NSLog(@"Started advertising...");
    }
    if (self.browsing) {
        [self.browser startBrowsingForPeers];
        NSLog(@"Started browsing...");
    }
}

#pragma mark - Custom accessors

- (void)setAdvertising:(BOOL)value {
    if (value) {
        [self.advertiser startAdvertisingPeer];
        NSLog(@"Started advertising...");
    }
    else {
        [self.advertiser stopAdvertisingPeer];
        NSLog(@"Stopped advertising");
    }
    _advertising = value;

    // Update UI on main thread
    if ([NSThread isMainThread]) {
        self.advertiseSwitch.on = value;
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.advertiseSwitch.on = value;
        });
    }
}

- (void)setBrowsing:(BOOL)value {
    if (value) {
        [self.browser startBrowsingForPeers];
        NSLog(@"Started browsing...");
    }
    else {
        [self.browser stopBrowsingForPeers];
        NSLog(@"Stopped browsing");
    }
    _browsing = value;


    // Update UI on main thread
    if ([NSThread isMainThread]) {
        self.browseSwitch.on = value;
    }
    else {
        dispatch_async(dispatch_get_main_queue(), ^{
            self.browseSwitch.on = value;
        });
    }
}

#pragma mark - IBActions

- (IBAction)browseSwitchChanged:(id)sender {
    if (self.browseSwitch.isOn) {
        self.browsing = YES;
    }
    else {
        self.browsing = NO;
    }
}

- (IBAction)advertiseSwitchChanged:(id)sender {
    if (self.advertiseSwitch.isOn) {
        self.advertising = YES;
    }
    else {
        self.advertising = NO;
    }
}

- (IBAction)disconnect:(id)sender {
    NSLog(@"Disconnecting");
    [self.session disconnect];
    self.session = nil;
    [self.myTableView reloadData];
}

- (IBAction)connect:(id)sender {
    if (!self.session) {
        NSLog(@"Connecting");
        [self initializeSession];
        self.advertising = YES;
    }
}

- (IBAction)showPeers:(id)sender {
    for (MCPeerID *peer in [self.session connectedPeers]) {
        NSLog(@"Peer: %@", peer.displayName);
    }
    NSLog(@"%lu peers found", (unsigned long)[[self.session connectedPeers] count]);
}

#pragma mark - MCNearbyServiceBrowserDelegate methods

- (void)browser:(MCNearbyServiceBrowser *)browser foundPeer:(MCPeerID *)peerID withDiscoveryInfo:(NSDictionary *)info {
    NSLog(@"FoundPeer: %@, %@", peerID.displayName, info);

    // Auto-invite any peers that are found
    [self.browser invitePeer:peerID toSession:self.session withContext:nil timeout:5.0];
}

- (void)browser:(MCNearbyServiceBrowser *)browser lostPeer:(MCPeerID *)peerID {
    NSLog(@"LostPeer: %@", peerID.displayName);
}

- (void)browser:(MCNearbyServiceBrowser *)browser didNotStartBrowsingForPeers:(NSError *)error {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
}

#pragma mark - MCNearbyServiceAdvertiserDelegate methods

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didReceiveInvitationFromPeer:(MCPeerID *)peerID withContext:(NSData *)context invitationHandler:(void (^)(BOOL accept, MCSession *session))invitationHandler {
    NSLog(@"Invitation from: %@", peerID.displayName);

    // Auto-accept any invitations received
    invitationHandler(YES, self.session);

    // Stop advertising once we join the session
    self.advertising = NO;
}

- (void)advertiser:(MCNearbyServiceAdvertiser *)advertiser didNotStartAdvertisingPeer:(NSError *)error {
    NSLog(@"%s %@", __PRETTY_FUNCTION__, error);
}

#pragma mark - MCSessionDelegate methods

- (void)session:(MCSession *)session peer:(MCPeerID *)peerID didChangeState:(MCSessionState)state {
    NSLog(@"%@: %@", [self stringForPeerConnectionState:state], peerID.displayName);

    // Update UI on main thread
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.myTableView reloadData];
    });
}

- (void)session:(MCSession *)session didReceiveData:(NSData *)data fromPeer:(MCPeerID *)peerID {
    // Decode the incoming data to a UTF8 encoded string
    NSString *msg = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
    NSLog(@"From %@: %@", peerID.displayName, msg);
}

- (void)session:(MCSession *)session didStartReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID withProgress:(NSProgress *)progress {
    NSLog(@"%s Resource: %@, Peer: %@, Progress %@", __PRETTY_FUNCTION__, resourceName, peerID.displayName, progress);
}

- (void)session:(MCSession *)session didFinishReceivingResourceWithName:(NSString *)resourceName fromPeer:(MCPeerID *)peerID atURL:(NSURL *)localURL withError:(NSError *)error {
    if (error) {
        NSLog(@"%s Peer: %@, Resource: %@, Error: %@", __PRETTY_FUNCTION__, peerID.displayName, resourceName, [error localizedDescription]);
    }
    else {
        NSLog(@"%s Peer: %@, Resource: %@ complete", __PRETTY_FUNCTION__, peerID.displayName, resourceName);
    }
}

- (void)session:(MCSession *)session didReceiveStream:(NSInputStream *)stream withName:(NSString *)streamName fromPeer:(MCPeerID *)peerID {
    NSLog(@"%s Peer: %@, Stream: %@", __PRETTY_FUNCTION__, peerID.displayName, streamName);
}

- (void)session:(MCSession *)session didReceiveCertificate:(NSArray *)cert fromPeer:(MCPeerID *)peerID certificateHandler:(void(^)(BOOL accept))certHandler {
    NSLog(@"%s Peer: %@", __PRETTY_FUNCTION__, peerID.displayName);
    certHandler(YES);
}

#pragma mark - UITableViewDataSource methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [[self.session connectedPeers] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"PlayerCell" forIndexPath:indexPath];

    MCPeerID *peerID = [[self.session connectedPeers] objectAtIndex:indexPath.row];
    cell.textLabel.text = peerID.displayName;

    return cell;
}

#pragma mark - UITableViewDelegate methods

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSData *msgData = [@"Hello there!" dataUsingEncoding:NSUTF8StringEncoding];

    NSError *error;
    MCPeerID *peerID = [[self.session connectedPeers] objectAtIndex:indexPath.row];
    [self.session sendData:msgData toPeers:@[peerID] withMode:MCSessionSendDataUnreliable error:&error];
    if (error)
        NSLog(@"SendData error: %@", error);
    else
        NSLog(@"Sent message");
}

#pragma mark - Helper methods

- (void)initializeSession {
    // Create session
    self.session = [[MCSession alloc] initWithPeer:_myPeerID securityIdentity:nil encryptionPreference:MCEncryptionNone];
    self.session.delegate = self;

    // Determine device model
    struct utsname systemInfo;
    uname(&systemInfo);
    NSString *devType = [NSString stringWithCString:systemInfo.machine encoding:NSUTF8StringEncoding];

    // Create DNS-SD TXT record
    NSDictionary *txtRecord = @{@"txtvers":@"1",
                                @"version":[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleShortVersionString"],
                                @"build":[[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleVersion"],
                                @"devtype":devType,
                                @"devname":[[UIDevice currentDevice] name],
                                @"sysname":[[UIDevice currentDevice] systemName],
                                @"sysvers":[[UIDevice currentDevice] systemVersion]};

    // Setup advertiser
    self.advertiser = [[MCNearbyServiceAdvertiser alloc] initWithPeer:_myPeerID discoveryInfo:txtRecord serviceType:kServiceType];
    self.advertiser.delegate = self;

    // Setup browser
    self.browser = [[MCNearbyServiceBrowser alloc] initWithPeer:_myPeerID serviceType:kServiceType];
    self.browser.delegate = self;
}

- (NSString *)stringForPeerConnectionState:(MCSessionState)state {
    switch (state) {
        case MCSessionStateConnected:
            return @"Connected";
            break;

        case MCSessionStateConnecting:
            return @"Connecting";
            break;

        case MCSessionStateNotConnected:
            return @"NotConnected";
            break;
    }
}

@end
