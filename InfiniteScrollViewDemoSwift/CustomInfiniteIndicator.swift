//
//  CustomInfiniteIndicator.swift
//  InfiniteScrollViewDemoSwift
//
//  Created by pronebird on 5/3/15.
//  Copyright (c) 2015 pronebird. All rights reserved.
//
import UIKit

private let rotationAnimationKey = "rotation"

class CustomInfiniteIndicator: UIView {
    
    var thickness: CGFloat = 2
    var outerColor = UIColor.gray.withAlphaComponent(0.2)
    
    lazy var innerColor: UIColor = {
        return self.tintColor
    }()
    
    private var animating = false
    private let innerCircle = CAShapeLayer()
    private let outerCircle = CAShapeLayer()
    private var startTime = CFTimeInterval(0)
    private var stopTime = CFTimeInterval(0)
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    deinit {
        unregisterFromAppStateNotifications()
    }
    
    override func layoutSublayers(of layer: CALayer) {
        setupBezierPaths()
    }
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        
        if let _ = window {
            restartAnimationIfNeeded()
        }
    }
    
    // MARK: - Private
    
    private func commonInit() {
        registerForAppStateNotifications()
        
        isHidden = true
        backgroundColor = UIColor.clear
        
        outerCircle.strokeColor = outerColor.cgColor
        outerCircle.fillColor = UIColor.clear.cgColor
        outerCircle.lineWidth = thickness
        
        innerCircle.strokeColor = innerColor.cgColor
        innerCircle.fillColor = UIColor.clear.cgColor
        innerCircle.lineWidth = thickness
        
        layer.addSublayer(outerCircle)
        layer.addSublayer(innerCircle)
    }
    
    private func addAnimation() {
        let anim = animation()
        anim.timeOffset = stopTime - startTime
        
        layer.add(anim, forKey: rotationAnimationKey)
        
        startTime = layer.convertTime(CACurrentMediaTime(), from: nil)
    }
    
    private func removeAnimation() {
        layer.removeAnimation(forKey: rotationAnimationKey)
        
        stopTime = layer.convertTime(CACurrentMediaTime(), from: nil)
    }
    
    func restartAnimationIfNeeded() {
        let anim = layer.animation(forKey: rotationAnimationKey)
        
        if animating && anim == nil {
            removeAnimation()
            addAnimation()
        }
    }
    
    private func registerForAppStateNotifications() {
        NotificationCenter.default.addObserver(self, selector: #selector(CustomInfiniteIndicator.restartAnimationIfNeeded), name: NSNotification.Name.UIApplicationWillEnterForeground, object: nil)
    }
    
    private func unregisterFromAppStateNotifications() {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func animation() -> CABasicAnimation {
        let animation = CABasicAnimation(keyPath: "transform.rotation")
        animation.toValue = NSNumber(value: M_PI * 2)
        animation.duration = 1
        animation.repeatCount = Float.infinity
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
        
        return animation
    }
    
    private func setupBezierPaths() {
        let center = CGPoint(x: bounds.size.width * 0.5, y: bounds.size.height * 0.5)
        let radius = bounds.size.width * 0.5 - thickness
        let ringPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: CGFloat(0), endAngle: CGFloat(M_PI * 2), clockwise: true)
        let quarterRingPath = UIBezierPath(arcCenter: center, radius: radius, startAngle: CGFloat(-M_PI_4), endAngle: CGFloat(M_PI_2 - M_PI_4), clockwise: true)
        
        outerCircle.path = ringPath.cgPath
        innerCircle.path = quarterRingPath.cgPath
    }
    
    // MARK: - Public
    
    func isAnimating() -> Bool {
        return animating
    }
    
    func startAnimating() {
        if animating {
            return
        }
        animating = true
        isHidden = false
        addAnimation()
    }
    
    func stopAnimationg() {
        if !animating {
            return
        }
        animating = false
        isHidden = true
        removeAnimation()
    }
    
}
