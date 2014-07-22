//
//  MyAnnotation.m
//  zadanie
//
//  Created by Marcin Michałek on 22.07.2014.
//  Copyright (c) 2014 mm. All rights reserved.
//

#import "MyAnnotation.h"

@interface MyAnnotation ()
@property (nonatomic, copy) NSString *name;
@property (nonatomic, assign) CLLocationCoordinate2D theCoordinate;
@end

@implementation MyAnnotation

- (id)initWithName:(NSString*)name coordinate:(CLLocationCoordinate2D)coordinate imgURL:(NSURL *)url {
    
    if ((self = [super init])) {
        _name = name;
        _theCoordinate = coordinate;
        _url = url;
    }
    
    return self;
}

- (NSString *)title
{
    return _name;
}

- (NSString *)subtitle
{
    CLLocationCoordinate2D coords = [self coordinate];
    
    return [NSString stringWithFormat:@"lat:%f; lng:%f", coords.latitude, coords.longitude];
}

- (CLLocationCoordinate2D)coordinate
{
    return _theCoordinate;
}

- (NSURL *)imageURL
{
    return _url;
}

@end
