//
//  MapViewController.m
//  zadanie
//
//  Created by Marcin Michałek on 22.07.2014.
//  Copyright (c) 2014 mm. All rights reserved.
//

#import "MapViewController.h"
#import "MyAnnotation.h"

@interface MapViewController ()

@end

#define JSON_URL "https://dl.dropboxusercontent.com/u/6556265/test.json"

@implementation MapViewController

#pragma mark -
#pragma mark ViewController lifecycle

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if(locMgr)
        [locMgr startUpdatingLocation];
    
    // try load pin
    [self loadJSONData];
    
    // observe device rotation
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(orientationChanged:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if(locMgr) // stop loc mgr
        [locMgr stopUpdatingLocation];
    
    // remove observer
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:UIDeviceOrientationDidChangeNotification
                                                  object:nil];
    
    [super viewWillDisappear:animated];
}

- (void)orientationChanged:(NSNotification *)notification
{
    if(locMgr)
        [self performSelector:@selector(updateMapRegion) withObject:nil afterDelay:1];
}



#pragma mark -
#pragma mark User Actions

- (IBAction)reloadData:(UIBarButtonItem *)sender
{
    [self loadJSONData];
}



#pragma mark -
#pragma mark Network & convert

- (void)loadJSONData
{
    self.title = @"wczytywanie...";
    
    NSURL *url = [NSURL URLWithString:@JSON_URL];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:[NSOperationQueue mainQueue]
                           completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
       
        if(!connectionError && data.length > 0){
            // convert to dict
            NSDictionary *d = [self convertDataToDict:data];

            if(d){
                // clear map
                [self.mapView removeAnnotations:self.mapView.annotations];
                
                // put pin
                [self putPinOnMap:d];
                
                // init location manager
                if(!locMgr){
                    locMgr = [CLLocationManager new];
                    locMgr.desiredAccuracy = kCLLocationAccuracyHundredMeters;
                    locMgr.pausesLocationUpdatesAutomatically = YES;
                    [locMgr setDelegate:self];
                    [locMgr startUpdatingLocation];
                }
                else{
                    [self checkLocationServices];
                }
            }
        }
        else{
            NSLog(@"Problem with internet connection: %@", connectionError.localizedDescription);
            
            self.title = @"offline :(";
        }
    }];
}

- (CLLocationCoordinate2D)getCoordinateFromDict:(NSDictionary *)dict
{
    CLLocationCoordinate2D coord = CLLocationCoordinate2DMake(0, 0);
    
    // get location data
    NSDictionary *locationD = (NSDictionary *)[dict objectForKey:@"location"];
    NSNumber *lat = [locationD objectForKey:@"latitude"];
    NSNumber *lng = [locationD objectForKey:@"longitude"];
    
    if(lat && lng){
        // make coords
        coord = CLLocationCoordinate2DMake([lat doubleValue], [lng doubleValue]);
    }
    
    
    return coord;
}

- (NSDictionary *)convertDataToDict:(NSData *)data
{
    NSDictionary *dict = nil;
    
    if(data){
        NSError *error;
        dict = [NSJSONSerialization JSONObjectWithData:data
                                               options:kNilOptions
                                                 error:&error];
        
        if(error)
            NSLog(@"Problem with json: %@", error.localizedDescription);
    }
    
    return dict;
}



#pragma mark -
#pragma mark Location Manager delegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    CLLocation *newLocation = [locations lastObject];
    
    [self updateMapRegion];
    
    [self calcDistanceBetweenAnnotationAndUserLocaton:newLocation];
}

- (void)checkLocationServices
{
    // check location services
    BOOL locationServEnabled = [CLLocationManager locationServicesEnabled];
    CLAuthorizationStatus gpsAuthStatus = [CLLocationManager authorizationStatus];
    
    if(!locationServEnabled || gpsAuthStatus == kCLAuthorizationStatusDenied){
        
        // show alert
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:@"Aplikacja nie posiada uprawnień lokalizacyjnych, lub masz wyłączony moduł GPS (Ustawienia / Prywatność / Usługi lokalizacji)" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        
        [alert show];
    }
}



#pragma mark -
#pragma mark Calculations

- (void)calcDistanceBetweenAnnotationAndUserLocaton:(CLLocation *)userLocation
{
    // get map annotation coord
    MyAnnotation *annotationOnMap = nil;
    
    for (id a in self.mapView.annotations) {
        if([a isKindOfClass:[MyAnnotation class]])
            annotationOnMap = a;
    }
    
    if(!annotationOnMap || !userLocation){
        self.title = @"problem z GPS";
        return;
    }
    
    
    CLLocationCoordinate2D c = annotationOnMap.coordinate;
    
    // calc distance
    CLLocation *pinLocation = [[CLLocation alloc] initWithLatitude:c.latitude longitude:c.longitude];
    
    double dist = [userLocation distanceFromLocation:pinLocation];
    dist /= 1000.0f;
    
    // set viewcontroller title
    self.title = [NSString stringWithFormat:@"odległość do punktu: %.2f km", dist];
}



#pragma mark -
#pragma mark Actions On map

- (void)putPinOnMap:(NSDictionary *)dict
{
    // get coordinate
    CLLocationCoordinate2D c = [self getCoordinateFromDict:dict];
    
    NSString *name = [dict valueForKey:@"text"];
    NSURL *url = [NSURL URLWithString:[dict valueForKey:@"image"]];
    
    // add annotation
    MyAnnotation *annotation = [[MyAnnotation alloc] initWithName:name
                                                       coordinate:c
                                                           imgURL:url];
    [self.mapView addAnnotation:annotation];
    
    // update map region
    [self updateMapRegion];
    
    // dont wait for locMgr now!
    [self calcDistanceBetweenAnnotationAndUserLocaton:self.mapView.userLocation.location];
}

- (void)updateMapRegion
{
    if(self.mapView.annotations.count){
        
        MKMapPoint *points = malloc(sizeof(MKMapPoint) * self.mapView.annotations.count);
        double ax = INFINITY, ay = INFINITY, bx = -INFINITY, by = -INFINITY;
        
        int i = 0;
        for (MKAnnotationView *annotation in self.mapView.annotations) {
            CLLocationCoordinate2D aCoord = ([annotation isKindOfClass:[MyAnnotation class]]) ? [(MyAnnotation *)annotation coordinate] : locMgr.location.coordinate;
            
            MKMapPoint mp = MKMapPointForCoordinate(CLLocationCoordinate2DMake(aCoord.latitude, aCoord.longitude));
            
            points[i++] = mp;
            
            if (mp.x < ax)
                ax = mp.x;
            if (mp.x > bx)
                bx = mp.x;
            if (mp.y < ay)
                ay = mp.y;
            if (mp.y > by)
                by = mp.y;
        }
        
        // set region to zoom in
        float marginX = (bx-ax) * .1f;
        float marginY = (by-ay) * .1f;
        
        MKMapRect mr = MKMapRectMake(ax - marginX, ay - marginY, bx-ax + 2*marginX, by-ay + 2*marginY);
        [self.mapView setRegion:MKCoordinateRegionForMapRect(mr) animated:YES];
    }
}



#pragma mark -
#pragma mark Map annotations

- (MKAnnotationView *)mapView:(MKMapView *)mapView viewForAnnotation:(id<MKAnnotation>)annotation
{
    MKAnnotationView *pinView = nil;
    
    if([annotation isKindOfClass:[MyAnnotation class]]){
        static NSString *defaultPinID = @"pin";
        
        pinView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:defaultPinID];
        if (pinView == nil)
            pinView = [[MKAnnotationView alloc]
                       initWithAnnotation:annotation reuseIdentifier:defaultPinID];
        
        MyAnnotation *a = (MyAnnotation *)annotation;
        pinView.annotation = a;
        pinView.image = [UIImage imageNamed:@"pinezka_ciekawemiejsce.png"];
        
        [pinView setCanShowCallout:YES];
    }
    
    return pinView;
}

- (void)mapView:(MKMapView *)mapView didAddAnnotationViews:(NSArray *)annotationViews
{
    for (MKAnnotationView *annView in annotationViews){
        CGRect endFrame = annView.frame;
        
        annView.frame = CGRectOffset(endFrame, 0, -500);
        [UIView animateWithDuration:0.5
                         animations:^{ annView.frame = endFrame; }];
    }
}

- (void)mapView:(MKMapView *)mapView didSelectAnnotationView:(MKAnnotationView *)view
{
    if([view.annotation isKindOfClass:[MyAnnotation class]]){
        MyAnnotation *a = view.annotation;
        
        // get img url
        NSURL *imgURL = a.url;
        
        // init & send request
        NSURLRequest *request = [NSURLRequest requestWithURL:imgURL];
        
        __block MKAnnotationView *aView = view;
        [NSURLConnection sendAsynchronousRequest:request
                                           queue:[NSOperationQueue mainQueue]
                               completionHandler:^(NSURLResponse *response, NSData *data, NSError *connectionError) {
            
            if(!connectionError && data.length > 0){
                // get img from data
                UIImage *img = [UIImage imageWithData:data];
                
                if(img){
                    // init img view
                    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
                    imageView.image = img;
                    
                    // set img view as left accessory view
                    dispatch_async(dispatch_get_main_queue(), ^{
                        aView.leftCalloutAccessoryView = imageView;
                    });
                }
            }
            else
                NSLog(@"Problem with internet connection: %@", connectionError.localizedDescription);
        }];
    }
}

@end
