//
//  TSNavigationController.h
//  TSNavigationController
//
//  Created by TragedyStar on 16/2/19.
//  Copyright © 2016年 TS. All rights reserved.
//

#import <UIKit/UIKit.h>

#define TSAnimationDuration     0.5f
#define TSMinX                  (0.5f * [UIScreen mainScreen].bounds.size.width)

@interface TSNavigationController : UINavigationController

/*
 *  If YES, disable the drag pop function. Default is NO.
 */
@property (nonatomic, assign) BOOL disableDragPop;

/*
 *  If YES, will pop view controller with spring animation effect. Default is NO.
 */
@property (nonatomic, assign, getter=isSpringAnimated) BOOL springAnimated;

@end



@interface UIViewController (TSNavigationController)

/*
 *  If NO, disable the drag pop function in this view controller. Default is YES.
 */
@property (nonatomic, assign) BOOL enableDragPop;

/*
 *  The view controller that you want to pop to.
 *  Nullable. If nil, navigationController will pop to the last controller in the stack.
 *  If the view controller is not in the stack, pop will do not work.
 */
@property (nonatomic, weak, nullable) UIViewController *viewControllerToPop;

/*
 *  Hide navigationBar in this viewController. Default is NO.
 */
@property (nonatomic, assign) BOOL prefersNavigationBarHidden;

/*
 *  If YES, then when this view controller is pushed into a controller hierarchy with a tab bar, the tab bar will hide.
 *  Default is NO.
 */
@property (nonatomic, assign) BOOL hidesTabBarWhenPushed;

/*
 *  The last view controller in the navigaiton controller's stack which this view controller is in.
 */
@property (nonatomic, readonly, weak)  UIViewController * _Nullable lastViewControllerInStack;

/*
 *  The first view controller in the navigaiton controller's stack which this view controller is in.
 */
@property (nonatomic, readonly, weak) UIViewController * _Nullable rootViewControllerInStack;

@end