//
//  PrviewView.swift
//  MLTest
//
//  Created by Andrey Volobuev on 12/11/17.
//  Copyright © 2017 Andrey Volobuev. All rights reserved.
//

import UIKit
import AVFoundation

class PrviewView: UIView {
    
    private var maskLayer = [CAShapeLayer]()
    
    
    // MARK: AV capture properties
    var videoPreviewLayer: AVCaptureVideoPreviewLayer {
        return layer as! AVCaptureVideoPreviewLayer
    }
    
    var session: AVCaptureSession? {
        get {
            return videoPreviewLayer.session
        }
        
        set {
            videoPreviewLayer.session = newValue
        }
    }
    
    override class var layerClass: AnyClass {
        return AVCaptureVideoPreviewLayer.self
    }
    
    func drawLayer(in rect: CGRect) {

        let mask = CAShapeLayer()
        mask.frame = rect
        
        mask.backgroundColor = UIColor.yellow.cgColor
        mask.cornerRadius = 10
        mask.opacity = 0.3
        mask.borderColor = UIColor.yellow.cgColor
        mask.borderWidth = 2.0
        
        maskLayer.append(mask)
        layer.insertSublayer(mask, at: 1)
    }
    
    func removeMask() {
        for mask in maskLayer {
            mask.removeFromSuperlayer()
        }
        maskLayer.removeAll()
    }
}
