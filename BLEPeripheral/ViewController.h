//
//  ViewController.h
//  BLEPeripheral
//
//  Created by Jérome Freyre on 27.03.15.
//  Copyright (c) 2015 JDC Electronic. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreBluetooth/CoreBluetooth.h>
#import "Services.h"

@interface ViewController : UIViewController<CBPeripheralManagerDelegate>



@property (strong, nonatomic) CBPeripheralManager       *peripheralManager;


@property (strong, nonatomic) CBMutableService          *anmService;
@property (strong, nonatomic) CBMutableCharacteristic   *anmWritable;
@property (strong, nonatomic) CBMutableCharacteristic   *anmReadableShort;
@property (strong, nonatomic) CBMutableCharacteristic   *anmReadableLarge;
@property (strong, nonatomic) CBMutableCharacteristic   *anmNotifier;


@property (strong, nonatomic) NSString                  * receivedData;
@property (strong, nonatomic) NSData                    *dataToSend;
@property (nonatomic, readwrite) NSInteger              sendDataIndex;
@property (nonatomic, strong) NSTimer                   *timer;


-(IBAction)toggleAdvertising:(id)sender;
-(IBAction)sendRandom:(id)sender;

@end

