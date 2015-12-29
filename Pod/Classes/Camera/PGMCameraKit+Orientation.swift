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

import Foundation
import UIKit
import AVFoundation

extension PGMCameraKit {

    
    // MARK: Associated objects
    
    private struct AssociatedKeys {
        static var CamIsObsDevOrKey = "cameraIsObservingDeviceOrientationKey"
    }
    
    var cameraIsObservingDeviceOrientation: Bool? {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.CamIsObsDevOrKey) as? Bool
        }
        
        set {
            if let newValue = newValue {
                objc_setAssociatedObject(self, &AssociatedKeys.CamIsObsDevOrKey, newValue as Bool?, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
            }
        }
    }
    
    
    // MARK: Start / Stop orientation changed listener
    
    internal func startFollowingDeviceOrientation() {
        
        if cameraIsObservingDeviceOrientation == nil ||  cameraIsObservingDeviceOrientation == false {
            
            NSNotificationCenter.defaultCenter().addObserver(self, selector: Selector("orientationChanged"), name: UIDeviceOrientationDidChangeNotification, object: nil)
            cameraIsObservingDeviceOrientation = true
        }
    }
    
    internal func stopFollowingDeviceOrientation() {
        
        if cameraIsObservingDeviceOrientation == true {
            
            NSNotificationCenter.defaultCenter().removeObserver(self, name: UIDeviceOrientationDidChangeNotification, object: nil)
            cameraIsObservingDeviceOrientation = false
        }
    }
    
    @objc internal func orientationChanged() {
        
        guard (UIDevice.currentDevice().orientation != .FaceDown && UIDevice.currentDevice().orientation != .FaceUp ) else {
            return
        }
        
        var currentConnection: AVCaptureConnection?;
        switch cameraOutputMode {
        case .StillImage:
            currentConnection = stillImageOutput?.connectionWithMediaType(AVMediaTypeVideo)
        case .VideoOnly, .VideoWithMic:
            currentConnection = getMovieOutput().connectionWithMediaType(AVMediaTypeVideo)
        }
        if let validPreviewLayer = previewLayer {
            if let validPreviewLayerConnection = validPreviewLayer.connection {
                if validPreviewLayerConnection.supportsVideoOrientation {
                    validPreviewLayerConnection.videoOrientation = currentVideoOrientation()
                }
            }
            if let validOutputLayerConnection = currentConnection {
                if validOutputLayerConnection.supportsVideoOrientation {
                    validOutputLayerConnection.videoOrientation = currentVideoOrientation()
                }
            }
            dispatch_async(dispatch_get_main_queue(), { () -> Void in
                if let validEmbedingView = self.embedingView {
                    validPreviewLayer.frame = validEmbedingView.bounds
                }
            })
        }
    }
    
    
    // MARK: Private Functions
    
    private func currentVideoOrientation() -> AVCaptureVideoOrientation {
        
        switch UIDevice.currentDevice().orientation {
            
        case .LandscapeLeft:
            return .LandscapeRight
            
        case .LandscapeRight:
            return .LandscapeLeft
            
        case .PortraitUpsideDown:
            return .PortraitUpsideDown
            
        default:
            return .Portrait
        }
    }
}

extension AVCaptureVideoOrientation {
    
    var uiDeviceOrientation: UIDeviceOrientation {
        get {
            switch self {
            case .LandscapeLeft:        return .LandscapeLeft
            case .LandscapeRight:       return .LandscapeRight
            case .Portrait:             return .Portrait
            case .PortraitUpsideDown:   return .PortraitUpsideDown
            }
        }
    }
    
    init(ui:UIDeviceOrientation) {
        switch ui {
            case .LandscapeRight:
                self = .LandscapeLeft
                //print("LandscapeRight")
            case .LandscapeLeft:
                self = .LandscapeRight
                //print("LandscapeLeft")
            case .Portrait:
                self = .Portrait
                //print("Portrait")
            case .PortraitUpsideDown:
                self = .PortraitUpsideDown
                //print("PortraitUpsideDown")
            default:
                self = .Portrait
                //print("Portrait")
        }
    }
}