//
//  AppNativeInterface.h
//  MyApp
//
//  Created by ceramic.
//  Copyright © 2018 My Company. All rights reserved.
//

#import <UIKit/UIKit.h>

/** Example of callback type specified with a typedef */
typedef void (^Callback)(void);

/**
 Example of native iOS code.
 In order to use this code from Haxe, add this in ceramic.yml:
 
 ```
 'if ios':
      +bind:
          - 'AppNativeInterface.h'
      +hooks:
          - when: begin build
            command: ceramic
            args: ['ios', 'bind']
 ```
 
 Then run `ceramic ios bind` to make the interface available through ios.AppNativeInterface Haxe module.
 */
@interface AppNativeInterface : NSObject

/** Get shared instance */
+ (instancetype)sharedInterface;

/** If provided, will be called when root view controller is visible on screen */
@property (nonatomic, copy) void (^viewDidAppear)(BOOL animated);

/** Last name. If provided, will be used when saying hello. */
@property (nonatomic, strong) NSString *lastName;

/** Say hello to `name` with a native iOS dialog. Add a last name if any is known. */
- (void)hello:(NSString *)name done:(Callback)done;

/** Get iOS version string */
- (NSString *)iosVersionString;

/** Get iOS version number */
- (CGFloat)iosVersionNumber;

/** Dummy method to get Haxe types converted to ObjC types that then get returned back as an array. */
- (NSArray *)testTypes:(BOOL)aBool anInt:(NSInteger)anInt aFloat:(CGFloat)aFloat anArray:(NSArray *)anArray aDict:(NSDictionary *)aDict;

@end

