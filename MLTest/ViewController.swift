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
    
    override func viewDidLoad() {
        super.viewDidLoad()
  //      let model = mobilenet_v1_1_0_224_1()
       
        do {
         //   let model = try VNCoreMLModel(for: mobilenet_v1_1_0_224_1().model)
             let model = try VNCoreMLModel(for: MyCustomImageClassifier().model)
       //     let mlmodel = manchester().model
      //      let model = try VNCoreMLModel(for: mlmodel)
            
      //      let userDefined = mlmodel.modelDescription.metadata[MLModelMetadataKey.creatorDefinedKey] as! [String: String]
      //      let labels = userDefined["classes"]
            
            let request = VNCoreMLRequest(model: model, completionHandler: { [weak self] request, error in
                self?.processClassifications(for: request, error: error)
            })
   
            //request.imageCropAndScaleOption = .scaleFill
            request.imageCropAndScaleOption = .centerCrop
            requests.append(request)
            
        } catch {
            print("Error \(error)")
        }
        // Do any additional setup after loading the view, typically from a nib.
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

    func processClassifications(for request: VNRequest, error: Error?) {

        DispatchQueue.main.async {
            guard let results = request.results else { return
            }
            if let classifications = results as? [VNClassificationObservation] {
                (self.manchesterLabel.isHidden, self.nyLabel.isHidden) =  self.format(res: classifications)
            }
        //    print("Classifications \(type(of: results))")
            
//            results.forEach {
//                print("\(type(of: $0))")
//            }

//            if let classifications = results as? [VNCoreMLFeatureValueObservation] {
//
//                classifications.forEach {
//                    print("Feature  \($0.featureValue) EndFeature")
//                }
//            }
//
//            classifications?.forEach {
//                print("\(($0 as! VNClassificationObservation).identifier) \($0.confidence) ")
//            }
//            let res = classifications?.map {
//                "\(($0 as! VNClassificationObservation).identifier) \($0.confidence)\n"
//            }.reduce("") { accum, res in
//                accum + res
//            }
            
        }
    }
    
    
    func format(res: [VNClassificationObservation]) -> (Bool, Bool) {
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
//        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
//                                            orientation: CGImagePropertyOrientation(rawValue: UInt32(ex))!,
//                                            options: requestOptions)
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
     
        
        do{
            try handler.perform(self.requests)
            
        } catch {
            
            print("Error \(error)")
        }
    }
}
