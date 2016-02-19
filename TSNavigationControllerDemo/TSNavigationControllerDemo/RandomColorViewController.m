//
//  RandomColorViewController.m
//  TSNavigationControllerDemo
//
//  Created by TragedyStar on 16/2/19.
//  Copyright © 2016年 TS. All rights reserved.
//

#import "RandomColorViewController.h"
#import "TSNavigationController.h"

@interface RandomColorViewController ()

@end

@implementation RandomColorViewController

- (void)viewDidLoad {
    [super viewDidLoad];

    // 设置view背景色
    self.view.backgroundColor = [UIColor colorWithRed:(arc4random()%256)/255.0f
                                                green:(arc4random()%256)/255.0f
                                                 blue:(arc4random()%256)/255.0f
                                                alpha:1.0f];
}

- (IBAction)push:(id)sender {

    if (self.navigationController.viewControllers.count == 6){
        
        [self.navigationController popViewControllerAnimated:NO];
//        [self.navigationController popToRootViewControllerAnimated:YES];
//        [self.navigationController popToViewController:self.navigationController.viewControllers[0] animated:YES];
    }else{
        
        RandomColorViewController *vc = [[RandomColorViewController alloc] init];
        
        if (self.navigationController.viewControllers.count == 1) {
            vc.hidesTabBarWhenPushed = YES;
        }
        
        if (self.navigationController.viewControllers.count == 2) {
            vc.hidesTabBarWhenPushed = NO; //此处意思是当push时不执行隐藏tabBar的操作，故已隐藏的tabBar不会重新显示出来
        }
        
        if (self.navigationController.viewControllers.count == 3) {
            vc.viewControllerToPop = self.navigationController.viewControllers[0];
        }
        
        if (self.navigationController.viewControllers.count == 4) {
            vc.prefersNavigationBarHidden = YES;
//            vc.viewControllerToPop = self.navigationController.viewControllers[1];
        }
        
        if (self.navigationController.viewControllers.count == 5){
            vc.prefersNavigationBarHidden = YES;
            vc.viewControllerToPop = self.navigationController.viewControllers.firstObject;
        }
        
        [self.navigationController pushViewController:vc  animated:YES];
    }
    
    
}

@end
