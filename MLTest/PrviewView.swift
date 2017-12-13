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
}
