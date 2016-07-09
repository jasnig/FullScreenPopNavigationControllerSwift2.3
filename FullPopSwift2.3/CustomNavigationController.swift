//
//  CustomNavigationController.swift
//  CustomAnimation
//
//  Created by jasnig on 16/6/24.
//  Copyright © 2016年 ZeroJ. All rights reserved.
//

import UIKit

class CustomNavigationController: UINavigationController {

    private(set) var panGesture: UIPanGestureRecognizer?
    private var customDelegate: CustomNavigationControllerDelegate?
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        enabledFullScreenPop(true)
    }
    
    override init(rootViewController: UIViewController) {
        super.init(rootViewController: rootViewController)
        enabledFullScreenPop(true)
    }
    
    init() {
        super.init(nibName: nil, bundle: nil)
        enabledFullScreenPop(true)
    }
    
    // 开启或者关闭全屏pop手势(默认开启)
    func enabledFullScreenPop(isEnabled: Bool) {
        if isEnabled {
            if customDelegate == nil {
                customDelegate = CustomNavigationControllerDelegate()
                panGesture = UIPanGestureRecognizer()
                customDelegate?.panGesture = panGesture
                delegate = customDelegate
            }
        
        } else {
            customDelegate = nil
            panGesture = nil
            delegate = nil
            
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

}

class CustomNavigationControllerDelegate: UIPercentDrivenInteractiveTransition {

    let animatedTime = 0.35
    var operation: UINavigationControllerOperation = .None
    var isInteracting = false
    var containerView: UIView!
    var navigationController: UINavigationController! = nil {
        didSet {
            containerView = navigationController.view
            containerView.addGestureRecognizer(panGesture)
        }
    }
    var panGesture: UIPanGestureRecognizer! = nil {
        didSet {
            panGesture.addTarget(self, action: "handlePan:")
        }
    }
}

//MARK: - gesture Handle(手势处理)
extension CustomNavigationControllerDelegate {
    func handlePan(gesture: UIPanGestureRecognizer) {
        
        func finishOrCancel() {
            let translation = gesture.translationInView(containerView)
            let percent = translation.x / containerView.bounds.width
            let velocityX = gesture.velocityInView(containerView).x
            let isFinished: Bool
            
            // 修改这里可以改变手势结束时的处理
            if velocityX > 100 {
                isFinished = true
            } else if percent > 0.5 {
                isFinished = true
            } else {
                isFinished = false
            }
            
            isFinished ? finishInteractiveTransition() : cancelInteractiveTransition()
        }
        
        switch gesture.state {
            
        case .Began:
            isInteracting = true
            // pop
            if navigationController.viewControllers.count > 0 {
                
                navigationController.popViewControllerAnimated(true)
            }
        case .Changed:
            if isInteracting {
                let translation = gesture.translationInView(containerView)
                var percent = translation.x / containerView.bounds.width
                percent = max(percent, 0)
                
                updateInteractiveTransition(percent)
                
            }
        case .Cancelled:
            if isInteracting {
                finishOrCancel()
                isInteracting = false
            }
        case .Ended:
            if isInteracting {
                finishOrCancel()
                isInteracting = false
            }
        default:
            break
            
        }
        
        
    }
}

//MARK: - UIViewControllerAnimatedTransitioning(动画代理)
extension CustomNavigationControllerDelegate: UIViewControllerAnimatedTransitioning {
    
    func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
        return animatedTime

    }
    
    
    
    func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
        // fromVc 总是获取到正在显示在屏幕上的Controller
        let fromVc = transitionContext.viewControllerForKey( UITransitionContextFromViewControllerKey)!
        // toVc 总是获取到将要显示的controller
        let toVc = transitionContext.viewControllerForKey( UITransitionContextToViewControllerKey)!
        
        let containView = transitionContext.containerView()
        
        let toView: UIView
        let fromView: UIView
        // Animators should not directly manipulate a view controller's views and should
        // use viewForKey: to get views instead.
        if transitionContext.respondsToSelector(NSSelectorFromString("viewForKey:")) {
            // 通过这种方法获取到view不一定是对应controller.view
            toView = transitionContext.viewForKey(UITransitionContextToViewKey)!
            fromView = transitionContext.viewForKey(UITransitionContextFromViewKey)!
        } else {
            toView = toVc.view
            fromView = fromVc.view
        }
        
        
        //  添加toview到最上面(fromView是当前显示在屏幕上的view不用添加)
        containView?.addSubview(toView)
        
        // 最终显示在屏幕上的controller的frame
        let visibleFrame = transitionContext.initialFrameForViewController(fromVc)
        // 隐藏在右边的controller的frame
        let rightHiddenFrame = CGRect(origin: CGPoint(x: visibleFrame.width, y: visibleFrame.origin.y) , size: visibleFrame.size)
        // 隐藏在左边的controller的frame
        let leftHiddenFrame = CGRect(origin: CGPoint(x: -visibleFrame.width/2, y: visibleFrame.origin.y) , size: visibleFrame.size)
        
        if operation == .Push {// present Vc左移
            toView.frame = rightHiddenFrame
            fromView.frame = visibleFrame
            
        } else {// dismiss Vc右移
            fromView.frame = visibleFrame
            toView.frame = leftHiddenFrame
            // 有时需要将toView添加到fromView的下面便于执行动画
            containView?.insertSubview(toView, belowSubview: fromView)
        }
        
        //options - 应该使用匀速, 否则 交互动画的时候动画进度偏差较大
        UIView.animateWithDuration(animatedTime, delay: 0.0, options: [.CurveLinear], animations: {
            if self.operation == .Push {
                toView.frame = visibleFrame
                fromView.frame = leftHiddenFrame
            } else {
                fromView.frame = rightHiddenFrame
                toView.frame = visibleFrame
            }
            
        }) { (_) in
            let cancelled = transitionContext.transitionWasCancelled()
            if cancelled {
                // 如果中途取消了就移除toView(可交互的时候会发生)
                toView.removeFromSuperview()
            }
            // 通知系统动画是否完成或者取消了(必须)
            transitionContext.completeTransition(!cancelled)
            
        }
    }
}

//MARK: - UINavigationControllerDelegate(navigationController代理)
extension CustomNavigationControllerDelegate: UINavigationControllerDelegate {
    func navigationController(navigationController: UINavigationController, animationControllerForOperation operation: UINavigationControllerOperation, fromViewController fromVC: UIViewController, toViewController toVC: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        self.navigationController = navigationController
        self.operation = operation
        return self
    }

    func navigationController(navigationController: UINavigationController, interactionControllerForAnimationController animationController: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
        return isInteracting ? self : nil

    }

}

