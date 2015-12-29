/*
Copyright (c) 2015 Pablo GM <invanzert@gmail.com>

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import UIKit
import CoreMedia
import AVFoundation
import PGMCameraKit

class ViewController: UIViewController {
    
    
    // MARK: Members
    
    let cameraManager       = PGMCameraKit()
    let helper              = PGMCameraKitHelper()
    var player: AVPlayer!
    
    
    // MARK: @IBOutlets
    
    @IBOutlet weak var cameraView: UIView!
    @IBOutlet weak var cameraButton: UIButton!
    @IBOutlet weak var flashModeButton: UIButton!
    @IBOutlet weak var interfaceView: UIView!
    
    
    // MARK: UIViewController
    
    override func viewDidLoad() {
        
        super.viewDidLoad()
        
        let currentCameraState = cameraManager.currentCameraStatus()
        
        if currentCameraState == .NotDetermined || currentCameraState == .AccessDenied {
            
            print("We don't have permission to use the camera.")
            
            cameraManager.askUserForCameraPermissions({ [unowned self] permissionGranted in
                
                if permissionGranted {
                    self.addCameraToView()
                }
                else {
                    self.addCameraAccessDeniedPopup("Go to settings and grant acces to the camera device to use it.")
                }
            })
        }
        else if (currentCameraState == .Ready) {
            
            addCameraToView()
        }
        
        if !cameraManager.hasFlash {
            
            flashModeButton.enabled = false
            flashModeButton.setTitle("No flash", forState: UIControlState.Normal)
        }
        
        
        // Limits
        
        cameraManager.maxRecordedDuration = 4.0
        
        
        // Listeners
        
        cameraManager.addCameraErrorListener( { [unowned self] error in
            
            if let err = error {
                
                if err.code == CameraError.CameraAccessDeniend.rawValue {
                    
                    self.addCameraAccessDeniedPopup(err.localizedFailureReason!)
                }
            }
            })
        
        cameraManager.addCameraTimeListener( { time in
            
            print("Time elapsed: \(time) seg")
        })
        
        cameraManager.addMaxAllowedLengthListener({ [unowned self] (videoURL, error, localIdentifier) -> () in
            
            if let err = error {
                print("Error \(err)")
            }
            else {
                
                if let url = videoURL {
                    
                    print("Saved video from local url \(url) with uuid \(localIdentifier)")
                    
                    let data = NSData(contentsOfURL: url)!
                    
                    print("Byte Size Before Compression: \(data.length / 1024) KB")
                    
                    // The compress file extension will depend on the output file type
                    self.helper.compressVideo(url, outputURL: self.cameraManager.tempCompressFilePath("mp4"), outputFileType: AVFileTypeMPEG4, handler: { session in
                        
                        if let currSession = session {
                            
                            print("Progress: \(currSession.progress)")
                            
                            print("Save to \(currSession.outputURL)")
                            
                            if currSession.status == .Completed {
                                
                                if let data = NSData(contentsOfURL: currSession.outputURL!) {
                                    
                                    print("File size after compression: \(data.length / 1024) KB")
                                    
                                    // Play compressed video
                                    dispatch_async(dispatch_get_main_queue(), {
                                        
                                        let player  = AVPlayer(URL: currSession.outputURL!)
                                        let layer   = AVPlayerLayer(player: player)
                                        layer.frame = self.view.bounds
                                        self.view.layer.addSublayer(layer)
                                        player.play()
                                        
                                        print("Playing video...")
                                    })
                                }
                            }
                            else if currSession.status == .Failed
                            {
                                print(" There was a problem compressing the video maybe you can try again later. Error: \(currSession.error!.localizedDescription)")
                            }
                        }
                    })
                }
            }
            
            // Recording stopped automatically after reached max allowed duration
            self.cameraButton.selected = !(self.cameraButton.selected)
            self.cameraButton.setTitle(" ", forState: UIControlState.Selected)
            self.cameraButton.backgroundColor = self.cameraButton.selected ? UIColor.redColor() : UIColor.greenColor()
            })
        
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.navigationBar.hidden = true
        cameraManager.resumeCaptureSession()
        
        // Start observing
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "postVideoFulFill:", name: "FulfillVideoPostRequest", object: nil)
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        cameraManager.stopCaptureSession()
        
        // Stop observing
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    override func viewDidAppear(animated: Bool) {
        
    }
    
    
    // MARK: Error Popups
    
    private func addCameraAccessDeniedPopup(message: String) {
        
        dispatch_async(dispatch_get_main_queue(), {
            self.showAlert("TubeAlert", message: message, ok: "Ok", cancel: "", cancelAction: nil, okAction: { alert in
                
                switch UIDevice.currentDevice().systemVersion.compare("8.0.0", options: NSStringCompareOptions.NumericSearch) {
                case .OrderedSame, .OrderedDescending:
                    UIApplication.sharedApplication().openURL(NSURL(string: UIApplicationOpenSettingsURLString)!)
                case .OrderedAscending:
                    print("Not supported")
                    break
                }
                }, completion: nil)
        })
    }
    
    
    // MARK: Orientation
    
    override func shouldAutorotate() -> Bool {
        return true
    }
    
    override func supportedInterfaceOrientations() -> UIInterfaceOrientationMask {
        return [UIInterfaceOrientationMask.Portrait, UIInterfaceOrientationMask.LandscapeLeft, UIInterfaceOrientationMask.LandscapeRight, UIInterfaceOrientationMask.PortraitUpsideDown]
    }
    
    override func preferredInterfaceOrientationForPresentation() -> UIInterfaceOrientation {
        return .Portrait
    }
    
    
    // MARK: Add / Revemo camera
    
    private func addCameraToView()
    {
        cameraManager.addPreviewLayerToView(cameraView, newCameraOutputMode: CameraOutputMode.VideoWithMic)
    }
    
    
    // MARK: @IBActions
    
    @IBAction func changeFlashMode(sender: UIButton)
    {
        switch (cameraManager.changeFlashMode()) {
        case .Off:
            sender.setTitle("Flash Off", forState: UIControlState.Normal)
        case .On:
            sender.setTitle("Flash On", forState: UIControlState.Normal)
        case .Auto:
            sender.setTitle("Flash Auto", forState: UIControlState.Normal)
        }
    }
    
    @IBAction func recordButtonTapped(sender: UIButton) {
        
        switch (cameraManager.cameraOutputMode) {
            
        case .StillImage:
            cameraManager.capturePictureWithCompletition( { (image, error, localIdentifier) -> () in
                
                if let err = error {
                    print("Error ocurred: \(err)")
                }
                else {
                    print("Image saved to library to id: \(localIdentifier)")
                }
                
                }, name: "ImageName")
            
        case .VideoWithMic, .VideoOnly:
            
            sender.selected = !sender.selected
            sender.setTitle(" ", forState: UIControlState.Selected)
            sender.backgroundColor = sender.selected ? UIColor.redColor() : UIColor.greenColor()
            
            if sender.selected {
                
                if cameraManager.timer?.state == .TimerStatePaused {
                    
                    cameraManager.resumeRecordingVideo()
                }
                else {
                    
                    cameraManager.startRecordingVideo( {(error)->() in
                        
                        if let err = error {
                            print("Error ocurred: \(err)")
                        }
                        
                    })
                }
            }
            else {
                
                cameraManager.pauseRecordingVideo()
                
                /*
                cameraManager.stopRecordingVideo( { (videoURL, error, localIdentifier) -> () in
                
                if let err = error {
                print("Error ocurred: \(err)")
                }
                else {
                print("Video url: \(videoURL) with unique id \(localIdentifier)")
                }
                
                })
                */
            }
        }
    }
    
    @IBAction func outputModeButtonTapped(sender: UIButton) {
        
        cameraButton.selected = false
        cameraButton.backgroundColor = UIColor.greenColor()
        
        switch (cameraManager.cameraOutputMode) {
        case .VideoOnly:
            cameraManager.cameraOutputMode = CameraOutputMode.StillImage
            sender.setTitle("Photo", forState: UIControlState.Normal)
        case .VideoWithMic:
            cameraManager.cameraOutputMode = CameraOutputMode.VideoOnly
            sender.setTitle("Video", forState: UIControlState.Normal)
        case .StillImage:
            cameraManager.cameraOutputMode = CameraOutputMode.VideoWithMic
            sender.setTitle("Mic On", forState: UIControlState.Normal)
        }
    }
    
    @IBAction func changeCameraDevice(sender: UIButton) {
        
        cameraManager.cameraDevice = cameraManager.cameraDevice == CameraDevice.Front ? CameraDevice.Back : CameraDevice.Front
        switch (cameraManager.cameraDevice) {
        case .Front:
            sender.setTitle("Front", forState: UIControlState.Normal)
        case .Back:
            sender.setTitle("Back", forState: UIControlState.Normal)
        }
    }
    
    @IBAction func changeCameraQuality(sender: UIButton) {
        
        switch (cameraManager.changeQualityMode()) {
        case .High:
            sender.setTitle("High", forState: UIControlState.Normal)
        case .Low:
            sender.setTitle("Low", forState: UIControlState.Normal)
        case .Medium:
            sender.setTitle("Medium", forState: UIControlState.Normal)
        }
    }
}