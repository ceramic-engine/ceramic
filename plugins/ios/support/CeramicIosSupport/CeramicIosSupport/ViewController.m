//
//  ViewController.m
//  CeramicIosSupport
//
//  Created by Jeremy FAIVRE on 27/09/2018.
//  Copyright © 2018 Ceramic. All rights reserved.
//

#import "ViewController.h"

#import "Http.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)viewDidAppear:(BOOL)animated {
    
    [super viewDidAppear:animated];
    
    /*// Test HTTP
    //
    NSLog(@"Test HTTP Request...");
    [Http sendHTTPRequest:@{
                            @"url": @"https://github.com/ceramic-engine/ceramic"
                            } done:^(NSDictionary *response) {
                                NSLog(@"status: %@", response[@"status"]);
                                NSLog(@"error: %@", response[@"error"]);
                                NSLog(@"headers: %@", response[@"headers"]);
                                NSLog(@"content: %@", response[@"content"]);
    }];*/
    
    NSLog(@"Test HTTP Download...");
    [Http download:@{
                     @"url": @"http://lorempixel.com/1920/1920/abstract/"
                     } targetPath:@"someFile.jpg" done:^(NSString *fullPath) {
        // Result
        NSLog(@"Result: %@", fullPath);
    }];
    
}

@end
