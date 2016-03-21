//
//  TSNavigationController.m
//  TSNavigationController
//
//  Created by TragedyStar on 16/2/19.
//  Copyright © 2016年 TS. All rights reserved.
//

#import "TSNavigationController.h"
#import <objc/runtime.h>

#define enableDrag (self.viewControllers.count > 1 && !self.disableDragPop && self.topViewController.enableDragPop)

#define TSKeyWindow     [[UIApplication sharedApplication] keyWindow]
#define TSNavViewW      [UIScreen mainScreen].bounds.size.width
#define TSDecelerationTime (0.4)

typedef NS_ENUM(int, TSNavMovingState) {
    TSNavMovingStateStanby = 0,
    TSNavMovingStateDragBegan,
    TSNavMovingStateDragChanged,
    TSNavMovingStateDragEnd,
    TSNavMovingStateDecelerating,
};
@interface TSNavigationController () <UIGestureRecognizerDelegate>
/**
 *  black mask of last screen 上一个界面的黑色渐变遮罩
 */
@property (nonatomic, strong) UIView *lastScreenBlackMaskView;
/**
 *  screenshot of last screen 上一个界面的截屏
 */
@property (nonatomic, strong) UIImageView *lastScreenShotImageView;
/**
 *  black backgroud of last screenshot 上一个界面的截屏的黑色背景
 */
@property (nonatomic, strong) UIView *backgroundView;
/**
 *  dictionary saved string of controller's pointer/controller's screenshot pairs. key:string of controller's pointer value:screenshot  存放截屏的字典 key：控制器指针字符串  value：截屏图片
 */
@property (nonatomic, strong) NSMutableDictionary *screenShotsDict;
/**
 *  moving state 移动状态
 */
@property (nonatomic, assign) TSNavMovingState movingState;

@end

@implementation TSNavigationController

#pragma mark - 懒加载
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
        
        _lastScreenShotImageView = [[UIImageView alloc] initWithFrame:_backgroundView.bounds];
        _lastScreenShotImageView.backgroundColor = [UIColor whiteColor];
        [_backgroundView addSubview:_lastScreenShotImageView];
        
        _lastScreenBlackMaskView = [[UIView alloc] initWithFrame:_backgroundView.bounds];
        _lastScreenBlackMaskView.backgroundColor = [UIColor blackColor];
        [_backgroundView addSubview:_lastScreenBlackMaskView];
    }
    
    if (_backgroundView.superview == nil) {
        [self.view.superview insertSubview:_backgroundView belowSubview:self.view];//每次pop之前要将backgroundView置于self.view的下一层，因为pop的时候是在移动self.view
    }
    return _backgroundView;
}

#pragma mark - 生命周期
- (void)viewDidLoad
{
    [super viewDidLoad];
    // 为导航控制器view，添加拖拽手势
    UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(paningGestureReceive:)];
    pan.delegate = self;
    [pan delaysTouchesBegan];
    [self.view addGestureRecognizer:pan];
    
    //    self.interactivePopGestureRecognizer.enabled = NO;
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
- (UIImage *)lastScreenShot
{
    NSUInteger index = 0;
    if (self.viewControllers.count > 2) {
        index = self.viewControllers.count - 2;
    }
    UIViewController *lastVC = [self.viewControllers objectAtIndex:index];
    return [self.screenShotsDict objectForKey:[self stringOfPointer:lastVC]];
}
/*
 *  获取当前页面要pop的viewController的截屏。若找不到，返回nil。
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

#pragma mark - 重写改变栈的方法
/**
 *  push前添加当前界面截屏
 */
- (void)pushViewController:(UIViewController *)viewController animated:(BOOL)animated {
    
    //push navigationController的根控制器时，不截屏
    if (self.viewControllers.count > 0) {
        [self.screenShotsDict setObject:[self capture] forKey:[self stringOfPointer:self.topViewController]];
    }
    
    //push之前判断是否需要隐藏tabbar
    if (viewController.hidesTabBarWhenPushed)
    {
        self.tabBarController.tabBar.hidden = YES;//此处不需要判断是否有tabbar
    }
    
    //push之前判断隐藏或者显示navigationBar。此处的隐藏和显示不是最自然的方式
    if (viewController.prefersNavigationBarHidden)
    {
        self.navigationBarHidden = YES;
        
    }else{
        self.navigationBarHidden = NO;
    }
    
    [super pushViewController:viewController animated:animated];
    
}

- (void)animatePopWithScreenShot:(UIImage *)screenShot completion:(void (^ __nullable)(BOOL finished))completion
{
    self.backgroundView.hidden = NO;//调用self.backgroundView时，会将其置于self.view的下一层
    self.lastScreenShotImageView.image = screenShot;
    self.movingState = TSNavMovingStateDecelerating;
    self.lastScreenBlackMaskView.alpha = 0.6 /* * (1 - (0 / TSNavViewW))*/;//初始值0.6
    CGFloat scale = 0.8 /* + (0 / TSNavViewW * 0.05)*/ ;//初始值0.8
    self.lastScreenShotImageView.transform = CGAffineTransformMakeScale(scale, scale);
    
    [UIView animateWithDuration:0.5
                          delay:0
         usingSpringWithDamping:self.isSpringAnimated? 0.4 : 1
          initialSpringVelocity:self.isSpringAnimated? 0.5 : 0
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         [self moveViewWithX:TSNavViewW];//最终值：黑色遮罩的alpha为0，上一个界面截图的transform为1，self.view的frame为{TSNavViewW，0，TSNavViewW，self.view.frame.size.height};
                     }
                     completion:^(BOOL finished) {
                         self.backgroundView.hidden = YES;
                         self.view.frame = (CGRect){ {0, self.view.frame.origin.y}, self.view.frame.size };//将self.view重新移动到屏幕中
                         self.movingState = TSNavMovingStateStanby;
                         
                         dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((0.5f) * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
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
                         
                         completion(finished);
                         
                     }];
}

/**
 *  pop后移除当前界面截屏
 */
- (UIViewController *)popViewControllerAnimated:(BOOL)animated {
    
    if (animated) {
        __block UIViewController *poppedVC;
        [self animatePopWithScreenShot:self.topViewController.viewControllerToPop? [self previousScreenShot] : [self lastScreenShot]
                            completion:^(BOOL finished) {
                                poppedVC = [self popViewControllerCompletion];
                            }];
        return poppedVC;
        
    }else{
        return [self popViewControllerCompletion];
    }
}

- (UIViewController *)popViewControllerCompletion
{
    //如果用户手动调用本方法时，也要执行如下判断进行正确pop
    if (self.topViewController.viewControllerToPop) { //返回按钮会
        [self popToViewController:self.topViewController.viewControllerToPop animated:NO];
        return nil; //由于此时pop了多个controller，此处无法返回pop了哪个controller，故返回nil
    }else{
        UIViewController *lastVC = [self.viewControllers objectAtIndex:self.viewControllers.count>1? self.viewControllers.count - 2 : 0];
        if (lastVC.prefersNavigationBarHidden) {
            self.navigationBarHidden = YES;
        }else{
            self.navigationBarHidden = NO;
        }
        
        UIViewController *poppedVC = [super popViewControllerAnimated:NO];
        [self.screenShotsDict removeObjectForKey:[self stringOfPointer:self.topViewController]];
        
        //判断只有当即将被POP的控制器在stack中是第一个设置hidesTabBarWhenPushed属性时，才显示出tabbar
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
        
        return poppedVC;
    }
}

//pop到指定界面需要移除相应的界面
- (NSArray<UIViewController *> *)popToViewController:(UIViewController *)viewController animated:(BOOL)animated
{
    
    if (animated) {
        
        __block NSArray *poppedVCs;
        [self animatePopWithScreenShot:[self screenShotOfViewController:viewController] completion:^(BOOL finished) {
            poppedVCs = [self popToViewControllerCompletion:viewController];
        }];
        return poppedVCs;
    }else{
        return [self popToViewControllerCompletion:viewController];
    }
}

- (NSArray<UIViewController *> *)popToViewControllerCompletion:(UIViewController *)viewController
{
    //导航条的显示和隐藏
    if (viewController.prefersNavigationBarHidden) {
        self.navigationBarHidden = YES;
    }else{
        self.navigationBarHidden = NO;
    }
    
    //删除被pop的viewControllers的截屏
    NSArray *poppedVCs = [super popToViewController:viewController animated:NO];
    for (UIViewController *vc in poppedVCs) {
        [self.screenShotsDict removeObjectForKey:[self stringOfPointer:vc]];
    }
    
    //判断否需要显示tabBar
    BOOL poppedVCsHideTabBar = NO;
    for (UIViewController *vc in poppedVCs) {
        if (vc.hidesTabBarWhenPushed) {
            poppedVCsHideTabBar = YES;
            break;
        }
    }
    if (poppedVCsHideTabBar) {//pop出去的多个控制器中，有设置了hidesTabBarWhenPushed属性的。
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
    
    return poppedVCs;
}

- (nullable NSArray<__kindof UIViewController *> *)popToRootViewControllerAnimated:(BOOL)animated
{
    //点击tabBar的item会执行此方法，故需要在此判断是否已经位于根视图，如果当前位于根视图，则不执行任何操作
    if (self.viewControllers.count == 1) {
        return nil;
    }
    
    if (animated) {
        __block NSArray *poppedVCs;
        [self animatePopWithScreenShot:[self screenShotOfViewController:[self.viewControllers firstObject]] completion:^(BOOL finished) {
            poppedVCs = [self popToRootViewControllerCompletion];
        }];
        return poppedVCs;
    }else{
        return [self popToRootViewControllerCompletion];
    }
    
}

- (nullable NSArray<__kindof UIViewController *> *)popToRootViewControllerCompletion
{
    //导航条的显示和隐藏
    UIViewController *rootVC = self.viewControllers.firstObject;
    if (rootVC.prefersNavigationBarHidden) {
        self.navigationBarHidden = YES;
    }else{
        self.navigationBarHidden = NO;
    }
    
    //删除被pop的viewControllers的截屏
    NSArray *poppedVCs = [super popToRootViewControllerAnimated:NO];
    for (UIViewController *vc in poppedVCs) {
        [self.screenShotsDict removeObjectForKey:[self stringOfPointer:vc]];
    }
    
    //判断否需要显示tabBar
    if (!rootVC.hidesTabBarWhenPushed) {
        self.tabBarController.tabBar.hidden = NO;
    }
    
    return poppedVCs;
}

/**
 *  重置界面时截屏(新增的界面会缺失截屏)
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
    // 设置水平位移在 [0, TSNavViewW] 之间
    x = MAX(MIN(x, TSNavViewW), 0);
    // 设置frame的x
    self.view.frame = (CGRect){ {x, self.view.frame.origin.y}, self.view.frame.size};
    // 设置黑色遮罩的透明度，范围在[0, 0.6]之间
    self.lastScreenBlackMaskView.alpha = 0.6 * (1 - (x / TSNavViewW));
    // 设置上一个截屏的缩放比例，范围在[0.95, 1]之间
    CGFloat scale = x / TSNavViewW * 0.05 + 0.95;
    self.lastScreenShotImageView.transform = CGAffineTransformMakeScale(scale, scale);
    
    // 移动键盘
    if (([[[UIDevice currentDevice] systemVersion] floatValue] >= 9)) {//iOS9 之后
        [[[UIApplication sharedApplication] windows] enumerateObjectsUsingBlock:^(__kindof UIWindow * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if ([obj isKindOfClass:NSClassFromString(@"UIRemoteKeyboardWindow")]) {
                [(UIWindow *)obj setTransform:CGAffineTransformMakeTranslation(x, 0)];
            }
        }];
    }else {//iOS9 之前
        if ([[[UIApplication sharedApplication] windows] count] > 1) {
            [((UIWindow *)[[[UIApplication sharedApplication] windows] objectAtIndex:1]) setTransform:CGAffineTransformMakeTranslation(x, 0)];
        }
    }
}
/*
 *  pan手势执行的方法
 */
- (void)paningGestureReceive:(UIPanGestureRecognizer *)recoginzer
{
    if (!enableDrag) return;
    //开始拖动
    if (recoginzer.state == UIGestureRecognizerStateBegan) {
        if (self.movingState == TSNavMovingStateStanby) {
            self.movingState = TSNavMovingStateDragBegan;
            self.backgroundView.hidden = NO;
            if (self.topViewController.viewControllerToPop) {
                self.lastScreenShotImageView.image = [self previousScreenShot];
            }else{
                self.lastScreenShotImageView.image = [self lastScreenShot];
            }
        }
    }//结束或取消拖动
    else if (recoginzer.state == UIGestureRecognizerStateEnded || recoginzer.state == UIGestureRecognizerStateCancelled){
        if (self.movingState == TSNavMovingStateDragBegan || self.movingState == TSNavMovingStateDragChanged) {
            self.movingState = TSNavMovingStateDragEnd;
            [self panGestureRecognizerDidFinish:recoginzer];
        }
    }//正在拖动
    else if (recoginzer.state == UIGestureRecognizerStateChanged) {
        if (self.movingState == TSNavMovingStateDragBegan || self.movingState == TSNavMovingStateDragChanged) {
            self.movingState = TSNavMovingStateDragChanged;
            [self moveViewWithX:[recoginzer translationInView:TSKeyWindow].x];
        }
    }
}
/*
 *  拖动结束或取消时执行此方法
 */
- (void)panGestureRecognizerDidFinish:(UIPanGestureRecognizer *)panGestureRecognizer {
    // 获取手指离开时候的速率
    CGFloat velocityX = [panGestureRecognizer velocityInView:TSKeyWindow].x;
    // 手指拖拽的距离
    CGFloat translationX = [panGestureRecognizer translationInView:TSKeyWindow].x;
    // 按照一定TSDecelerationTime的衰减时间，计算出来的目标位置
    CGFloat targetX = MIN(MAX(translationX + (velocityX * TSDecelerationTime / 2), 0), TSNavViewW);
    // 是否pop
    BOOL pop = ( targetX > TSMinX );
    // 设置动画初始化速率为当前手指离开的速率
    CGFloat initialSpringVelocity = fabs(velocityX) / (pop ? TSNavViewW - translationX : translationX);
    
    self.movingState = TSNavMovingStateDecelerating;
    [UIView animateWithDuration:TSAnimationDuration
                          delay:0
         usingSpringWithDamping:self.isSpringAnimated? 0.3 : 1
          initialSpringVelocity:self.isSpringAnimated? initialSpringVelocity : 0
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
                         self.movingState = TSNavMovingStateStanby;
                         
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
        
        //如果originalSelector不存在，则添加originalSelector方法，方法实现为AOP方法的实现。如果存在则不添加方法，并返回success为NO
        BOOL success = class_addMethod(class, originalSelector, method_getImplementation(swizzledMethod), method_getTypeEncoding(swizzledMethod));
        if (success) {
            //将AOP方法的实现设置成空
            class_replaceMethod(class, swizzledSelector, method_getImplementation(originalMethod), method_getTypeEncoding(originalMethod));
        } else {
            method_exchangeImplementations(originalMethod, swizzledMethod);
        }
        
        
        SEL viewDidLoadSEL = @selector(viewDidLoad);
        SEL AOP_viewDidLoadSEL = @selector(AOP_viewDidLoad);
        
        Method viewDidLoadMethod = class_getInstanceMethod(class, viewDidLoadSEL);
        Method AOP_viewDidLoadMethod = class_getInstanceMethod(class, AOP_viewDidLoadSEL);
        
        BOOL success1 = class_addMethod(class, viewDidLoadSEL, method_getImplementation(AOP_viewDidLoadMethod), method_getTypeEncoding(AOP_viewDidLoadSEL));
        if (success1) {
            class_replaceMethod(class, AOP_viewDidLoadSEL, method_getImplementation(viewDidLoadMethod), method_getTypeEncoding(viewDidLoadMethod));
        } else {
            method_exchangeImplementations(viewDidLoadMethod, AOP_viewDidLoadMethod);
        }
    });
}

//初始化控制器的属性写在此处，由子控制器在viewDidLoad中的[super viewDidLoad]调用
- (void)AOP_viewDidLoad
{
    [self AOP_viewDidLoad];
    
    self.enableDragPop = YES;
}

- (void)AOP_viewWillAppear:(BOOL)animated
{
    // Forward to primary implementation.
    [self AOP_viewWillAppear:animated];
    
    if (self.hidesTabBarWhenPushed && self.navigationController.viewControllers.count == 1) {
        self.tabBarController.tabBar.hidden = YES;
    }
}

#pragma -mark 是否开启拖拽返回
- (void)setEnableDragPop:(BOOL)enableDragPop
{
    objc_setAssociatedObject(self, @selector(enableDragPop), @(enableDragPop), OBJC_ASSOCIATION_ASSIGN);
}

- (BOOL)enableDragPop
{
    NSNumber *number = objc_getAssociatedObject(self, _cmd);
    if (number) {
        return number.boolValue;
    }else{
        self.enableDragPop = NO;
        return NO;
    }
}

#pragma -mark 要pop到的控制器
- (void)setViewControllerToPop:(UIViewController *)viewControllerToPop
{
    objc_setAssociatedObject(self, @selector(viewControllerToPop), viewControllerToPop, OBJC_ASSOCIATION_ASSIGN);
}

- (UIViewController *)viewControllerToPop
{
    return objc_getAssociatedObject(self, _cmd);
}

#pragma -mark 是否隐藏navigationBar
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

#pragma -mark 是否隐藏tabbar
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

#pragma -mark 自己所在的栈中的前一个控制器
- (UIViewController *)lastViewControllerInStack
{
    if (!self.navigationController) {
        NSInteger index = self.navigationController.viewControllers.count-2;
        if (index < 0) {
            index = 0;
        }
        return self.navigationController.viewControllers[index];
    }
    return nil;
}

#pragma -mark 自己所在栈中的第一个控制器
- (UIViewController *)rootViewControllerInStack
{
    return [self.navigationController.viewControllers firstObject];
}

@end