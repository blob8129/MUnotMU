//
//  ViewController.swift
//  MLTest
//
//  Created by Andrey Volobuev on 12/11/17.
//  Copyright © 2017 Andrey Volobuev. All rights reserved.
//

import UIKit
import Vision
import AVFoundation

class ViewController: UIViewController {
    
    @IBOutlet weak var previewView: PrviewView!
    @IBOutlet weak var manchesterLabel: UILabel!
    
    private var requests = [VNCoreMLRequest]()
    private var captureSession = AVCaptureSession()
    private var captureDevice: AVCaptureDevice!
    private var devicePosition: AVCaptureDevice.Position = .back
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareCamera()
    }
    
    @IBAction func stopAction(_ sender: Any) {
        captureSession.stopRunning()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            let mlmodel = manchester().model
            let model = try VNCoreMLModel(for: mlmodel)
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
   
            request.imageCropAndScaleOption = .scaleFill
            requests.append(request)
        } catch {
            print("Error \(error)")
        }
    }
    
    func prepareCamera() {
        captureSession.sessionPreset = AVCaptureSession.Preset.photo
        
        let devices = AVCaptureDevice.DiscoverySession(deviceTypes: [.builtInWideAngleCamera],
                                                       mediaType: AVMediaType.video,
                                                       position: .back).devices
        captureDevice = devices.first
        beginSession()
    }
    
    func beginSession () {
        do {
            let captureDeviceInput = try AVCaptureDeviceInput(device: captureDevice)
            captureSession.addInput(captureDeviceInput)
        }catch {
            print(error.localizedDescription)
        }
        
        self.previewView.session = captureSession
        captureSession.startRunning()
        
        let dataOutput = AVCaptureVideoDataOutput()
        dataOutput.videoSettings = [((kCVPixelBufferPixelFormatTypeKey as NSString) as String): NSNumber(value:kCVPixelFormatType_32BGRA)]
        
        dataOutput.alwaysDiscardsLateVideoFrames = true
        
        if captureSession.canAddOutput(dataOutput) {
            captureSession.addOutput(dataOutput)
        }
        
        captureSession.commitConfiguration()
        let queue = DispatchQueue(label: "com.blob8129")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
    }
    
    struct Prediction {
        let labelIndex: Int
        let confidence: Float
        let boundingBox: CGRect
    }
    
    func processClassifications(for request: VNRequest, error: Error?) {
        DispatchQueue.main.async {
            let unorderedPredictions = self.extractPredictions(from: request)
            let maxPrediction = self.max(predictions: unorderedPredictions)
            self.render(prediction: maxPrediction)
        }
    }
    
    private func extractPredictions(from request: VNRequest) -> [Prediction] {
        var unorderedPredictions = [Prediction]()
        self.hideAll()
        guard let classifications = request.results as? [VNCoreMLFeatureValueObservation] else {
            return  [Prediction]()
        }
        
        let confidenceThreshold = 0.1
        let coordinates = classifications[0].featureValue.multiArrayValue!
        let confidence = classifications[1].featureValue.multiArrayValue!
        
        let numBoundingBoxes = confidence.shape[0].intValue
        let numClasses = confidence.shape[1].intValue
        
        let confidencePointer = UnsafeMutablePointer<Double>(OpaquePointer(confidence.dataPointer))
        let coordinatesPointer = UnsafeMutablePointer<Double>(OpaquePointer(coordinates.dataPointer))
        
        for b in 0..<numBoundingBoxes {
            var maxConfidence = 0.0
            var maxIndex = 0
            for c in 0..<numClasses {
                let conf = confidencePointer[b * numClasses + c]
                if conf > maxConfidence {
                    maxConfidence = conf
                    maxIndex = c
                }
            }
            if maxConfidence > confidenceThreshold {
                let x = coordinatesPointer[b * 4]
                let y = coordinatesPointer[b * 4 + 1]
                let w = coordinatesPointer[b * 4 + 2]
                let h = coordinatesPointer[b * 4 + 3]
                
                let rect = CGRect(x: CGFloat(x - w/2), y: -CGFloat(y + h/2), width: CGFloat(w), height: CGFloat(h))
                let prediction = Prediction(labelIndex: maxIndex,
                                            confidence: Float(maxConfidence),
                                            boundingBox: rect)
                unorderedPredictions.append(prediction)
            }
        }
        return unorderedPredictions
    }
    
    private func render(prediction: Prediction?) {
        guard let prediction = prediction else {
            self.previewView.removeMask()
            return
        }
        self.draw(rec: prediction.boundingBox)
        self.manchesterLabel.isHidden = prediction.labelIndex == 0 ? false : true
    }
    
    private func max(predictions: [Prediction]) -> Prediction? {
        guard let first = predictions.first else { return nil }
        return predictions.reduce(first) { accum, pred -> Prediction  in
            return accum.confidence > pred.confidence ? accum : pred
        }
    }
    
    private func draw(rec: CGRect) {
        previewView.removeMask()
        let transform = CGAffineTransform(scaleX: 1, y: -1)
        let translate = CGAffineTransform.identity
            .scaledBy(x: previewView.frame.width, y: previewView.frame.height)
        let rectBounds = rec.applying(translate).applying(transform)
        previewView.drawLayer(in: rectBounds)
    }
    
    private func format(for index: Int) -> (Bool, Bool) {
        return index == 0 ? (false, true):  (true, true)
    }
    
    private func hideAll() {
        manchesterLabel.isHidden = true
    }
    
    private func format(res: [VNClassificationObservation]) -> (Bool, Bool) {
        let max = res.reduce(res[0]) { accum, res in
            return res.confidence > accum.confidence ? res : accum
        }
        guard max.confidence == 1 else { return (true, true) }
        return max.identifier == "manch" ? (false, true):  (true, false)
    }
    
    private func exifOrientationFromDeviceOrientation() -> Int32 {
        enum DeviceOrientation: Int32 {
            case top0ColLeft = 1
            case top0ColRight = 2
            case bottom0ColRight = 3
            case bottom0ColLeft = 4
            case left0ColTop = 5
            case right0ColTop = 6
            case right0ColBottom = 7
            case left0ColBottom = 8
        }
        var exifOrientation: DeviceOrientation
        
        switch UIDevice.current.orientation {
        case .portraitUpsideDown:
            exifOrientation = .left0ColBottom
        case .landscapeLeft:
            exifOrientation = devicePosition == .front ? .bottom0ColRight : .top0ColLeft
        case .landscapeRight:
            exifOrientation = devicePosition == .front ? .top0ColLeft : .bottom0ColRight
        default:
            exifOrientation = .right0ColTop
        }
        return exifOrientation.rawValue
    }
}

extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    
     func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        var requestOptions = [VNImageOption: Any]()
        
        if let cameraIntrinsicsData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicsData]
        }
        let ex = exifOrientationFromDeviceOrientation()
        
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: CGImagePropertyOrientation(rawValue: UInt32(ex))!,
                                            options: requestOptions)
        do{
            try handler.perform(requests)
        } catch {
            print("Error \(error)")
        }
    }
}
