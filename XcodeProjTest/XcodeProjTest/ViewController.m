//
//  ViewController.m
//  XcodeProjTest
//
//  Created by 朱天超 on 2017/7/7.
//  Copyright © 2017年 朱天超. All rights reserved.
//

#import "ViewController.h"
#import "XcodeProjLibA.h"
//#import "XcodeProjLibB.h"
@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    NSLog(@"%@",[XcodeProjLibA version]);
//    NSLog(@"%@",[XcodeProjLibB version]);
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
