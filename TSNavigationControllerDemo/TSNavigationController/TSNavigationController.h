//
//  ATNavigationController.h
//  YAMI
//
//  Created by 林涛 on 15/1/24.
//  Copyright (c) 2015年 Summer. All rights reserved.
//

#import <UIKit/UIKit.h>

#define TSAnimationDuration     0.5f
#define TSMinX                  (0.5f * [UIScreen mainScreen].bounds.size.width)

@interface TSNavigationController : UINavigationController
/**
 *  If yes, disable the drag back, default is NO.
 */
@property (nonatomic, assign) BOOL disableDragBack;

@end

@interface UIViewController (TSNavigationController)
/*
 *  The ViewController that you want to pop to.
 *  Nullable.If nil,navigationController will pop to the last controller in the stack.
 *  If the view controller is not in the stack,pop will do not work.
 */
@property (nonatomic, strong) UIViewController *viewControllerToPop;
/*
 *  Hide navigationBar in this viewController.Default is NO.
 */
@property (nonatomic, assign) BOOL prefersNavigationBarHidden;
/*
 *  If YES, then when this view controller is pushed into a controller hierarchy with a tab bar,the tab bar will hide.
 *  Default is NO.
 */
@property (nonatomic, assign) BOOL hidesTabBarWhenPushed;

@end