//
//  MyAnnotation.h
//  zadanie
//
//  Created by Marcin Michałek on 22.07.2014.
//  Copyright (c) 2014 mm. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <MapKit/MapKit.h>

@interface MyAnnotation : NSObject <MKAnnotation>

@property (strong, nonatomic, readonly) NSURL *url;
@property (strong, nonatomic, readonly) NSNumber *tag;

- (id)initWithName:(NSString*)name coordinate:(CLLocationCoordinate2D)coordinate imgURL:(NSURL *)url andTag:(NSNumber*)tag;

@end

