//
//  AppNativeInterface.m
//
//  Created by ceramic.
//  Copyright © 2018 My Company. All rights reserved.
//

#import "AppNativeInterface.h"

@implementation AppNativeInterface

+ (instancetype)sharedInterface {
    
    static id instance;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        instance = [[self alloc] init];
    });
    
    return instance;
    
} //sharedInterface

- (void)hello:(NSString *)name done:(Callback)done {
    
    NSString *sentence = [NSString stringWithFormat:@"Hello %@", name];
    
    if (_lastName) {
        sentence = [NSString stringWithFormat:@"%@ %@", sentence, _lastName];
    }
    
    UIAlertController *alert = [UIAlertController
                                alertControllerWithTitle:@"Native iOS (ObjC)"
                                message:sentence
                                preferredStyle:UIAlertControllerStyleAlert];
    
    [alert addAction:[UIAlertAction
                      actionWithTitle:@"OK"
                      style:UIAlertActionStyleDefault
                      handler:^(UIAlertAction * action) {
                          // Pressed `OK`
                          if (done) done();
                      }]];
    
    UIViewController *viewController = [[UIApplication sharedApplication] keyWindow].rootViewController;
    [viewController presentViewController:alert animated:YES completion:nil];
    
} //hello

- (NSString *)iosVersionString {
    
    return [[UIDevice currentDevice] systemVersion];
    
} //iosVersionString

/** Get iOS version number */
- (CGFloat)iosVersionNumber {
    
    return [[[UIDevice currentDevice] systemVersion] floatValue];
    
} //iosVersionNumber

/** Dummy method to get Haxe types converted to ObjC types that then get returned back as an dictionary. */
- (NSArray *)testTypes:(BOOL)aBool anInt:(NSInteger)anInt aFloat:(CGFloat)aFloat anArray:(NSArray *)anArray aDict:(NSDictionary *)aDict {
    
    NSLog(@"Objective-C types:");
    NSLog(@"  Bool: %@", @(aBool));
    NSLog(@"  Int: %@", @(anInt));
    NSLog(@"  Float: %@", @(aFloat));
    NSLog(@"  Array: %@", anArray);
    NSLog(@"  Dict: %@", aDict);
    
    return @[aBool ? @YES : @NO,
             @(anInt),
             @(aFloat),
             anArray ? anArray : [NSNull null],
             aDict ? aDict : [NSNull null]];
    
} //testTypes

@end

