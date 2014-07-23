//
//  MapViewController.h
//  zadanie
//
//  Created by Marcin Michałek on 22.07.2014.
//  Copyright (c) 2014 mm. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <MapKit/MapKit.h>

@interface MapViewController : UIViewController <MKMapViewDelegate, CLLocationManagerDelegate>
{
    CLLocationManager *locMgr;
    
    BOOL gpsFix;
    
    CLLocation *lastUserLocation;
}

@property (weak, nonatomic) IBOutlet MKMapView *mapView;

@end
