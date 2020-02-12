//
//  RNiBeacon.m
//  RNiBeacon
//
//  Created by MacKentoch on 17/02/2017.
//  Copyright © 2017 Erwan DATIN. All rights reserved.
//

#import <CoreLocation/CoreLocation.h>

#import <React/RCTBridge.h>
#import <React/RCTConvert.h>
#import <React/RCTEventDispatcher.h>
#import "ESSBeaconScanner.h"
#import "ESSEddystone.h"

#import "RNiBeacon.h"

static NSString *const kEddystoneRegionID = @"EDDY_STONE_REGION_ID";

@interface RNiBeacon() <CLLocationManagerDelegate, ESSBeaconScannerDelegate>
    
@property (strong, nonatomic) CLLocationManager *locationManager;
@property (strong, nonatomic) ESSBeaconScanner *eddyStoneScanner;
@property (assign, nonatomic) BOOL dropEmptyRanges;
@property NSString *debugApiEndpoint;
@property NSDate *lastApiSendDate;
@property NSString *apiToken;
@property NSString *beaconApiRequest;
@property NSString *notiApi;
@property NSString *notiTitle;
@property NSString *notiContent;
@property NSDictionary *MyRegion;
@property NSString *uid;
@property int notiDelay;
@property int sendPeriod;

@end

@implementation RNiBeacon
    
RCT_EXPORT_MODULE()
    
#pragma mark Initialization
    
- (instancetype)init
    {
        if (self = [super init]) {
            self.locationManager = [[CLLocationManager alloc] init];
            
            self.locationManager.delegate = self;
            self.locationManager.pausesLocationUpdatesAutomatically = NO;
            self.locationManager.allowsBackgroundLocationUpdates = YES;
            self.dropEmptyRanges = NO;
            self.locationManager.distanceFilter = 0.1; // meters
            self.locationManager.activityType = CLActivityTypeAutomotiveNavigation;
            self.locationManager.desiredAccuracy = kCLLocationAccuracyBest;
            self.eddyStoneScanner = [[ESSBeaconScanner alloc] init];
            self.eddyStoneScanner.delegate = self;
            self.MyRegion = nil;
            self.debugApiEndpoint = @"";
            
        }
        
        return self;
    }
    
+ (instancetype)sharedInstance
    {
        static RNiBeacon *sharedInstance = nil;
        static dispatch_once_t onceToken;
        dispatch_once(&onceToken, ^{
            sharedInstance = [[RNiBeacon alloc] init];
            // Do any other initialisation stuff here
            sharedInstance.sendPeriod = 60 * 1000;
            sharedInstance.notiDelay = 30;
        });
        return sharedInstance;
    }
    
- (NSArray<NSString *> *)supportedEvents
    {
        return @[
                 @"authorizationStatusDidChange",
                 @"beaconsDidRange",
                 @"regionDidEnter",
                 @"regionDidExit",
                 @"didDetermineState"
                 ];
    }
    
#pragma mark
    
-(CLBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                  uuid: (NSString *) uuid
                                 major: (NSInteger) major
                                 minor:(NSInteger) minor
    {
        NSUUID *beaconUUID = [[NSUUID alloc] initWithUUIDString:uuid];
        
        unsigned short mj = (unsigned short) major;
        unsigned short mi = (unsigned short) minor;
        
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:beaconUUID major:mj
                                                                               minor:mi
                                                                          identifier:identifier];
        
        NSLog(@"[Beacon] createBeaconRegion with: identifier - uuid - major - minor");
        beaconRegion.notifyOnEntry = YES;
        beaconRegion.notifyOnExit = YES;
        beaconRegion.notifyEntryStateOnDisplay = YES;
        
        return beaconRegion;
    }
    
-(CLBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                  uuid: (NSString *) uuid
                                 major: (NSInteger) major
    {
        NSUUID *beaconUUID = [[NSUUID alloc] initWithUUIDString:uuid];
        
        unsigned short mj = (unsigned short) major;
        
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:beaconUUID
                                                                               major:mj
                                                                          identifier:identifier];
        
        NSLog(@"[Beacon] createBeaconRegion with: identifier - uuid - major");
        beaconRegion.notifyOnEntry = YES;
        beaconRegion.notifyOnExit = YES;
        beaconRegion.notifyEntryStateOnDisplay = YES;
        
        return beaconRegion;
    }
    
-(CLBeaconRegion *) createBeaconRegion: (NSString *) identifier
                                  uuid: (NSString *) uuid
    {
        NSUUID *beaconUUID = [[NSUUID alloc] initWithUUIDString:uuid];
        
        CLBeaconRegion *beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:beaconUUID
                                                                          identifier:identifier];
        
        NSLog(@"[Beacon] createBeaconRegion with: identifier - uuid");
        beaconRegion.notifyOnEntry = YES;
        beaconRegion.notifyOnExit = YES;
        beaconRegion.notifyEntryStateOnDisplay = YES;
        
        return beaconRegion;
    }
    
-(CLBeaconRegion *) convertDictToBeaconRegion: (NSDictionary *) dict
    {
        if (dict[@"minor"] == nil) {
            if (dict[@"major"] == nil) {
                return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                           uuid:[RCTConvert NSString:dict[@"uuid"]]];
            } else {
                return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                           uuid:[RCTConvert NSString:dict[@"uuid"]]
                                          major:[RCTConvert NSInteger:dict[@"major"]]];
            }
        } else {
            return [self createBeaconRegion:[RCTConvert NSString:dict[@"identifier"]]
                                       uuid:[RCTConvert NSString:dict[@"uuid"]]
                                      major:[RCTConvert NSInteger:dict[@"major"]]
                                      minor:[RCTConvert NSInteger:dict[@"minor"]]];
        }
    }
    
-(NSDictionary *) convertBeaconRegionToDict: (CLBeaconRegion *) region
    {
        if (region.minor == nil) {
            if (region.major == nil) {
                return @{
                         @"identifier": region.identifier,
                         @"uuid": [region.proximityUUID UUIDString],
                         };
            } else {
                return @{
                         @"identifier": region.identifier,
                         @"uuid": [region.proximityUUID UUIDString],
                         @"major": region.major
                         };
            }
        } else {
            return @{
                     @"identifier": region.identifier,
                     @"uuid": [region.proximityUUID UUIDString],
                     @"major": region.major,
                     @"minor": region.minor
                     };
        }
    }
    
-(NSString *)stringForProximity:(CLProximity)proximity {
    switch (proximity) {
        case CLProximityUnknown:    return @"unknown";
        case CLProximityFar:        return @"far";
        case CLProximityNear:       return @"near";
        case CLProximityImmediate:  return @"immediate";
        default:                    return @"";
    }
}
    
RCT_EXPORT_METHOD(requestAlwaysAuthorization)
{
    if ([self.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)]) {
        [self.locationManager requestAlwaysAuthorization];
    }
}

RCT_EXPORT_METHOD(requestWhenInUseAuthorization)
{
    if ([self.locationManager respondsToSelector:@selector(requestWhenInUseAuthorization)]) {
        [self.locationManager requestWhenInUseAuthorization];
    }
}

RCT_EXPORT_METHOD(allowsBackgroundLocationUpdates:(BOOL)allow)
{
    self.locationManager.allowsBackgroundLocationUpdates = allow;
}

RCT_EXPORT_METHOD(getAuthorizationStatus:(RCTResponseSenderBlock)callback)
{
    callback(@[[self nameForAuthorizationStatus:[CLLocationManager authorizationStatus]]]);
}

RCT_EXPORT_METHOD(getMonitoredRegions:(RCTResponseSenderBlock)callback)
{
    NSMutableArray *regionArray = [[NSMutableArray alloc] init];
    
    for (CLBeaconRegion *region in self.locationManager.monitoredRegions) {
        [regionArray addObject: [self convertBeaconRegionToDict: region]];
    }
    
    callback(@[regionArray]);
}

RCT_EXPORT_METHOD(startMonitoringForRegion:(NSDictionary *) dict)
{
    [self.locationManager startMonitoringSignificantLocationChanges];
    self.MyRegion = [dict copy];
    [self.locationManager startMonitoringForRegion:[self convertDictToBeaconRegion:dict]];
    
    [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                     @"StartMonitoringForRegion", @"message",
                     nil]];
}

RCT_EXPORT_METHOD(startRangingBeaconsInRegion:(NSDictionary *) dict)
{
    if ([dict[@"identifier"] isEqualToString:kEddystoneRegionID]) {
        [_eddyStoneScanner startScanning];
    } else {
        [self.locationManager startRangingBeaconsInRegion:[self convertDictToBeaconRegion:dict]];
    }
    [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                     @"StartRangingForRegion", @"message",
                     nil]];
}

RCT_EXPORT_METHOD(stopMonitoringForRegion:(NSDictionary *) dict)
{
    [self.locationManager stopMonitoringSignificantLocationChanges];
    self.MyRegion = nil;
    [self.locationManager stopMonitoringForRegion:[self convertDictToBeaconRegion:dict]];
    [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                     @"StopMonitoringForRegion", @"message",
                     nil]];
}

RCT_EXPORT_METHOD(stopRangingBeaconsInRegion:(NSDictionary *) dict)
{
    if ([dict[@"identifier"] isEqualToString:kEddystoneRegionID]) {
        [self.eddyStoneScanner stopScanning];
    } else {
        [self.locationManager stopRangingBeaconsInRegion:[self convertDictToBeaconRegion:dict]];
    }
    [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                     @"StopRangingForRegion", @"message",
                     nil]];
}

RCT_EXPORT_METHOD(startUpdatingLocation)
{
    [self.locationManager startUpdatingLocation];
}

RCT_EXPORT_METHOD(stopUpdatingLocation)
{
    [self.locationManager stopUpdatingLocation];
}

RCT_EXPORT_METHOD(shouldDropEmptyRanges:(BOOL)drop)
{
    self.dropEmptyRanges = drop;
}

RCT_EXPORT_METHOD(setDebugApi:(NSString *)debugApi)
{
    NSLog(@"[Beacon] setDebugApi: %@", debugApi);
    self.debugApiEndpoint = [debugApi copy];
}

RCT_EXPORT_METHOD(setRequestToken:(NSString *)token)
{
    NSLog(@"[Beacon] setRequestToken: %@", token);
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    sharedInstance.apiToken = [token copy];
}

RCT_EXPORT_METHOD(setBeaconRequestApi:(NSString *)requestApi)
{
    NSLog(@"[Beacon] setBeaconRequestApi: %@", requestApi);
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    sharedInstance.beaconApiRequest = [requestApi copy];
}

RCT_EXPORT_METHOD(setNotificationRequestApi:(NSString *)notificationRequestApi)
{
    NSLog(@"[Beacon] setNotificationRequestApi: %@", notificationRequestApi);
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    sharedInstance.notiApi = [notificationRequestApi copy];
}

RCT_EXPORT_METHOD(setNotificationTitle:(NSString *)notificationTitle)
{
    NSLog(@"[Beacon] setNotificationTitle: %@", notificationTitle);
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    sharedInstance.notiTitle = [notificationTitle copy];
}

RCT_EXPORT_METHOD(setNotificationContent:(NSString *)notificationContent)
{
    NSLog(@"[Beacon] setNotificationContent: %@", notificationContent);
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    sharedInstance.notiContent = [notificationContent copy];
}

RCT_EXPORT_METHOD(setBeaconSendPeriod:(int)beaconSendPeriod)
{
    NSLog(@"[Beacon] setBeaconSendPeriod: %d", beaconSendPeriod);
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    sharedInstance.sendPeriod = beaconSendPeriod;
}

RCT_EXPORT_METHOD(setUserId:(NSString *)userId)
{
    NSLog(@"[Beacon] setUserId: %@", userId);
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    sharedInstance.uid = [userId copy];
}
    
RCT_EXPORT_METHOD(setNotificationDelay:(int)notificationDelay)
{
    NSLog(@"[Beacon] setNotificationDelay: %d", notificationDelay);
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    sharedInstance.notiDelay = notificationDelay;
}

    
-(NSString *)nameForAuthorizationStatus:(CLAuthorizationStatus)authorizationStatus
    {
        switch (authorizationStatus) {
            case kCLAuthorizationStatusAuthorizedAlways:
            return @"authorizedAlways";
            
            case kCLAuthorizationStatusAuthorizedWhenInUse:
            return @"authorizedWhenInUse";
            
            case kCLAuthorizationStatusDenied:
            return @"denied";
            
            case kCLAuthorizationStatusNotDetermined:
            return @"notDetermined";
            
            case kCLAuthorizationStatusRestricted:
            return @"restricted";
        }
    }
    
- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
    {
        CLLocation *location = [locations lastObject];
        [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                         @"didUpdateLocations", @"message",
                         nil]];
    }
    
-(void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
    {
        NSString *statusName = [self nameForAuthorizationStatus:status];
        [self sendEventWithName:@"authorizationStatusDidChange" body:statusName];
    }
    
-(void)locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
    {
        NSLog(@"[Beacon] Failed ranging region: %@", error);
    }
    
-(void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
    NSLog(@"[Beacon] Failed monitoring region: %@", error);
}
    
-(void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
    NSLog(@"[Beacon] Location manager failed: %@", error);
}
    
-(NSString *)stringForState:(CLRegionState)state {
    switch (state) {
        case CLRegionStateInside:   return @"inside";
        case CLRegionStateOutside:  return @"outside";
        case CLRegionStateUnknown:  return @"unknown";
        default:                    return @"unknown";
    }
}
    
- (void) locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
    {
        
        NSDictionary *event = @{
                                @"state":   [self stringForState:state],
                                @"identifier":  region.identifier,
                                };
        
        [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                         @"didDetermineState", @"message",
                         [self stringForState:state], @"state",
                         nil]];
        
        [self sendEventWithName:@"didDetermineState" body:event];
        
        switch (state) {
            case CLRegionStateInside:
            [self startRanging: self.MyRegion];
            return;
            case CLRegionStateOutside:
            [self stopRanging: self.MyRegion];
            return;
            default:
            return;
        }
    }
    
-(void) locationManager:(CLLocationManager *)manager didRangeBeacons:
(NSArray *)beacons inRegion:(CLBeaconRegion *)region
    {
        if (self.dropEmptyRanges && beacons.count == 0) {
            return;
        }
        NSMutableArray *beaconArray = [[NSMutableArray alloc] init];
        
        for (CLBeacon *beacon in beacons) {
            [beaconArray addObject:@{
                                     @"uuid": [beacon.proximityUUID UUIDString],
                                     @"major": beacon.major,
                                     @"minor": beacon.minor,
                                     
                                     @"rssi": [NSNumber numberWithLong:beacon.rssi],
                                     @"proximity": [self stringForProximity: beacon.proximity],
                                     @"accuracy": [NSNumber numberWithDouble: beacon.accuracy],
                                     @"distance": [NSNumber numberWithDouble: beacon.accuracy],
                                     }];
        }
        
        NSDictionary *event = @{
                                @"region": @{
                                        @"identifier": region.identifier,
                                        @"uuid": [region.proximityUUID UUIDString],
                                        },
                                @"beacons": beaconArray
                                };
        
        [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                         @"didRangeBeacons", @"message",
                         beaconArray, @"beacons",
                         nil]];
        RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
        if(self.lastApiSendDate != nil) {
            NSTimeInterval seconds = [[NSDate date] timeIntervalSinceDate:self.lastApiSendDate];
            if((seconds * 1000) > sharedInstance.sendPeriod) {
                self.lastApiSendDate = [NSDate date];
                [self sendBeacon:[beaconArray firstObject]];
            }
        } else {
            self.lastApiSendDate = [NSDate date];
            [self sendBeacon:[beaconArray firstObject]];
        }
        
        [self sendEventWithName:@"beaconsDidRange" body:event];
    }
    
-(void)locationManager:(CLLocationManager *)manager
        didEnterRegion:(CLBeaconRegion *)region {
    NSDictionary *event = [self convertBeaconRegionToDict: region];
    [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                     @"EnterRegion", @"message",
                     nil]];
    
    [self sendEventWithName:@"regionDidEnter" body:event];
}
    
-(void)locationManager:(CLLocationManager *)manager
         didExitRegion:(CLBeaconRegion *)region {
    NSDictionary *event = [self convertBeaconRegionToDict: region];
    [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                     @"ExitRegion", @"message",
                     nil]];
    [self sendEventWithName:@"regionDidExit" body:event];
}
    
+ (BOOL)requiresMainQueueSetup
    {
        return YES;
    }
    
- (void)beaconScanner:(ESSBeaconScanner *)scanner didRangeBeacon:(NSArray *)beacons {
    [self notifyAboutBeaconChanges:beacons];
}
    
- (void)notifyAboutBeaconChanges:(NSArray *)beacons {
    NSMutableArray *beaconArray = [[NSMutableArray alloc] init];
    
    for (id key in beacons) {
        ESSBeaconInfo *beacon = key;
        NSDictionary *info = [self getEddyStoneInfo:beacon];
        [beaconArray addObject:info];
    }
    NSDictionary *event = @{
                            @"region": @{
                                    @"identifier": kEddystoneRegionID,
                                    @"uuid": @"", // do not use for eddy stone
                                    },
                            @"beacons": beaconArray
                            };
    [self sendEventWithName:@"beaconsDidRange" body:event];
}
    
- (NSDictionary*)getEddyStoneInfo:(id)beaconInfo {
    ESSBeaconInfo *info = beaconInfo;
    NSNumber *distance = [self calculateDistance:info.txPower rssi:info.RSSI];
    NSString *identifier = [self getEddyStoneUUID:info.beaconID.beaconID];
    NSDictionary *beaconData = @{
                                 @"identifier": identifier,
                                 @"uuid": identifier,
                                 @"rssi": info.RSSI,
                                 @"txPower": info.txPower,
                                 @"distance": distance,
                                 };
    return beaconData;
}
    
- (NSNumber*)calculateDistance:(NSNumber*)txPower rssi:(NSNumber*) rssi {
    if ([rssi floatValue] >= 0){
        return [NSNumber numberWithInt:-1];
    }
    
    float ratio = [rssi floatValue] / ([txPower floatValue] - 41);
    if (ratio < 1.0) {
        return [NSNumber numberWithFloat:pow(ratio, 10)];
    }
    
    float distance = (0.89976) * pow(ratio, 7.7095) + 0.111;
    return [NSNumber numberWithFloat:distance];
}
    
- (NSString *)getEddyStoneUUID:(NSData*)data {
    const unsigned char *dataBuffer = (const unsigned char *)[data bytes];
    const int EDDYSTONE_UUID_LENGTH = 10;
    if (!dataBuffer) {
        return [NSString string];
    }
    
    NSMutableString *hexString  = [NSMutableString stringWithCapacity:(data.length * 2)];
    [hexString appendString:@"0x"];
    for (int i = 0; i < EDDYSTONE_UUID_LENGTH; ++i) {
        [hexString appendString:[NSString stringWithFormat:@"%02lx", (unsigned long)dataBuffer[i]]];
    }
    
    return [NSString stringWithString:hexString];
}
    
-(void)startRanging: (NSDictionary *)dict {
    if(dict != nil) {
        if ([dict[@"identifier"] isEqualToString:kEddystoneRegionID]) {
            [_eddyStoneScanner startScanning];
        } else {
            [self.locationManager startRangingBeaconsInRegion:[self convertDictToBeaconRegion:dict]];
        }
        [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                         @"StartRangingForRegion", @"message",
                         nil]];
    }
}
    
-(void)stopRanging: (NSDictionary *)dict {
    if(dict != nil) {
        if ([dict[@"identifier"] isEqualToString:kEddystoneRegionID]) {
            [self.eddyStoneScanner stopScanning];
        } else {
            [self.locationManager stopRangingBeaconsInRegion:[self convertDictToBeaconRegion:dict]];
        }
        [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                         @"StopRangingForRegion", @"message",
                         nil]];
    }
}
    
-(void)sendDebug:(NSDictionary *) dict {
    if(self.debugApiEndpoint && self.debugApiEndpoint.length != 0) {
        NSString *requestUrl = self.debugApiEndpoint;
        NSMutableDictionary *jsonData = [dict mutableCopy];
        [jsonData setObject:@"ios" forKey:@"device"];
        
        NSError* error;
        NSData* data = [NSJSONSerialization dataWithJSONObject:jsonData options:0 error:&error];
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"POST"];
        [request setURL:[NSURL URLWithString:requestUrl]];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        [request setHTTPBody:[dataString dataUsingEncoding:NSUTF8StringEncoding]];
        NSError *responseError;
        NSURLResponse *response = nil;
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&responseError];
    }
}
    
-(void)sendBeacon:(NSDictionary *) dict {
    
    NSDictionary *jsonData = nil;
    
    if(dict[@"uuid"] != nil) {
        jsonData = [[NSDictionary alloc] initWithObjectsAndKeys:
                    dict[@"uuid"],@"uuid",
                    dict[@"major"],@"major",
                    dict[@"minor"],@"minor",
                    nil];
    }
    
    [self sendDebug:[[NSDictionary alloc] initWithObjectsAndKeys:
                     @"SendBeacon", @"message",
                     jsonData, @"Beacon",
                     nil]];
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    if(sharedInstance.beaconApiRequest && sharedInstance.beaconApiRequest.length != 0 && sharedInstance.apiToken && sharedInstance.apiToken.length != 0) {
        NSString *requestUrl = sharedInstance.beaconApiRequest;
        NSError* error;
        NSData* data = [NSJSONSerialization dataWithJSONObject:jsonData options:0 error:&error];
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"POST"];
        [request setURL:[NSURL URLWithString:requestUrl]];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        NSString *authorizationToken = [NSString stringWithFormat:@"%@", sharedInstance.apiToken];
        [request setValue:authorizationToken forHTTPHeaderField:@"Authorization"];
        [request setHTTPBody:[dataString dataUsingEncoding:NSUTF8StringEncoding]];
        NSError *responseError;
        NSURLResponse *response = nil;
        
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&responseError];
        if (!error) {
            NSLog(@"[Beacon] Send Beacon Response String : %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
            
            id json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            NSLog(@"[Beacon] Send Beacon Parsed Data : %@", json);
        }
    }
}
    
+ (void)applicationWillTerminate:(UIApplication *)application
{
    RNiBeacon *sharedInstance = [RNiBeacon sharedInstance];
    if(sharedInstance.apiToken && sharedInstance.apiToken.length != 0 && sharedInstance.uid && sharedInstance.uid.length != 0 && sharedInstance.notiApi && sharedInstance.notiApi.length != 0 && sharedInstance.notiContent && sharedInstance.notiContent.length != 0 && sharedInstance.notiTitle && sharedInstance.notiTitle.length != 0) {
        NSDictionary *jsonData = [[NSDictionary alloc] initWithObjectsAndKeys:
                                  @"true", @"content_available",
                                  sharedInstance.notiTitle, @"title",
                                  sharedInstance.uid, @"userId",
                                  sharedInstance.notiContent, @"message",
                                  @(sharedInstance.notiDelay), @"delay",
                                  nil];
        
        NSError* error;
        NSData* data = [NSJSONSerialization dataWithJSONObject:jsonData options:0 error:&error];
        NSString *dataString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
        NSMutableURLRequest *request = [[NSMutableURLRequest alloc] init];
        [request setHTTPMethod:@"POST"];
        [request setURL:[NSURL URLWithString:sharedInstance.notiApi]];
        [request setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
        [request setValue:@"application/json" forHTTPHeaderField:@"Accept"];
        NSString *authorizationToken = [NSString stringWithFormat:@"%@", sharedInstance.apiToken];
        [request setValue:authorizationToken forHTTPHeaderField:@"Authorization"];
        [request setHTTPBody:[dataString dataUsingEncoding:NSUTF8StringEncoding]];
        
        NSError *responseError;
        NSURLResponse *response = nil;
        
        sleep(2);
        
        NSData *responseData = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&responseError];
        if (!error) {
            NSLog(@"[Beacon] Send Notification Response String : %@", [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding]);
            
            id json = [NSJSONSerialization JSONObjectWithData:responseData options:0 error:nil];
            NSLog(@"[Beacon] Send Notification  Parsed Data : %@", json);
        }
        
    }
}

@end
