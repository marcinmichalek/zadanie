//
//  MapViewController.m
//  zadanie
//
//  Created by Marcin Michałek on 22.07.2014.
//  Copyright (c) 2014 mm. All rights reserved.
//

#import "MapViewController.h"
#import "MyAnnotation.h"
#import <RestKit/RestKit.h>

#define JSON_URL "https://dl.dropboxusercontent.com/u/6556265/test.json"
#define USER_PIN_TAG [NSNumber numberWithInt:1]
#define LOCATION_PIN_TAG [NSNumber numberWithInt:2]


@interface MapViewController ()

@end

@implementation MapViewController

#pragma mark -
#pragma mark ViewController lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    // init location manager
    if(!locMgr){
        locMgr = [CLLocationManager new];
        locMgr.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        locMgr.pausesLocationUpdatesAutomatically = YES;
        [locMgr setDelegate:self];
        [locMgr startUpdatingLocation];
    }
//    else{
//        [self checkLocationServices];
//    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    // try load pin
    [self loadJSONData];
}

- (void)viewWillDisappear:(BOOL)animated
{
    if(locMgr) // stop loc mgr
        [locMgr stopUpdatingLocation];
    
    [super viewWillDisappear:animated];
}

-(void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    if(locMgr)
        [self performSelector:@selector(updateMapRegion) withObject:nil afterDelay:1];
}



#pragma mark -
#pragma mark User Actions

- (IBAction)reloadData:(UIBarButtonItem *)sender
{
    gpsFix = NO;
    
    [self loadJSONData];
}



#pragma mark -
#pragma mark Network & convert

- (void)loadJSONData
{
    self.title = NSLocalizedString(@"LOADING", nil);
    
    
    // get json from server
    AFHTTPClient *httpClient = [[AFHTTPClient alloc] initWithBaseURL:[NSURL URLWithString:@"https://dl.dropboxusercontent.com/"]];
    NSMutableURLRequest *request = [httpClient requestWithMethod:@"GET"
                                                            path:@JSON_URL
                                                      parameters:nil];
    AFHTTPRequestOperation *operation = [[AFHTTPRequestOperation alloc] initWithRequest:request];
    [httpClient registerHTTPOperationClass:[AFHTTPRequestOperation class]];
    [operation setCompletionBlockWithSuccess:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSLog(@"Response: %@", [[NSString alloc] initWithData:responseObject encoding:NSUTF8StringEncoding]);
        
        // convert to dict
        NSDictionary *d = [self convertDataToDict:responseObject];
        
        if(d){
            // remove old pin
            [self removeAnnotationFromMapWithTag:LOCATION_PIN_TAG];
            
            [self.mapView removeOverlays:self.mapView.overlays];
            
            // put pin
            [self putPinOnMap:d withTag:LOCATION_PIN_TAG];
        }
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"%@: %@", NSLocalizedString(@"INTERNET_CONNECTION_PROBLEM_LOG", nil), error.localizedDescription);
        
        self.title = NSLocalizedString(@"OFFLINE", nil);
    }];
    
    [operation start];
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
            NSLog(@"%@: %@", NSLocalizedString(@"JSON_DECODE_PROBLEM_LOG", nil) ,error.localizedDescription);
    }
    
    return dict;
}



#pragma mark -
#pragma mark Location Manager delegate methods

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    if(!gpsFix){
        gpsFix = YES;
        
        // remove old user pin
        [self removeAnnotationFromMapWithTag:USER_PIN_TAG];
        
        CLLocation *newLocation = [locations lastObject];
        lastUserLocation = newLocation;
        
        // put pin with user location
        NSMutableDictionary *userLocationDict = [[NSMutableDictionary alloc] init];
        NSDictionary *locationD = [NSDictionary dictionaryWithObjectsAndKeys:[NSNumber numberWithDouble:newLocation.coordinate.latitude], @"latitude", [NSNumber numberWithDouble:newLocation.coordinate.longitude], @"longitude", nil];
        [userLocationDict setObject:locationD forKey:@"location"];
        [userLocationDict setValue:NSLocalizedString(@"USER_LOCATION", nil) forKey:@"text"];
        
        [self putPinOnMap:userLocationDict withTag:USER_PIN_TAG];
    }
}

- (void)checkLocationServices
{
    // check location services
    BOOL locationServEnabled = [CLLocationManager locationServicesEnabled];
    CLAuthorizationStatus gpsAuthStatus = [CLLocationManager authorizationStatus];
    
    if(!locationServEnabled || gpsAuthStatus == kCLAuthorizationStatusDenied){
        
        NSString *msg = NSLocalizedString(@"LOCATION_SERVICES_AUTH_ALERT", nil);
        // show alert
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"" message:msg delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
        
        [alert show];
    }
}



#pragma mark -
#pragma mark Calculations

- (void)calcDistanceBetweenAnnotationAndUserLocaton:(CLLocation *)userLocation
{
    // get map annotation coord
    MyAnnotation *annotationOnMap = nil;
    
    for (MyAnnotation *a in self.mapView.annotations) {
        if(a.tag == LOCATION_PIN_TAG)
            annotationOnMap = a;
    }
    
    if(!annotationOnMap)
        return;
    
    if(!userLocation){
        self.title = NSLocalizedString(@"GPS_PROBLEM", nil);
        return;
    }
    
    
    CLLocationCoordinate2D c = annotationOnMap.coordinate;
    
    // calc distance
    CLLocation *pinLocation = [[CLLocation alloc] initWithLatitude:c.latitude longitude:c.longitude];
    
    double dist = [userLocation distanceFromLocation:pinLocation];
    dist /= 1000.0f;
    
    // set viewcontroller title
    self.title = [NSString stringWithFormat:@"%@: %.2f km", NSLocalizedString(@"DISTANCE", nil), dist];
}



#pragma mark -
#pragma mark Actions On map

- (void)putPinOnMap:(NSDictionary *)dict withTag:(NSNumber*)tag
{
    // get coordinate
    CLLocationCoordinate2D c = [self getCoordinateFromDict:dict];
    
    NSString *name = [dict valueForKey:@"text"];
    NSString *imgURL = [dict valueForKey:@"image"];
    
    NSURL *url = nil;
    if(imgURL.length > 0)
        url = [NSURL URLWithString:imgURL];
    
    // add annotation
    MyAnnotation *annotation = [[MyAnnotation alloc] initWithName:name
                                                       coordinate:c
                                                           imgURL:url
                                                           andTag:tag];
    [self.mapView addAnnotation:annotation];
    
    // update map region
    [self updateMapRegion];
    
    // dont wait for locMgr now!
    [self calcDistanceBetweenAnnotationAndUserLocaton:lastUserLocation];
    
    
    // draw line between points
    CLLocation *pinLocation = nil;
    if(self.mapView.annotations.count == 2){
        
        for (MyAnnotation *a in self.mapView.annotations) {
            if(a.tag == LOCATION_PIN_TAG){
                pinLocation = [[CLLocation alloc] initWithLatitude:a.coordinate.latitude longitude:a.coordinate.longitude];
                break;
            }
        }
    
        if(pinLocation)
            [self drawLineFromPoint:lastUserLocation toPoint:pinLocation withTitle:NSLocalizedString(@"DISTANCE", nil)];
    }
}

- (void)removeAnnotationFromMapWithTag:(NSNumber *)tag
{
    for (int i = 0; i < self.mapView.annotations.count; i++) {
        
        MyAnnotation *a = [self.mapView.annotations objectAtIndex:i];
        if(a.tag == tag)
            [self.mapView removeAnnotation:a];
    }
}

- (void)drawLineFromPoint:(CLLocation*)startPoint toPoint:(CLLocation*)endPoint withTitle:(NSString*)title
{
    MKMapPoint start = MKMapPointForCoordinate(startPoint.coordinate);
    MKMapPoint end = MKMapPointForCoordinate(endPoint.coordinate);
    
    
    MKMapPoint *points = malloc(sizeof(MKMapPoint) * 2);
    points[0] = start;
    points[1] = end;
    
    MKPolyline *line = [MKPolyline polylineWithPoints:points count:2];
    free(points);
    
    [self.mapView addOverlay:line];
}

- (void)updateMapRegion
{
    if(self.mapView.annotations.count){
        
        MKMapPoint *points = malloc(sizeof(MKMapPoint) * self.mapView.annotations.count);
        double ax = INFINITY, ay = INFINITY, bx = -INFINITY, by = -INFINITY;
        
        int i = 0;
        for (MKAnnotationView *annotation in self.mapView.annotations) {
            CLLocationCoordinate2D aCoord = ([(MyAnnotation*)annotation tag] == LOCATION_PIN_TAG) ? [(MyAnnotation *)annotation coordinate] : lastUserLocation.coordinate;
            
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
    BOOL userPin = ([(MyAnnotation*)annotation tag] == USER_PIN_TAG);
    
    NSString *pinID = (userPin) ? @"userPin" : @"locationPin";
    
    MKAnnotationView *pinView = (MKAnnotationView *)[mapView dequeueReusableAnnotationViewWithIdentifier:pinID];
    if (pinView == nil)
        pinView = [[MKAnnotationView alloc]
                   initWithAnnotation:annotation reuseIdentifier:pinID];
    
    MyAnnotation *a = (MyAnnotation *)annotation;
    pinView.annotation = a;
    pinView.canShowCallout = YES;
    pinView.image = (userPin) ? [UIImage imageNamed:@"pinezka_uzytkownik.png"] : [UIImage imageNamed:@"pinezka_ciekawemiejsce.png"];
    
    
    
    return pinView;
}

- (MKOverlayView *)mapView:(MKMapView *)mapView viewForOverlay:(id )overlay
{
    MKPolylineView *view = [[MKPolylineView alloc] initWithPolyline:overlay];
    view.strokeColor = [UIColor colorWithRed:0.0 green:127.0/255.0 blue:255.0/255.0 alpha:1];
    view.lineCap = kCGLineCapRound;
    view.lineWidth = 6;
    
    return view;
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
        
        if(imgURL){
            
            // get image and add it to pin
            __block MKAnnotationView *aView = view;
            
            NSURLRequest *request = [NSURLRequest requestWithURL:imgURL];
            AFImageRequestOperation *operation;
            operation = [AFImageRequestOperation imageRequestOperationWithRequest:request
                                                             imageProcessingBlock:nil
                                                                          success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
                if(image){
                    // init img view
                    UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 32, 32)];
                    imageView.image = image;
                    
                    // set img view as left accessory view
                    dispatch_async(dispatch_get_main_queue(), ^{
                        aView.leftCalloutAccessoryView = imageView;
                    });
                }
                
            } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
                NSLog(@"%@: %@", NSLocalizedString(@"INTERNET_CONNECTION_PROBLEM_LOG", nil), error.localizedDescription);
            }];
            
            [operation start];
        }
    }
}

@end
