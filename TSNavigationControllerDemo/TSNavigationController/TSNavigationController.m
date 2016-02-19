//
//  ATNavigationController.m
//  AT
//
//  Created by CoderAT on 15/1/24.
//  Copyright (c) 2015年 AT. All rights reserved.
//

#import "TSNavigationController.h"
#import <objc/runtime.h>

#define enableDrag (self.viewControllers.count > 1 && !self.disableDragBack)

#define TSKeyWindow     [[UIApplication sharedApplication] keyWindow]
#define TSNavViewW      [UIScreen mainScreen].bounds.size.width

typedef NS_ENUM(int, ATNavMovingStateEnumes) {
    ATNavMovingStateStanby = 0,
    ATNavMovingStateDragBegan,
    ATNavMovingStateDragChanged,
    ATNavMovingStateDragEnd,
    ATNavMovingStateDecelerating,
};
@interface TSNavigationController () <UIGestureRecognizerDelegate>
/**
 *  黑色的蒙板
 */
@property (nonatomic, strong) UIView *lastScreenBlackMask;
/**
 *  显示上一个界面的截屏
 */
@property (nonatomic, strong) UIImageView *lastScreenShotView;
/**
 *  显示上一个界面的截屏黑色背景
 */
@property (nonatomic,retain) UIView *backgroundView;
/**
 *  存放截屏的字典数组 key：控制器指针字符串  value：截屏图片
 */
@property (nonatomic,retain) NSMutableDictionary *screenShotsDict;
/**
 *  正在移动
 */
@property (nonatomic,assign) ATNavMovingStateEnumes movingState;

@end

@implementation TSNavigationController

#pragma -mark 懒加载
- (NSMutableDictionary *)screenShotsDict {
    if (_screenShotsDict == nil) {
        _screenShotsDict = [NSMutableDictionary dictionary];
    }
    return _screenShotsDict;
}
- (UIView *)backgroundView {
    if (_backgroundView == nil) {
        _backgroundView = [[UIView alloc]initWithFrame:self.view.bounds];
        _backgroundView.backgroundColor = [UIColor blackColor];
        
        _lastScreenShotView = [[UIImageView alloc] initWithFrame:_backgroundView.bounds];
        _lastScreenShotView.backgroundColor = [UIColor whiteColor];
        [_backgroundView addSubview:_lastScreenShotView];
        
        _lastScreenBlackMask = [[UIView alloc] initWithFrame:_backgroundView.bounds];
        _lastScreenBlackMask.backgroundColor = [UIColor blackColor];
        [_backgroundView addSubview:_lastScreenBlackMask];
    }
    
    if (_backgroundView.superview == nil) {
        [self.view.superview insertSubview:_backgroundView belowSubview:self.view];
    }
    return _backgroundView;
}

#pragma -mark 生命周期
- (void)viewDidLoad
{
    [super viewDidLoad];
    // 为导航控制器view，添加拖拽手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] init];
    [pan addTarget:self action:@selector(paningGestureReceive:)];
    [pan setDelegate:self];
    [pan delaysTouchesBegan];
    [self.view addGestureRecognizer:pan];
    
    self.interactivePopGestureRecognizer.enabled = NO;
}

- (void)dealloc {
    self.screenShotsDict = nil;
    [self.backgroundView removeFromSuperview];
    self.backgroundView = nil;
}

#pragma mark - 截屏相关方法
/**
 *  当前导航栏界面截屏
 */
- (UIImage *)capture {
    UIView *view = self.view;
    if (self.tabBarController) {
        view = self.tabBarController.view;
    }
    UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0);
    [view.layer renderInContext:UIGraphicsGetCurrentContext()];
    UIImage * img = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return img;
}
/**
 *  得到OC对象的指针字符串
 */
- (NSString *)stringOfPointer:(id)objet {
    return [NSString stringWithFormat:@"%p", objet];
}
/**
 *  获取前一个界面的截屏
 */
- (UIImage *)lastScreenShot {
    UIViewController *lastVC = [self.viewControllers objectAtIndex:self.viewControllers.count - 2];
    
    return [self.screenShotsDict objectForKey:[self stringOfPointer:lastVC]];
}
/*
 *  获取当前页面要pop的viewController的截屏
 */
- (UIImage *)previousScreenShot{
    return [self.screenShotsDict objectForKey:[self stringOfPointer:self.topViewController.viewControllerToPop]];
}
/**
 *  获取指定界面的截屏
 */
- (UIImage *)screenShotOfViewController:(UIViewController *)viewController
{
    return [self.screenShotsDict objectForKey:[self stringOfPointer:viewController]];
}

#pragma mark - 监听导航栏栈控制器改变 截屏
/**
 *  push前添加当前界面截屏
 */
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    
    if (self.viewControllers.count > 0) {
        [self.screenShotsDict setObject:[self capture] forKey:[self stringOfPointer:self.topViewController]];
    }
    
    if (viewController.hidesTabBarWhenPushed)
    {
        self.tabBarController.tabBar.hidden = YES;
    }
    
    
    if (viewController.prefersNavigationBarHidden)
    {
        self.navigationBarHidden = YES;
    }else{
        self.navigationBarHidden = NO;
    }
    
    [super pushViewController:viewController animated:animated];
    
}
/**
 *  pop后移除当前界面截屏
 */
- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    
    __block UIViewController *poppedVC;
    if (animated) {
        self.backgroundView.hidden = NO;
//        self.lastScreenShotView.image = [self lastScreenShot];
        if (self.topViewController.viewControllerToPop) {
            self.lastScreenShotView.image = [self previousScreenShot];
        }else{
            self.lastScreenShotView.image = [self lastScreenShot];
        }
        self.movingState = ATNavMovingStateDecelerating;
        self.lastScreenBlackMask.alpha = 0.6 * (1 - (0 / TSNavViewW));
        CGFloat scale = 0 / TSNavViewW * 0.05 + 0.9;
        self.lastScreenShotView.transform = CGAffineTransformMakeScale(scale, scale);
        
        [UIView animateWithDuration:0.5
                              delay:0
             usingSpringWithDamping:0.4
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [self moveViewWithX:TSNavViewW];
                         }
                         completion:^(BOOL finished) {
                             self.backgroundView.hidden = YES;

                             self.view.frame = (CGRect){ {0, self.view.frame.origin.y}, self.view.frame.size };
                             self.movingState = ATNavMovingStateStanby;
                             
                             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.3f) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                 // 移动键盘
                                 if (([[[UIDevice currentDevice] systemVersion] floatValue] >= 9)) {
                                     [[[UIApplication sharedApplication] windows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                         if ([obj isKindOfClass:NSClassFromString(@"UIRemoteKeyboardWindow")]) {
                                             [(UIWindow *)obj setTransform:CGAffineTransformIdentity];
                                         }
                                     }];
                                 }
                                 else {
                                     if ([[[UIApplication sharedApplication] windows] count] > 1) {
                                         [((UIWindow *)[[[UIApplication sharedApplication] windows] objectAtIndex:1]) setTransform:CGAffineTransformIdentity];
                                     }
                                 }
                             });
                             
                             
                             
                             if (self.topViewController.viewControllerToPop) {
                                 [self popToViewController:self.topViewController.viewControllerToPop animated:NO];
                             }else{
                                 UIViewController *lastVC = [self.viewControllers objectAtIndex:self.viewControllers.count - 2];
                                 if (lastVC.prefersNavigationBarHidden) {
                                     self.navigationBarHidden = YES;
                                 }else{
                                     self.navigationBarHidden = NO;
                                 }
                                 
                                 poppedVC = [super popViewControllerAnimated:NO];
                                 
                                 [self.screenShotsDict removeObjectForKey:[self stringOfPointer:self.topViewController]];
                                 
                                 if (poppedVC.hidesTabBarWhenPushed) {
                                     BOOL previousHide = NO;
                                     for (UIViewController *vc in self.viewControllers) {
                                         if (vc.hidesTabBarWhenPushed) {
                                             previousHide = YES;
                                             break; //之前的控制器只要有一个隐藏了tabBar，此处pop时就不管tabBar的显示了
                                         }
                                     }
                                     if (previousHide == NO) {
                                         self.tabBarController.tabBar.hidden = NO;
                                     }
                                 }
                             }
                         }];
    }else{
        if (self.topViewController.viewControllerToPop) {
            [self popToViewController:self.topViewController.viewControllerToPop animated:NO];
        }else{
            UIViewController *lastVC = [self.viewControllers objectAtIndex:self.viewControllers.count - 2];
            if (lastVC.prefersNavigationBarHidden) {
                self.navigationBarHidden = YES;
            }else{
                self.navigationBarHidden = NO;
            }
            
            poppedVC = [super popViewControllerAnimated:animated];
            [self.screenShotsDict removeObjectForKey:[self stringOfPointer:self.topViewController]];
            
            if (poppedVC.hidesTabBarWhenPushed) {
                
                BOOL previousHide = NO;
                for (UIViewController *vc in self.viewControllers) {
                    if (vc.hidesTabBarWhenPushed) {
                        previousHide = YES;
                        break;
                    }
                }
                if (previousHide == NO) {
                    self.tabBarController.tabBar.hidden = NO;
                }
                
            }
        }
    }
    
    return poppedVC;
}

//pop到指定界面需要移除相应的界面
- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    __block NSArray *poppedVCs;
    if (animated) {
        self.backgroundView.hidden = NO;
        self.lastScreenShotView.image = [self screenShotOfViewController:viewController];
        self.movingState = ATNavMovingStateDecelerating;
        self.lastScreenBlackMask.alpha = 0.6 * (1 - (0 / TSNavViewW));
        CGFloat scale = 0 / TSNavViewW * 0.05 + 0.9;
        self.lastScreenShotView.transform = CGAffineTransformMakeScale(scale, scale);
        
        [UIView animateWithDuration:0.5
                              delay:0
             usingSpringWithDamping:0.4
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [self moveViewWithX:TSNavViewW];
                         }
                         completion:^(BOOL finished) {
                             self.backgroundView.hidden = YES;
                             
                             self.view.frame = (CGRect){ {0, self.view.frame.origin.y}, self.view.frame.size };
                             self.movingState = ATNavMovingStateStanby;
                             
                             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.3f) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                 // 移动键盘
                                 if (([[[UIDevice currentDevice] systemVersion] floatValue] >= 9)) {
                                     [[[UIApplication sharedApplication] windows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                         if ([obj isKindOfClass:NSClassFromString(@"UIRemoteKeyboardWindow")]) {
                                             [(UIWindow *)obj setTransform:CGAffineTransformIdentity];
                                         }
                                     }];
                                 }
                                 else {
                                     if ([[[UIApplication sharedApplication] windows] count] > 1) {
                                         [((UIWindow *)[[[UIApplication sharedApplication] windows] objectAtIndex:1]) setTransform:CGAffineTransformIdentity];
                                     }
                                 }
                             });
                             
                             if (viewController.prefersNavigationBarHidden) {
                                 self.navigationBarHidden = YES;
                             }else{
                                 self.navigationBarHidden = NO;
                             }
                             
                             poppedVCs = [super popToViewController:viewController animated:NO];
                             for (UIViewController *vc in poppedVCs) {
                                 [self.screenShotsDict removeObjectForKey:[self stringOfPointer:vc]];
                             }
                             
                             
                             BOOL poppedVCsHideTabBar = NO;
                             for (UIViewController *vc in poppedVCs) {
                                 if (vc.hidesTabBarWhenPushed) {
                                     poppedVCsHideTabBar = YES;
                                     break;//pop出的控制器只要有一个隐藏了tabBar，就需要进一步判断之前的控制器是否隐藏tabBar
                                 }
                             }
                             if (poppedVCsHideTabBar) {
                                 
                                 BOOL previousHide = NO;
                                 for (UIViewController *vc in self.viewControllers) {
                                     if (vc.hidesTabBarWhenPushed) {
                                         previousHide = YES;
                                         break; //之前的控制器只要有一个隐藏了tabBar，此处pop时就不管tabBar的显示了
                                     }
                                 }
                                 if (previousHide == NO) {
                                     self.tabBarController.tabBar.hidden = NO;
                                 }
                                 
                             }
                         }];
    }else{
        if (viewController.prefersNavigationBarHidden) {
            self.navigationBarHidden = YES;
        }else{
            self.navigationBarHidden = NO;
        }
        
        poppedVCs = [super popToViewController:viewController animated:animated];
        for (UIViewController *vc in poppedVCs) {
            [self.screenShotsDict removeObjectForKey:[self stringOfPointer:vc]];
        }
        
        BOOL poppedVCsHideTabBar = NO;
        for (UIViewController *vc in poppedVCs) {
            if (vc.hidesTabBarWhenPushed) {
                poppedVCsHideTabBar = YES;
                break;
            }
        }
        if (poppedVCsHideTabBar) {
            
            BOOL previousHide = NO;
            for (UIViewController *vc in self.viewControllers) {
                if (vc.hidesTabBarWhenPushed) {
                    previousHide = YES;
                    break;
                }
            }
            if (previousHide == NO) {
                self.tabBarController.tabBar.hidden = NO;
            }
            
        }
    }
    
    return poppedVCs;
}

- (nullable NSArray<__kindof UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated
{
    if (self.viewControllers.count == 1) {
        return nil;
    }
    
    __block NSArray *poppedVCs;
    if (animated) {
        self.backgroundView.hidden = NO;
        self.lastScreenShotView.image = [self screenShotOfViewController:[self.viewControllers firstObject]];
        self.movingState = ATNavMovingStateDecelerating;
        self.lastScreenBlackMask.alpha = 0.6 * (1 - (0 / TSNavViewW));
        CGFloat scale = 0 / TSNavViewW * 0.05 + 0.9;
        self.lastScreenShotView.transform = CGAffineTransformMakeScale(scale, scale);
        
        [UIView animateWithDuration:0.5
                              delay:0
             usingSpringWithDamping:0.4
              initialSpringVelocity:0.5
                            options:UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             [self moveViewWithX:TSNavViewW];
                         }
                         completion:^(BOOL finished) {
                             self.backgroundView.hidden = YES;
                             
                             self.view.frame = (CGRect){ {0, self.view.frame.origin.y}, self.view.frame.size };
                             self.movingState = ATNavMovingStateStanby;
                             
                             dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.3f) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                                 // 移动键盘
                                 if (([[[UIDevice currentDevice] systemVersion] floatValue] >= 9)) {
                                     [[[UIApplication sharedApplication] windows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                         if ([obj isKindOfClass:NSClassFromString(@"UIRemoteKeyboardWindow")]) {
                                             [(UIWindow *)obj setTransform:CGAffineTransformIdentity];
                                         }
                                     }];
                                 }
                                 else {
                                     if ([[[UIApplication sharedApplication] windows] count] > 1) {
                                         [((UIWindow *)[[[UIApplication sharedApplication] windows] objectAtIndex:1]) setTransform:CGAffineTransformIdentity];
                                     }
                                 }
                             });
                             
                             UIViewController *rootVC = self.viewControllers.firstObject;
                             if (rootVC.prefersNavigationBarHidden) {
                                 self.navigationBarHidden = YES;
                             }else{
                                 self.navigationBarHidden = NO;
                             }
                             
                             
                             poppedVCs = [super popToRootViewControllerAnimated:NO];
                             for (UIViewController *vc in poppedVCs) {
                                 [self.screenShotsDict removeObjectForKey:[self stringOfPointer:vc]];
                             }
                             
                             if (!rootVC.hidesTabBarWhenPushed) {
                                 
                                self.tabBarController.tabBar.hidden = NO;
                                 
                             }
                         }];
    }else{
        
        UIViewController *rootVC = self.viewControllers.firstObject;
        if (rootVC.prefersNavigationBarHidden) {
            self.navigationBarHidden = YES;
        }else{
            self.navigationBarHidden = NO;
        }
        
        poppedVCs = [super popToRootViewControllerAnimated:animated];
        for (UIViewController *vc in poppedVCs) {
            [self.screenShotsDict removeObjectForKey:[self stringOfPointer:vc]];
        }
        
        if (!rootVC.hidesTabBarWhenPushed) {
            
            self.tabBarController.tabBar.hidden = NO;
            
        }
    }
    
    return poppedVCs;
}

/**
 *  重置界面的截屏(新增了界面会缺失截屏)
 */
- (void)setViewControllers:(NSArray *)viewControllers animated:(BOOL)animated
{
    if ([viewControllers containsObject:self.topViewController]) {
        [self.screenShotsDict setObject:[self capture] forKey:[self stringOfPointer:self.topViewController]];
    }
    [super setViewControllers:viewControllers animated:animated];
    
    NSMutableDictionary *newDic = [NSMutableDictionary dictionary];
    for (UIViewController *vc in viewControllers) {
        id obj = [self.screenShotsDict objectForKey:[self stringOfPointer:vc]];
        if (obj) {
            [newDic setObject:obj forKey:[self stringOfPointer:vc]];
        }
    }
    self.screenShotsDict = newDic;
}

#pragma mark - 拖拽移动界面
- (void)moveViewWithX:(float)x
{
    // 设置水平位移在 [0, ATNavViewW] 之间
    x = MAX(MIN(x, TSNavViewW), 0);
    // 设置frame的x
    self.view.frame = (CGRect){ {x, self.view.frame.origin.y}, self.view.frame.size};
    // 设置黑色蒙版的不透明度
    self.lastScreenBlackMask.alpha = 0.6 * (1 - (x / TSNavViewW));
    // 设置上一个截屏的缩放比例
    CGFloat scale = x / TSNavViewW * 0.05 + 0.95;
    self.lastScreenShotView.transform = CGAffineTransformMakeScale(scale, scale);
    
    // 移动键盘
    if (([[[UIDevice currentDevice] systemVersion] floatValue] >= 9)) {
        [[[UIApplication sharedApplication] windows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:NSClassFromString(@"UIRemoteKeyboardWindow")]) {
                [(UIWindow *)obj setTransform:CGAffineTransformMakeTranslation(x, 0)];
            }
        }];
    }else {
        if ([[[UIApplication sharedApplication] windows] count] > 1) {
            [((UIWindow *)[[[UIApplication sharedApplication] windows] objectAtIndex:1]) setTransform:CGAffineTransformMakeTranslation(x, 0)];
        }
    }
}

- (void)paningGestureReceive:(UIPanGestureRecognizer *)recoginzer
{
    if (!enableDrag) return;
    
    if (recoginzer.state == UIGestureRecognizerStateBegan) {
        if (self.movingState == ATNavMovingStateStanby) {
            self.movingState = ATNavMovingStateDragBegan;
            self.backgroundView.hidden = NO;
            if (self.topViewController.viewControllerToPop) {
                self.lastScreenShotView.image = [self previousScreenShot];
            }else{
                self.lastScreenShotView.image = [self lastScreenShot];
            }
        }
    }else if (recoginzer.state == UIGestureRecognizerStateEnded || recoginzer.state == UIGestureRecognizerStateCancelled){
        if (self.movingState == ATNavMovingStateDragBegan || self.movingState == ATNavMovingStateDragChanged) {
            self.movingState = ATNavMovingStateDragEnd;
            [self panGestureRecognizerDidFinish:recoginzer];
        }
    } else if (recoginzer.state == UIGestureRecognizerStateChanged) {
        if (self.movingState == ATNavMovingStateDragBegan || self.movingState == ATNavMovingStateDragChanged) {
            self.movingState = ATNavMovingStateDragChanged;
            [self moveViewWithX:[recoginzer translationInView:TSKeyWindow].x];
        }
    }
}

- (void)panGestureRecognizerDidFinish:(UIPanGestureRecognizer *)panGestureRecognizer {
#define decelerationTime (0.4)
    // 获取手指离开时候的速率
    CGFloat velocityX = [panGestureRecognizer velocityInView:TSKeyWindow].x;
    // 手指拖拽的距离
    CGFloat translationX = [panGestureRecognizer translationInView:TSKeyWindow].x;
    // 按照一定decelerationTime的衰减时间，计算出来的目标位置
    CGFloat targetX = MIN(MAX(translationX + (velocityX * decelerationTime / 2), 0), TSNavViewW);
    // 是否pop
    BOOL pop = ( targetX > TSMinX );
    // 设置动画初始化速率为当前手指离开的速率
    CGFloat initialSpringVelocity = fabs(velocityX) / (pop ? TSNavViewW - translationX : translationX);
    
    self.movingState = ATNavMovingStateDecelerating;
    [UIView animateWithDuration:TSAnimationDuration
                          delay:0
         usingSpringWithDamping:0.3
          initialSpringVelocity:initialSpringVelocity
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         [self moveViewWithX:pop ? TSNavViewW : 0];
                     }
                     completion:^(BOOL finished) {
                         self.backgroundView.hidden = YES;
                         if ( pop ) {
                             if (self.topViewController.viewControllerToPop) {
                                 if ([self.viewControllers containsObject:self.topViewController.viewControllerToPop]) {
                                     [self popToViewController:self.topViewController.viewControllerToPop animated:NO];
                                 }
                             }else{
                                 [self popViewControllerAnimated:NO];
                             }
                         }
                         self.view.frame = (CGRect){ {0, self.view.frame.origin.y}, self.view.frame.size };
                         self.movingState = ATNavMovingStateStanby;
                         
                         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((pop ? 0.3f : 0.0f) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                             // 移动键盘
                             if (([[[UIDevice currentDevice] systemVersion] floatValue] >= 9)) {
                                 [[[UIApplication sharedApplication] windows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
                                     if ([obj isKindOfClass:NSClassFromString(@"UIRemoteKeyboardWindow")]) {
                                         [(UIWindow *)obj setTransform:CGAffineTransformIdentity];
                                     }
                                 }];
                             }
                             else {
                                 if ([[[UIApplication sharedApplication] windows] count] > 1) {
                                     [((UIWindow *)[[[UIApplication sharedApplication] windows] objectAtIndex:1]) setTransform:CGAffineTransformIdentity];
                                 }
                             }
                         });
                     }];
}

#pragma mark - 拖拽手势代理
/**
 *  不响应的手势则传递下去
 */
- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldReceiveTouch:(UITouch *)touch {
    return enableDrag;
}
///**
// *  优先响应其他手势
// */
//- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRequireFailureOfGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer {
//    return YES;
//}


@end

@implementation UIViewController (TSNavigationController)

+ (void)load
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        Class class = [self class];
        
        SEL originalSelector = @selector(viewWillAppear:);
        SEL swizzledSelector = @selector(AOP_viewWillAppear:);
        
        Method originalMethod = class_getInstanceMethod(class, originalSelector);
        Method swizzledMethod = class_getInstanceMethod(class, swizzledSelector);
        
        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
    });
}

- (void)AOP_viewWillAppear:(BOOL)animated
{
    // Forward to primary implementation.
    [self AOP_viewWillAppear:animated];
    
    if (self.hidesTabBarWhenPushed && self.navigationController.viewControllers.count == 1) {
        self.tabBarController.tabBar.hidden = YES;
    }
}

- (void)setViewControllerToPop:(UIViewController *)ViewControllerToPop
{
    objc_setAssociatedObject(self, @selector(viewControllerToPop), ViewControllerToPop, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (UIViewController *)viewControllerToPop
{
    return objc_getAssociatedObject(self, _cmd);
}

- (void)setPrefersNavigationBarHidden:(BOOL)prefersNavigationBarHidden
{
    objc_setAssociatedObject(self, @selector(prefersNavigationBarHidden), @(prefersNavigationBarHidden), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)prefersNavigationBarHidden
{
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) {
        return number.boolValue;
    }else{
        self.prefersNavigationBarHidden = NO;
        return NO;
    }
}

- (void)setHidesTabBarWhenPushed:(BOOL)hidesTabBarWhenPushed
{
    objc_setAssociatedObject(self, @selector(hidesTabBarWhenPushed), @(hidesTabBarWhenPushed), OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (BOOL)hidesTabBarWhenPushed
{
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) {
        return number.boolValue;
    }else{
        self.hidesTabBarWhenPushed = NO;
        return NO;
    }
}

@end