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
    
    var requests = [VNCoreMLRequest]()

    @IBOutlet weak var previewView: PrviewView!
 //   @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var manchesterLabel: UILabel!
    @IBOutlet weak var nyLabel: UILabel!
    
    var captureSession = AVCaptureSession()
    var captureDevice: AVCaptureDevice!
    var devicePosition: AVCaptureDevice.Position = .back
    
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        prepareCamera()
    }
    
    @IBAction func stopAction(_ sender: Any) {
        captureSession.stopRunning()
    }
    
   
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
     //   let (x, y, w, h) = (previewView.frame.origin.x, previewView.frame.origin.y, previewView.frame.width, previewView.frame.height)
   //     let rect = CGRect(x: x * 0.2, y: y * 0.2, width: w * 0.2, height: h * 0.4)
     //   previewView.drawLayer(in: rect)
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        do {
         //    let model = try VNCoreMLModel(for: mobilenet_v1_1_0_224_1().model)
        //     let model = try VNCoreMLModel(for: MyCustomImageClassifier().model)
            let mlmodel = manchester().model
            let model = try VNCoreMLModel(for: mlmodel)
            
            let userDefined = mlmodel.modelDescription.metadata[MLModelMetadataKey.creatorDefinedKey] as! [String: String]
            let labels = userDefined["classes"]
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
   
            request.imageCropAndScaleOption = .scaleFill
            //request.imageCropAndScaleOption = .centerCrop
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
        
 
        let queue = DispatchQueue(label: "com.brianadvent.captureQueue")
        dataOutput.setSampleBufferDelegate(self, queue: queue)
    }
    
    struct Prediction {
        let labelIndex: Int
        let confidence: Float
        let boundingBox: CGRect
    }
    
    func processClassifications(for request: VNRequest, error: Error?) {
        
        var unorderedPredictions = [Prediction]()
        DispatchQueue.main.async {
            guard let results = request.results else { return
            }
//            if let classifications = results as? [VNClassificationObservation] {
//                (self.manchesterLabel.isHidden, self.nyLabel.isHidden) =  self.format(res: classifications)
//            }

            if let classifications = results as? [VNCoreMLFeatureValueObservation] {
                print("Results count \(classifications.count)")
                
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
                        
                     //  let rect = CGRect(x: CGFloat(x - w/2), y: -CGFloat(y - h/2),  width: CGFloat(w), height: CGFloat(h))
                        let rect = CGRect(x: CGFloat(x - h/2), y: -CGFloat(y + h/2), width: CGFloat(w), height: CGFloat(h))
                        let prediction = Prediction(labelIndex: maxIndex,
                                                    confidence: Float(maxConfidence),
                                                    boundingBox: rect)
                        print("rect")
                    //    let (xx, yy, ww, hh) = (self.previewView.frame.origin.x, self.previewView.frame.origin.y, self.previewView.frame.width, self.previewView.frame.height)
                    //    let scaledRect = CGRect(x: rect.origin.x * xx, y: rect.origin.y * yy, width: rect.width * ww, height: rect.height * hh)
                //        let scaledRect = CGRect(x: rect.origin.x * 100, y: rect.origin.y * 100, width: rect.width * 100, height: rect.height * 100)
                     //   self.draw(rec: prediction.boundingBox)
                        
                        unorderedPredictions.append(prediction)
                    }
                }
                
               
//                classifications.forEach {
//                    print("0 \($0.featureValue.multiArrayValue?.shape[0].intValue) 0")
//                    print("1 \($0.featureValue.multiArrayValue?.shape[1].intValue) 1")
//                }
//                print("\n\n")
            }
            let max = unorderedPredictions.reduce(unorderedPredictions.first) { accum, pred -> Prediction?  in
                if accum == nil { return nil }
                return accum!.confidence > pred.confidence ? accum : pred
            }
            if max == nil {
                self.previewView.removeMask()
            } else {
                self.draw(rec: max!.boundingBox)
            }
            
         //   print(self.unorderedPredictions)
        //    if self.unorderedPredictions.last != nil  { self.previewView.drawLayer(in:  self.unorderedPredictions.last!.boundingBox) }

        }
    }
    
    func draw(rec: CGRect) {
        previewView.removeMask()
        let transform = CGAffineTransform(scaleX: 1, y: -1)
            .translatedBy(x: 0, y: 0)
       
        let translate = CGAffineTransform.identity
            .scaledBy(x: previewView.frame.width, y: previewView.frame.height)
        
        let rectBounds = rec.applying(translate).applying(transform)
        previewView.drawLayer(in: rectBounds)
    }
    
    
    private func format(res: [VNClassificationObservation]) -> (Bool, Bool) {
        let max = res.reduce(res[0]) { accum, res in
            return res.confidence > accum.confidence ? res : accum
        }
        print(" \(max.identifier) \(max.confidence) ")
        guard max.confidence == 1 else { return (true, true) }
        return max.identifier == "manch" ? (false, true):  (true, false)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func processAction(_ sender: Any) {
        guard let image = UIImage(named: "R")?.cgImage else {
            
            return
        }
      //  let ciImage = CIImage(cgImage: image, options: [:])
        
    //    let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do{
            try handler.perform(self.requests)
            
        } catch {
            
            print("Error \(error)")
        }
    }
    
    func exifOrientationFromDeviceOrientation() -> Int32 {
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
        
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            
            return
            
        }
        
        //
        var requestOptions = [VNImageOption: Any]()

        if let cameraIntrinsicsData = CMGetAttachment(sampleBuffer, kCMSampleBufferAttachmentKey_CameraIntrinsicMatrix, nil) {
            requestOptions = [.cameraIntrinsics: cameraIntrinsicsData]
        }
        //
        
        let ex = self.exifOrientationFromDeviceOrientation()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: CGImagePropertyOrientation(rawValue: UInt32(ex))!,
                                            options: requestOptions)
      //  let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
     
        
        do{
            try handler.perform(self.requests)
            
        } catch {
            
            print("Error \(error)")
        }
    }
}
