# CameraKit

[![CI Status](http://img.shields.io/travis/pablogm/CameraKit.svg?style=flat)](https://travis-ci.org/pablogm/CameraKit)
[![Version](https://img.shields.io/cocoapods/v/PGMCameraKit.svg?style=flat)](http://cocoapods.org/pods/PGMCameraKit)
[![License](https://img.shields.io/cocoapods/l/PGMCameraKit.svg?style=flat)](http://cocoapods.org/pods/PGMCameraKit)
[![Platform](https://img.shields.io/cocoapods/p/PGMCameraKit.svg?style=flat)](http://cocoapods.org/pods/PGMCameraKit)
[![Carthage compatible](https://img.shields.io/badge/Carthage-compatible-4BC51D.svg?style=flat)](https://github.com/Carthage/Carthage)

Swift library to provide all the configurations you need to create a camera view: 

* Start / pause / resume / stop recording
* Video compression 
* Save / Fetch videos & images from the media library
* Set max video duration threshold
* Follow camera orientation change
* Front and back camera
* Flash modes
* Video / still image modes
* Output quality

## Usage

To run the example project, clone the repo, and run `pod install` from the Example directory first.

## Requirements

## Installation

CameraKit is available through [CocoaPods](http://cocoapods.org). To install
it, simply add the following line to your Podfile:

```ruby
pod "PGMCameraKit"
```

## Installation with Carthage

[Carthage](https://github.com/Carthage/Carthage) is another dependency management tool written in Swift.

Add the following line to your Cartfile:

```ruby
github "pablogm/CameraKit"
```

## How to use

Init Camera Kit:

```swift
let cameraManager       = PGMCameraKit()
```

Init Camera Kit Helper (util functions to save images/videos, retrieve images/videos from media library and compress video output)

```swift
let helper              = PGMCameraKitHelper()
```

Ask user for camera permissions:

```swift
cameraManager.askUserForCameraPermissions({ [unowned self] permissionGranted in

    if permissionGranted {
        self.addCameraToView()
    }
    else {
        self.addCameraAccessDeniedPopup("Go to settings and grant acces to the camera device to use it.")
    }
})

```

Set video time limit.

```swift
cameraManager.maxRecordedDuration = 4.0 // secs
```

Listeners:

```swift
// Errors
cameraManager.addCameraErrorListener( { error in


})

// Time progress
cameraManager.addCameraTimeListener( { time in

    print("Time elapsed: \(time) seg")
})

// Video time limit
cameraManager.addMaxAllowedLengthListener({ [unowned self] (videoURL, error, localIdentifier) -> () in

    if let err = error {
        print("Error \(err)")
    }
    else {

        if let url = videoURL {

            print("Saved video from local url \(url) with uuid \(localIdentifier)")

            let data = NSData(contentsOfURL: url)!

            print("Byte Size Before Compression: \(data.length / 1024) KB")

        }
    }
})
```

Start recording video:

```swift
cameraManager.startRecordingVideo( {(error)->() in

    if let err = error {
        print("Error ocurred: \(err)")
    }
})
```

Pause recording:

```swift
cameraManager.pauseRecordingVideo()
```

Resume recording:

```swift
cameraManager.resumeRecordingVideo()
```

Stop recording:

```swift
cameraManager.stopRecordingVideo( { (videoURL, error, localIdentifier) -> () in

    if let err = error {
        print("Error ocurred: \(err)")
    }
    else {
        print("Video url: \(videoURL) with unique id \(localIdentifier)")
    }
})
```


Video compression:

```swift
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
```



## Support

Supports iOS8 and above. XCode 7.0 is required to build the latest code written in Swift 2.0

## Author

pablogm, invanzert@gmail.com

## License

CameraKit is available under the MIT license. See the LICENSE file for more info.
