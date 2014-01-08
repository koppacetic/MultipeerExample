//
//  ViewController.h
//  MultipeerExample
//
//  Created by Skip Koppenhaver on 1/8/14.
//  Copyright (c) 2014 Skip Koppenhaver. All rights reserved.
//
#import <UIKit/UIKit.h>
@import MultipeerConnectivity;

@interface ViewController : UIViewController <MCSessionDelegate, MCNearbyServiceAdvertiserDelegate, MCNearbyServiceBrowserDelegate,
                                                UITableViewDataSource, UITableViewDelegate>

@end
