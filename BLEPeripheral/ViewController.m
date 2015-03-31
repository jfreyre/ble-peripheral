//
//  ViewController.m
//  BLEPeripheral
//
//  Created by Jérome Freyre on 27.03.15.
//  Copyright (c) 2015 JDC Electronic. All rights reserved.
//

#import "ViewController.h"
#import "LoremIpsum.h"
#import "SVProgressHUD.h"

@interface ViewController ()

@end

@implementation ViewController


- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // Start up the CBPeripheralManager
    _peripheralManager = [[CBPeripheralManager alloc] initWithDelegate:self queue:dispatch_get_main_queue()];
}

-(void) setupService {
    
    
    _anmWritable = [[CBMutableCharacteristic alloc]
                    initWithType:[CBUUID UUIDWithString:BLE_SERVICE_WRITABLE]
                    properties:CBCharacteristicPropertyWriteWithoutResponse | CBCharacteristicPropertyWrite
                    value:nil
                    permissions:CBAttributePermissionsWriteable];
    _anmReadableShort = [[CBMutableCharacteristic alloc]
                         initWithType:[CBUUID UUIDWithString:BLE_SERVICE_READABLE_SHORT]
                         properties:CBCharacteristicPropertyRead
                         value:nil
                         permissions:CBAttributePermissionsReadable];
    _anmReadableLarge = [[CBMutableCharacteristic alloc]
                         initWithType:[CBUUID UUIDWithString:BLE_SERVICE_READABLE_LARGE]
                         properties:CBCharacteristicPropertyRead
                         value:nil
                         permissions:CBAttributePermissionsReadable];
    
    _anmNotifier  = [[CBMutableCharacteristic alloc]
                     initWithType:[CBUUID UUIDWithString:BLE_SERVICE_NOTIFIER]
                     properties:CBCharacteristicPropertyNotify
                     value:nil
                     permissions:CBAttributePermissionsReadable];
    
    _anmService = [[CBMutableService alloc] initWithType:[CBUUID UUIDWithString:BLE_SERVICE]
                                                                  primary:YES];
    [_anmService setCharacteristics:@[_anmWritable, _anmReadableShort, _anmReadableLarge, _anmNotifier]];
    
    // And add it to the peripheral manager
    [self.peripheralManager addService:_anmService];
    
    
}


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


#pragma mark
#pragma mark CoreBlueTooth delegate

/** Required protocol method.  A full app should take care of all the possible states,
 *  but we're just waiting for  to know when the CBPeripheralManager is ready
 */
- (void)peripheralManagerDidUpdateState:(CBPeripheralManager *)peripheral
{
    switch (peripheral.state) {
        case CBPeripheralManagerStatePoweredOn:
            NSLog(@"Peripheral powered on.");
            [self setupService];
            break;
        default:
            NSLog(@"Peripheral Manager did change state");
            break;
    }
}

-(void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveReadRequest:(CBATTRequest *)request
{
    if (_dataToSend == nil || _dataToSend.length == 0) {
        _sendDataIndex = 0;
        if ([request.characteristic.UUID isEqual:_anmReadableShort.UUID]) {
            _dataToSend = [[LoremIpsum wordsWithNumber:1] dataUsingEncoding:NSUTF8StringEncoding];
            
        } else if ([request.characteristic.UUID isEqual:_anmReadableLarge.UUID]) {
            _dataToSend = [[LoremIpsum paragraphsWithNumber:3] dataUsingEncoding:NSUTF8StringEncoding];
            
        } else {
            [self.peripheralManager respondToRequest:request withResult:CBATTErrorAttributeNotFound];
            return;
        }
    }
    
    if (_sendDataIndex < [_dataToSend length]) {
        int amountToSend = _dataToSend.length - _sendDataIndex;
        amountToSend = (amountToSend > NOTIFY_MTU) ? NOTIFY_MTU : amountToSend;
        
        NSData * chunk = [_dataToSend subdataWithRange:NSMakeRange(_sendDataIndex, amountToSend)];
        NSLog(@"SENT: %@", [[NSString alloc] initWithData:chunk encoding:NSUTF8StringEncoding]);
        request.value = chunk;
        _sendDataIndex += amountToSend;
        
    } else {
        NSData * eomData = [@"==EOM==" dataUsingEncoding:NSUTF8StringEncoding];
        NSLog(@"SENT EOM");
        request.value = eomData;
        _sendDataIndex = 0;
        _dataToSend = nil;
    }
    [self.peripheralManager respondToRequest:request withResult:CBATTErrorSuccess];
    
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral didReceiveWriteRequests:(NSArray *)requests
{
    
    for (CBATTRequest * r in requests) {
        
        NSString * msg = [[NSString alloc] initWithData:r.value encoding:NSUTF8StringEncoding];
        if (msg == nil) {
            [peripheral respondToRequest:r withResult:CBATTErrorUnlikelyError];
            return;
        } else {
            [peripheral respondToRequest:r withResult:CBATTErrorSuccess];
        }
        if ([msg  isEqual: @"==EOM=="]) {
            [SVProgressHUD showSuccessWithStatus:_receivedData];
            _receivedData = @"";
        } else {
            _receivedData = [_receivedData stringByAppendingString:msg];
            [SVProgressHUD showWithStatus:@"Receiving data..."];
        }
        NSLog(@"received: %@", msg);
        
    }
}


- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didSubscribeToCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central subscribed to characteristic %@", characteristic.UUID.UUIDString);
}

- (void)peripheralManager:(CBPeripheralManager *)peripheral central:(CBCentral *)central didUnsubscribeFromCharacteristic:(CBCharacteristic *)characteristic
{
    NSLog(@"Central unsubscribed from characteristic");
}

- (void)peripheralManagerIsReadyToUpdateSubscribers:(CBPeripheralManager *)peripheral
{
    
}


#pragma mark
#pragma mark Actions

-(IBAction)toggleAdvertising:(id)sender
{
    UIButton * advertisingBtn = (UIButton*) sender;
    if ([self.peripheralManager isAdvertising]) {
        
        [self.peripheralManager stopAdvertising];
        [advertisingBtn setTitle:@"Start adv." forState:UIControlStateNormal];
        NSLog(@"Stop advertising");
    } else {
        [self.peripheralManager startAdvertising:@{
                                                   CBAdvertisementDataLocalNameKey: [[UIDevice currentDevice] name],
                                                   CBAdvertisementDataServiceUUIDsKey : @[[CBUUID UUIDWithString:BLE_SERVICE]]
                                                   }];
        [advertisingBtn setTitle:@"Stop adv." forState:UIControlStateNormal];
        NSLog(@"Start advertising");
    }
}

-(IBAction)sendRandom:(id)sender
{
    
    if (((UISwitch*)sender).on) {
        self.timer = [NSTimer scheduledTimerWithTimeInterval:1 target:self selector:@selector(sendRandomNumber) userInfo:nil repeats:NO];
    } else {
        [self.timer invalidate];
    }
}

-(void) sendRandomNumber
{
    
    NSNumber *randomNumber = [NSNumber numberWithInt:arc4random() % 100];
    
    [self.peripheralManager updateValue:[randomNumber.stringValue dataUsingEncoding:NSUTF8StringEncoding]
                      forCharacteristic:_anmNotifier
                   onSubscribedCentrals:nil];
    
    NSLog(@"Send random %@", randomNumber);
    self.timer = [NSTimer scheduledTimerWithTimeInterval:1
                                                  target:self
                                                selector:@selector(sendRandomNumber)
                                                userInfo:nil
                                                 repeats:NO];
}


@end
