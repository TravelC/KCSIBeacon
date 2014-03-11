//
//  KSBeaconManager.m
//  KCSIBeacon
//
//  Copyright 2014 Kinvey, Inc
//
//  Licensed under the Apache License, Version 2.0 (the "License");
//  you may not use this file except in compliance with the License.
//  You may obtain a copy of the License at
//
//  http://www.apache.org/licenses/LICENSE-2.0
//
//  Unless required by applicable law or agreed to in writing, software
//  distributed under the License is distributed on an "AS IS" BASIS,
//  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
//  See the License for the specific language governing permissions and
//  limitations under the License.
//

#import "KCSBeaconManager.h"

@import UIKit;

@interface KCSBeaconManager () <CLLocationManagerDelegate>
@property (nonatomic, strong) CLLocationManager* locationManager;
@property (nonatomic, strong) CLBeacon* lastBeacon;
@property (nonatomic, strong) NSDate* lastRanging;
@property (nonatomic, strong) NSDate* lastBoundary;
@end


#define kUUID @"999DAFD9-3BAF-4DC1-8019-907B52ECE096"

@implementation KCSBeaconManager

- (id)init
{
    self = [super init];
    if (self) {
        _lastBeacon = nil;
        _lastRanging = nil;
        _lastBoundary = nil;
        _monitoringInterval = 0;
    }
    return self;
}

/*
 
 The Core Location framework provides two ways to detect a user’s entry and exit into specific regions: geographical region monitoring (iOS 4.0 and later and OS X 10.8 and later) and beacon region monitoring (iOS 7.0 and later and OS X 10.9 and later). A geographical region is an area defined by a circle of a specified radius around a known point on the Earth’s surface. In contrast, a beacon region is an area defined by the device’s proximity to Bluetooth low energy beacons. Beacons themselves are simply devices that advertise a particular Bluetooth low energy payload—you can even turn your iOS device and Mac into a beacon with some assistance from the Core Bluetooth framework.
 
 Apps can use region monitoring to be notified when the user crosses geographic boundaries or when the user enters or exits the vicinity of a beacon. While a beacon is in range of the user’s device, apps can also monitor for the relative distance to the beacon. You can use these capabilities to develop many types of innovative location-based apps. That said, because a geographical region and a beacon region are conceptually different from one another, the type of region monitoring you decide to use in your app will likely depend on the use case your app is designed to fulfill.
 
 In iOS, regions associated with your app are tracked at all times, including when your app is not running. If a region boundary is crossed while an app is not running, that app is relaunched into the background to handle the event. Similarly, if the app is suspended when the event occurs, it is woken up and given a short amount of time (around 10 seconds) to handle the event. When necessary, an app can request more background execution time using the beginBackgroundTaskWithExpirationHandler: method of the UIApplication class. Be sure to end the background task appropriately by calling the endBackgroundTask: method. The process for requesting more background execution time is described in “Executing a Finite-Length Task in the Background” in iOS App Programming Guide.
 
 In OS X, region monitoring works only while the app is running (either in the foreground or background) and the user’s system is awake. As a result, the system does not launch apps to deliver region-related notifications.
 
 Determining the Availability of Region Monitoring
 
 Before attempting to monitor any regions, your app should check to see if region monitoring is supported on the current device. There are several reasons why region monitoring might not be available:
 
 The device may not have the hardware needed to support region monitoring.
 The user might have denied the app the authorization to use region monitoring.
 The user may have disabled location services in the Settings app.
 The user may have disabled Background App Refresh in the Settings app, either for the device or for your app.
 The device might be in Airplane mode and unable to power up the necessary hardware.
 In iOS 7.0 and later, you should always call the isMonitoringAvailableForClass: and authorizationStatus class methods of CLLocationManager before attempting to monitor regions. (In OS X 10.8 and later and in previous versions of iOS, use the regionMonitoringAvailable class instead.) The isMonitoringAvailableForClass: method lets you know whether the underlying hardware supports region monitoring for the specified class at all. If that method returns NO, your app can’t use region monitoring on the device. If it returns YES, call the authorizationStatus method to determine whether the app is currently authorized to use location services. If the authorization status is kCLAuthorizationStatusAuthorized, your app will begin to receive boundary crossing notifications for any regions it registered. If the authorization status is set to any other value, your app does not receive those notifications.
 
 Note: Even if your app is not authorized to use region monitoring, it can still register regions for use later. If the user subsequently grants authorization to your app, monitoring for those regions will begin and will generate subsequent boundary crossing notifications. If you do not want regions to remain installed while your app is not authorized, you can use the locationManager:didChangeAuthorizationStatus: delegate method to detect changes in your app’s status and remove regions as appropriate.
 Finally, if your app needs to process location updates in the background, be sure to check the backgroundRefreshStatus property of the UIApplication class. You can use the value of this property to determine if doing so is possible and to warn the user if it is not.
 
 
 */

- (CLLocationManager *)locationManager
{
    if (!_locationManager) {
        _locationManager = [[CLLocationManager alloc] init];
    }
    return _locationManager;
}

- (void) startMonitoringForRegion:(NSString*)UUIDString identifier:(NSString*)identifier
{
    [self startMonitoringForRegion:UUIDString identifier:identifier major:nil minor:nil];
}

- (void) startMonitoringForRegion:(NSString*)UUIDString identifier:(NSString*)identifier major:(NSNumber*)major minor:(NSNumber*)minor
{
    // Create the beacon region to be monitored.
    NSUUID* uuid = [[NSUUID alloc] initWithUUIDString:UUIDString];
    
    CLBeaconRegion *beaconRegion;
    if (minor) {
        beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:[major unsignedIntValue] minor:[minor unsignedIntValue] identifier:identifier];
    } else if (major) {
        beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid major:[major unsignedIntValue] identifier:identifier];
    } else {
        beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:uuid identifier:identifier];
    }
    
    beaconRegion.notifyEntryStateOnDisplay = YES;
    
    // Register the beacon region with the location manager.
    [self.locationManager startMonitoringForRegion:beaconRegion];
    self.locationManager.delegate = self;
    
    _lastRanging = [NSDate date];
}


- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region
{
    NSLog(@"%@", region);
    CLBeaconRegion* reg = (CLBeaconRegion*)region;
    NSNumber* maj = reg.major;

    if (state == CLRegionStateInside) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        
        notification.alertBody = NSLocalizedString(@"You're inside the region", @"");
        if (maj) {
            notification.userInfo = @{@"inside":maj};
        }
        notification.userInfo = @{@"uuid":reg.identifier};
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
        
        [self.locationManager startRangingBeaconsInRegion:reg];
    } else if (state == CLRegionStateOutside) {
        [self.locationManager stopRangingBeaconsInRegion:reg];
    } else {
        //unknown?
    }
    
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"%@",error);
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error
{
    NSLog(@"%@", error);
    if (self.delegate && [self.delegate respondsToSelector:@selector(rangingFailedForRegion:withError:)]) {
        [self.delegate rangingFailedForRegion:nil withError:error];
    }
}

- (void)locationManager:(CLLocationManager *)manager didEnterRegion:(CLRegion *)region
{
    if ([[NSDate date] timeIntervalSinceDate:self.lastBoundary] < self.monitoringInterval) {
        return;
    }
    self.lastBoundary = [NSDate date];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(enteredRegion:)]) {
        [self.delegate enteredRegion:(CLBeaconRegion*)region];
    }
    
    if (self.postsLocalNotification) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = NSLocalizedString(@"You're inside the region %@", region.identifier);
        notification.userInfo = @{@"region":region, @"event":@"enter"};

        /*
         If the application is in the foreground, it will get a callback to application:didReceiveLocalNotification:.
         If it's not, iOS will display the notification to the user.
         */
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    }
}

- (void)locationManager:(CLLocationManager *)manager didExitRegion:(CLRegion *)region
{
    if ([[NSDate date] timeIntervalSinceDate:self.lastBoundary] < self.monitoringInterval) {
        return;
    }
    self.lastBoundary = [NSDate date];
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(exitedRegion:)]) {
        [self.delegate exitedRegion:(CLBeaconRegion*)region];
    }
    
    if (self.postsLocalNotification) {
        UILocalNotification *notification = [[UILocalNotification alloc] init];
        notification.alertBody = NSLocalizedString(@"You're outside the region %@", region.identifier);
        notification.userInfo = @{@"region":region, @"event":@"exit"};
        
        /*
         If the application is in the foreground, it will get a callback to application:didReceiveLocalNotification:.
         If it's not, iOS will display the notification to the user.
         */
        [[UIApplication sharedApplication] presentLocalNotificationNow:notification];
    }
}

- (void) locationManager:(CLLocationManager *)manager rangingBeaconsDidFailForRegion:(CLBeaconRegion *)region withError:(NSError *)error
{
    if (self.delegate && [self.delegate respondsToSelector:@selector(rangingFailedForRegion:withError:)]) {
        [self.delegate rangingFailedForRegion:region withError:error];
    }
}

- (void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray *)beacons inRegion:(CLBeaconRegion *)region
{
    CLBeacon* closestBeacon = nil;
    for (CLBeacon* beacon in beacons) {
        NSLog(@"beacons, %@: %ld", beacon, (long)beacon.proximity);
        if (!closestBeacon) {
            closestBeacon = beacon;
        } else {
            if (beacon.proximity > CLProximityUnknown) {
                if (beacon.proximity < closestBeacon.proximity) {
                    closestBeacon = beacon;
                } else if (beacon.proximity == closestBeacon.proximity && beacon.accuracy < closestBeacon.accuracy) {
                    closestBeacon = beacon;
                }
            } else if (closestBeacon.proximity == CLProximityUnknown && beacon.accuracy < closestBeacon.accuracy) {
                closestBeacon = beacon;
            }
            
        }
    }
    
    //Note that this can different CLBeacon instances, even for the same beacon
    BOOL different = ![self.lastBeacon.proximityUUID isEqual:closestBeacon.proximityUUID] ||
    ![self.lastBeacon.major isEqualToNumber:closestBeacon.major] ||
    ![self.lastBeacon.minor isEqualToNumber:self.lastBeacon.minor];
    
    if (different && [self.lastRanging timeIntervalSinceNow] >= -self.monitoringInterval) {
        self.lastBeacon = closestBeacon;
        self.lastRanging = [NSDate date];
        
        if (self.delegate && [self.delegate respondsToSelector:@selector(newNearestBeacon:)]) {
            [self.delegate newNearestBeacon:self.lastBeacon];
        }
    }
    
    
}

@end