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
import AVFoundation
import AssetsLibrary
import Photos
import PGMTimer


// MARK: Typedef

public typealias VideoCompletionType = (NSURL?, NSError?, LocalIdentifierType?) -> ()
public typealias CompletionType      = () -> ()
public typealias CompletionBoolType  = Bool -> ()
public typealias CompletionErrorType = NSError? -> ()
public typealias SizeCompletionType  = Int64? -> ()
public typealias TimeCompletionType  = String? -> ()
public typealias ImageCompletionType = (UIImage?, NSError?, LocalIdentifierType?) -> ()

@objc public class PGMCameraKit: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate, AVCaptureAudioDataOutputSampleBufferDelegate {
    
    
    // MARK: Public properties
    
    /// Capture session to customize camera settings.
    public var captureSession: AVCaptureSession?
    
    /// Bool property to determine if current device has front camera.
    public var hasFrontCamera: Bool = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for  device in devices  {
            let captureDevice = device as! AVCaptureDevice
            if (captureDevice.position == .Front) {
                return true
            }
        }
        return false
    }()
    
    /// Bool property to determine if current device has flash.
    public var hasFlash: Bool = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        for  device in devices  {
            let captureDevice = device as! AVCaptureDevice
            if (captureDevice.position == .Back) {
                return captureDevice.hasFlash
            }
        }
        return false
    }()
    
    /// Property to change camera device between front and back.
    public var cameraDevice = CameraDevice.Back {
        didSet {
            if cameraDevice != oldValue {
                updateCameraDevice(cameraDevice)
            }
        }
    }
    
    /// Property to change camera flash mode.
    public var flashMode = CameraFlashMode.Off {
        didSet {
            if flashMode != oldValue {
                updateFlasMode(flashMode)
            }
        }
    }
    
    /// Property to change camera output quality.
    public var cameraOutputQuality = CameraOutputQuality.High {
        didSet {
            if cameraOutputQuality != oldValue {
                updateCameraQualityMode(cameraOutputQuality)
            }
        }
    }
    
    /// Property to change camera output.
    public var cameraOutputMode = CameraOutputMode.VideoWithMic {
        didSet {
            if cameraOutputMode != oldValue {
                setupOutputMode(cameraOutputMode, oldCameraOutputMode: oldValue)
            }
        }
    }
    
    /// This property specifies a hard limit on the duration of recorded files.
    public var maxRecordedDuration:NSTimeInterval = 9.0
    
    /// Video preview layer
    public var previewLayer: AVCaptureVideoPreviewLayer?
    
    /// Timer to handle video state (paused, recording, ...)
    public var timer:PGMTimer?
    
    
    // MARK: Internal properties
    
    /// Still image output
    internal var stillImageOutput: AVCaptureStillImageOutput?
    
    /// Movie output
    internal var movieOutput: AVCaptureVideoDataOutput?
    
    /// Audio output
    internal var audioOutput: AVCaptureAudioDataOutput?
    
    /// View where to place the preview layer
    internal weak var embedingView: UIView?
    
    
    // MARK: Private properties
    
    private var videoCompletition: VideoCompletionType?
    
    private let lockQueue       = dispatch_queue_create("com.aumentia.lockQueue", nil)
    
    private let sessionQueue    = dispatch_queue_create("com.aumentia.recordingQueue", DISPATCH_QUEUE_SERIAL)
    
    private lazy var frontCameraDevice: AVCaptureDevice? = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        return devices.filter{$0.position == .Front}.first
    }()
    
    private lazy var backCameraDevice: AVCaptureDevice? = {
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo) as! [AVCaptureDevice]
        return devices.filter{$0.position == .Back}.first
    }()
    
    private lazy var mic: AVCaptureDevice? = {
        return AVCaptureDevice.defaultDeviceWithMediaType(AVMediaTypeAudio)
    }()
    
    private var library: PHPhotoLibrary?
    
    private var videoWriter : PGMCameraKitWriter?
    
    private let cameraKitErrorDomain = "cameraKitErrorDomain"
    
    private var height:Int?
    private var width:Int?
    
    private var cameraIsSetup   = false
    private var isCapturing     = false
    private var isPaused        = false
    private var isDiscontinue   = false
    private var fileIndex       = 0
    
    private var timeOffset      = CMTimeMake(0, 0)
    private var lastAudioPts: CMTime?
    
    private var cameraError: CompletionErrorType?
    private var cameraMaxAllowedLength: VideoCompletionType?
    private var cameraTime: TimeCompletionType?
    
    
    // MARK: Paths
    
    /**
    Temporal path where the original video is stored
    
    - returns: Original video path
    */
    public func tempFilePath() -> NSURL {
        
        return FileManager.getPath("tempMovie", ext: "mp4")
    }
    
    /**
     Temporal path where the compressed video is stored
     
     - parameter ext: Compressed video extension
     
     - returns: Compressed video path
     */
    public func tempCompressFilePath(ext: String) -> NSURL {
        
        return FileManager.getPath("tempCompressMovie", ext: ext)
    }
    
    
    // MARK: Listeners
    
    /**
    Use this listener to track errors
    
    - parameter cameraError: CompletionErrorType
    */
    public func addCameraErrorListener(cameraError: CompletionErrorType) {
        self.cameraError = cameraError
    }
    
    /**
     Use this listener to track the time progress
     
     - parameter cameraTime: TimeCompletionType
     */
    public func addCameraTimeListener(cameraTime: TimeCompletionType) {
        self.cameraTime = cameraTime
    }
    
    /**
     Use this listener to be notified when reached the max allowed video time lenght
     
     - parameter cameraMaxAllowedLength: VideoCompletionType
     */
    public func addMaxAllowedLengthListener(cameraMaxAllowedLength: VideoCompletionType) {
        self.cameraMaxAllowedLength = cameraMaxAllowedLength
    }
    
    
    // MARK: CameraManager
    
    /**
    Inits a capture session and adds a preview layer to the given view.
    Preview layer bounds will automaticaly be set to match given view.
    Default session is initialized with still image output.
    
    - parameter view:                The view you want to add the preview layer to
    - parameter newCameraOutputMode: The mode you want capturesession to run image / video / video and microphone
    
    - returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined.
    */
    public func addPreviewLayerToView(view: UIView, newCameraOutputMode: CameraOutputMode) -> CameraState {
        
        if canLoadCamera() {
            
            if let _ = embedingView {
                
                if let validPreviewLayer = previewLayer {
                    validPreviewLayer.removeFromSuperlayer()
                }
            }
            
            if cameraIsSetup {
                
                addPreeviewLayerToView(view)
                cameraOutputMode = newCameraOutputMode
            }
            else {
                setupCamera({ [weak self] () -> () in
                    self?.addPreeviewLayerToView(view)
                    self?.cameraOutputMode = newCameraOutputMode
                    })
            }
        }
        
        return checkIfCameraIsAvailable()
    }
    
    /**
     Asks the user for camera permissions.
     Only works if the permissions are not yet determined.
     Note that it'll also automaticaly ask about the microphone permissions if you selected VideoWithMic output.
     
     - parameter completition: Completition block with the result of permission request
     */
    public func askUserForCameraPermissions(completition: CompletionBoolType) {
        
        AVCaptureDevice.requestAccessForMediaType(AVMediaTypeVideo, completionHandler: { [weak self] (alowedAccess) -> () in
            
            if self?.cameraOutputMode == .VideoWithMic {
                
                AVCaptureDevice.requestAccessForMediaType(AVMediaTypeAudio, completionHandler: { (alowedAccess) -> () in
                    
                    dispatch_sync(dispatch_get_main_queue(), { () -> () in
                        completition(alowedAccess)
                    })
                })
            }
            else {
                
                dispatch_sync(dispatch_get_main_queue(), { () -> () in
                    completition(alowedAccess)
                })
            }
            })
    }
    
    /**
     Stops running capture session but all setup devices, inputs and outputs stay for further reuse.
     */
    public func stopCaptureSession() {
        captureSession?.stopRunning()
        stopFollowingDeviceOrientation()
    }
    
    /**
     Resumes capture session.
     */
    public func resumeCaptureSession() {
        
        if let validCaptureSession = captureSession {
            
            if !validCaptureSession.running && cameraIsSetup {
                
                validCaptureSession.startRunning()
                startFollowingDeviceOrientation()
            }
        }
        else {
            
            if canLoadCamera() {
                
                if cameraIsSetup {
                    stopAndRemoveCaptureSession()
                }
                setupCamera({ [weak self] () -> () in
                    
                    if let validEmbedingView = self?.embedingView {
                        
                        self?.addPreeviewLayerToView(validEmbedingView)
                    }
                    self?.startFollowingDeviceOrientation()
                    })
            }
        }
    }
    
    /**
     Get video data output
     
     - returns: AVCaptureVideoDataOutput
     */
    public func getMovieOutput() -> AVCaptureVideoDataOutput {
        
        var shouldReinitializeMovieOutput = movieOutput == nil
        
        if !shouldReinitializeMovieOutput {
            if let connection = movieOutput!.connectionWithMediaType(AVMediaTypeVideo) {
                shouldReinitializeMovieOutput = shouldReinitializeMovieOutput || !connection.active
            }
        }
        
        if shouldReinitializeMovieOutput {
            
            setupMovieOutput()
        }
        
        return movieOutput!
    }
    
    
    // MARK: Still Image
    
    /**
    Captures still image from currently running capture session.
    
    - parameter imageCompletition: imageCompletition Completition block containing the captured UIImage
    */
    public func capturePictureWithCompletition(imageCompletition: ImageCompletionType, name: String) {
        
        if cameraIsSetup {
            
            if cameraOutputMode == .StillImage {
                
                dispatch_async(sessionQueue, {
                    
                    self.getStillImageOutput().captureStillImageAsynchronouslyFromConnection(self.getStillImageOutput().connectionWithMediaType(AVMediaTypeVideo), completionHandler: { (sample: CMSampleBuffer!, error: NSError!) -> () in
                        
                        if (error != nil) {
                            imageCompletition(nil, error, "")
                        }
                        else {
                            let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(sample)
                            
                            // Get a reference to our helper
                            let helper = PGMCameraKitHelper()
                            
                            // Save the image to library
                            if let imageToSave = UIImage(data: imageData) {
                                
                                helper.saveImageAsAsset(imageToSave, completion: { (localIdentifier, error) -> () in
                                    
                                    imageCompletition(imageToSave, error, localIdentifier)
                                })
                            }
                            else {
                                imageCompletition(UIImage(data: imageData), nil, "")
                            }
                        }
                    })
                })
            }
            else {
                
                let err = NSError(localizedDescription: "Can not take the picture", localizedFailureReason: "Capture session output mode video", domain: cameraKitErrorDomain)
                imageCompletition(nil, err, "")
            }
        }
        else {
            
            let err = NSError(localizedDescription: "Can not take the picture", localizedFailureReason: "No capture session setup", domain: cameraKitErrorDomain)
            imageCompletition(nil, err, "")
        }
    }
    
    
    // MARK: Video: start, stop, pause, resume
    
    /**
    Start recording video
    
    - parameter completion: CompletionErrorType
    */
    public func startRecordingVideo(completion: CompletionErrorType) {
        
        if cameraOutputMode != .StillImage {
            
            dispatch_sync(self.lockQueue) {
                
                if !self.isCapturing{
                    
                    print("Start recording")
                    
                    self.isPaused       = false
                    self.isDiscontinue  = false
                    self.isCapturing    = true
                    self.timeOffset     = CMTimeMake(0, 0)
                    
                    guard self.timer == nil else {
                        fatalError("Timer should be nil")
                    }
                    
                    self.timer = PGMTimer(timerEnd: self.maxRecordedDuration, timerWillStart: {}, timerDidFire: { [weak self] time in
                        
                        self?.cameraTime?(time)
                        
                        }, timerDidPause: {
                            
                            print("Pause recording")
                            
                        }, timerWillResume: {
                            
                            print("Resume recording")
                            
                        }, timerDidStop: { [weak self] in
                            
                            self?.stopProcess(false)
                            
                        }, timerDidEnd: { [weak self] time in
                            
                            self?.stopProcess(true)
                        })
                    
                    self.timer?.start()
                    
                    self.captureSession?.beginConfiguration()
                    if self.flashMode != .Off {
                        self.updateTorch(self.flashMode)
                    }
                    self.captureSession?.commitConfiguration()
                    
                    completion(nil)
                }
            }
        }
        else {
            let err = NSError(localizedDescription: "Can not record video", localizedFailureReason: "Can only take pictures", domain: cameraKitErrorDomain)
            completion(err)
        }
    }
    
    /**
     Stop recording video
     
     - parameter completition: VideoCompletionType
     */
    public func stopRecordingVideo(completition:VideoCompletionType) {
        
        if let _ = movieOutput {
            
            dispatch_sync(self.lockQueue) {
                
                guard (self.timer?.state == .TimerStateRunning) else {
                    
                    print("Can not stop")
                    return
                }
                
                if self.isCapturing {
                    
                    print("Stop recording")
                    
                    self.videoCompletition = completition
                    
                    guard self.timer != nil else {
                        fatalError("Timer should not be nil")
                    }
                    
                    self.timer?.stop()
                }
            }
        }
    }
    
    /**
     Pause recording video
     */
    public func pauseRecordingVideo() {
        
        dispatch_sync(self.lockQueue) {
            
            if self.isCapturing {
                
                guard (self.timer?.state == .TimerStateRunning) else {
                    
                    print("Can not pause")
                    return
                }
                
                self.isPaused = true
                self.isDiscontinue = true
                self.timer?.pause()
            }
        }
    }
    
    /**
     Resume recording video
     */
    public func resumeRecordingVideo() {
        
        dispatch_sync(self.lockQueue) {
            
            if self.isCapturing{
                
                guard (self.timer?.state == .TimerStatePaused) else {
                    
                    print("Can not resume")
                    return
                }
                
                self.isPaused = false
                self.timer?.resume()
            }
        }
    }
    
    
    // MARK: Camera properties
    
    /**
    Current camera status.
    
    - returns: Current state of the camera: Ready / AccessDenied / NoDeviceFound / NotDetermined
    */
    public func currentCameraStatus() -> CameraState {
        return checkIfCameraIsAvailable()
    }
    
    /**
     Change current flash mode to next value from available ones.
     
     - returns: Current flash mode: Off / On / Auto
     */
    public func changeFlashMode() -> CameraFlashMode {
        flashMode = CameraFlashMode(rawValue: (flashMode.rawValue + 1) % 3)!
        return flashMode
    }
    
    /**
     Change current output quality mode to next value from available ones.
     
     - returns: Current quality mode: Low / Medium / High
     */
    public func changeQualityMode() -> CameraOutputQuality {
        cameraOutputQuality = CameraOutputQuality(rawValue: (cameraOutputQuality.rawValue + 1) % 3)!
        return cameraOutputQuality
    }
    
    
    // MARK: AVCaptureDataVideoDelegate
    
    public func captureOutput(captureOutput: AVCaptureOutput!, didOutputSampleBuffer sampleBuffer: CMSampleBuffer!, fromConnection connection: AVCaptureConnection!) {
        
        dispatch_sync(self.lockQueue) {
            
            if !self.isCapturing || self.isPaused {
                return
            }
            
            let isVideo = captureOutput is AVCaptureVideoDataOutput
            
            if self.cameraOutputMode == .VideoWithMic {
                
                if self.videoWriter == nil && !isVideo {
                    
                    let fileManager = NSFileManager()
                    
                    if fileManager.fileExistsAtPath(self.filePath()) {
                        do {
                            try fileManager.removeItemAtPath(self.filePath())
                        }
                        catch let outError as NSError {
                            
                            let err = NSError(localizedDescription: "Error removing file: \(outError.localizedDescription)",
                                localizedFailureReason: outError.localizedFailureReason,
                                domain: self.cameraKitErrorDomain)
                            
                            self.cameraError?(err)
                        }
                    }
                    
                    let fmt = CMSampleBufferGetFormatDescription(sampleBuffer)
                    let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(fmt!)
                    
                    print("setup video writer (with mic)")
                    
                    self.videoWriter = PGMCameraKitWriter(
                        fileUrl: self.filePathUrl(),
                        height: AVCaptureVideoOrientation(ui:UIDevice.currentDevice().orientation) == .Portrait ? self.width! : self.height!,
                        width: AVCaptureVideoOrientation(ui:UIDevice.currentDevice().orientation) == .Portrait ? self.height! : self.width!,
                        channels: Int(asbd.memory.mChannelsPerFrame),
                        samples: asbd.memory.mSampleRate
                    )
                }
            }
            else {
                if self.videoWriter == nil && isVideo {
                    
                    let fileManager = NSFileManager()
                    
                    if fileManager.fileExistsAtPath(self.filePath()) {
                        do {
                            try fileManager.removeItemAtPath(self.filePath())
                        }
                        catch let outError as NSError {
                            
                            let err = NSError(localizedDescription: "Error removing file: \(outError.localizedDescription)",
                                localizedFailureReason: outError.localizedFailureReason,
                                domain: self.cameraKitErrorDomain)
                            
                            self.cameraError?(err)
                        }
                    }
                    
                    print("setup video writer (only video)")
                    
                    self.videoWriter = PGMCameraKitWriter(
                        fileUrl: self.filePathUrl(),
                        height: AVCaptureVideoOrientation(ui:UIDevice.currentDevice().orientation) == .Portrait ? self.width! : self.height!,
                        width: AVCaptureVideoOrientation(ui:UIDevice.currentDevice().orientation) == .Portrait ? self.height! : self.width!
                    )
                }
            }
            
            
            if self.isDiscontinue {
                if isVideo {
                    return
                }
                
                var pts = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
                
                let isAudioPtsValid = self.lastAudioPts!.flags.intersect(CMTimeFlags.Valid)
                
                if isAudioPtsValid.rawValue != 0 {
                    
                    print("isAudioPtsValid is valid")
                    
                    let isTimeOffsetPtsValid = self.timeOffset.flags.intersect(CMTimeFlags.Valid)
                    
                    if isTimeOffsetPtsValid.rawValue != 0 {
                        print("isTimeOffsetPtsValid is valid")
                        pts = CMTimeSubtract(pts, self.timeOffset);
                    }
                    let offset = CMTimeSubtract(pts, self.lastAudioPts!);
                    
                    if (self.timeOffset.value == 0)
                    {
                        print("timeOffset is \(self.timeOffset.value)")
                        self.timeOffset = offset;
                    }
                    else
                    {
                        print("timeOffset is \(self.timeOffset.value)")
                        self.timeOffset = CMTimeAdd(self.timeOffset, offset);
                    }
                }
                self.lastAudioPts!.flags = CMTimeFlags()
                self.isDiscontinue = false
            }
            
            var buffer = sampleBuffer
            if self.timeOffset.value > 0 {
                buffer = self.ajustTimeStamp(sampleBuffer, offset: self.timeOffset)
            }
            
            if !isVideo {
                var pts = CMSampleBufferGetPresentationTimeStamp(buffer)
                let dur = CMSampleBufferGetDuration(buffer)
                if (dur.value > 0)
                {
                    pts = CMTimeAdd(pts, dur)
                }
                self.lastAudioPts = pts
            }
            
            self.videoWriter?.write(buffer, isVideo: isVideo)
        }
    }
    
    // MARK: Private Functions
    
    
    // MARK: Setups
    
    private func ajustTimeStamp(sample: CMSampleBufferRef, offset: CMTime) -> CMSampleBufferRef {
        
        var count: CMItemCount = 0
        CMSampleBufferGetSampleTimingInfoArray(sample, 0, nil, &count);
        var info = [CMSampleTimingInfo](count: count, repeatedValue: CMSampleTimingInfo(duration: CMTimeMake(0, 0), presentationTimeStamp: CMTimeMake(0, 0), decodeTimeStamp: CMTimeMake(0, 0)))
        CMSampleBufferGetSampleTimingInfoArray(sample, count, &info, &count);
        
        for i in 0..<count {
            info[i].decodeTimeStamp = CMTimeSubtract(info[i].decodeTimeStamp, offset);
            info[i].presentationTimeStamp = CMTimeSubtract(info[i].presentationTimeStamp, offset);
        }
        
        
        var sbufWithNewTiming: CMSampleBuffer? = nil
        let err = CMSampleBufferCreateCopyWithNewTiming(kCFAllocatorDefault,
            sample,
            count,
            &info,
            &sbufWithNewTiming)
        if err != 0 {
            print("Error \(err)")
        }
        
        return sbufWithNewTiming!
    }
    
    private func updateTorch(flashMode: CameraFlashMode) {
        
        captureSession?.beginConfiguration()
        
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        
        for  device in devices  {
            
            let captureDevice = device as! AVCaptureDevice
            
            if (captureDevice.position == AVCaptureDevicePosition.Back) {
                
                let avTorchMode = AVCaptureTorchMode(rawValue: flashMode.rawValue)
                
                if (captureDevice.isTorchModeSupported(avTorchMode!)) {
                    
                    do {
                        try captureDevice.lockForConfiguration()
                    }
                    catch {
                        return;
                    }
                    captureDevice.torchMode = avTorchMode!
                    captureDevice.unlockForConfiguration()
                }
            }
        }
        captureSession?.commitConfiguration()
    }
    
    private func setupMovieOutput() -> AVCaptureVideoDataOutput? {
        
        movieOutput = AVCaptureVideoDataOutput()
        
        if let videoDataOutput = movieOutput {
            
            videoDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
            videoDataOutput.alwaysDiscardsLateVideoFrames = true
            let setcapSettings: [NSObject : AnyObject] = [
                kCVPixelBufferPixelFormatTypeKey : Int(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange)
            ]
            videoDataOutput.videoSettings = setcapSettings
            
        }
        
        return movieOutput
    }
    
    private func setupAudioOutput() -> AVCaptureAudioDataOutput? {
        
        audioOutput = AVCaptureAudioDataOutput()
        
        if let audioDataOutput = audioOutput {
            
            audioDataOutput.setSampleBufferDelegate(self, queue: sessionQueue)
        }
        
        return audioOutput
    }
    
    private func getStillImageOutput() -> AVCaptureStillImageOutput {
        
        var shouldReinitializeStillImageOutput = stillImageOutput == nil
        
        if !shouldReinitializeStillImageOutput {
            
            if let connection = stillImageOutput!.connectionWithMediaType(AVMediaTypeVideo) {
                shouldReinitializeStillImageOutput = shouldReinitializeStillImageOutput || !connection.active
            }
        }
        
        if shouldReinitializeStillImageOutput {
            
            stillImageOutput = AVCaptureStillImageOutput()
            
            captureSession?.beginConfiguration()
            captureSession?.addOutput(stillImageOutput)
            captureSession?.commitConfiguration()
        }
        
        return stillImageOutput!
    }
    
    private func setupCamera(completition: CompletionType) {
        captureSession = AVCaptureSession()
        
        dispatch_async(sessionQueue, {
            if let validCaptureSession = self.captureSession {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = AVCaptureSessionPresetHigh
                self.updateCameraDevice(self.cameraDevice)
                self.setupOutputs()
                self.setupOutputMode(self.cameraOutputMode, oldCameraOutputMode: nil)
                self.setupPreviewLayer()
                validCaptureSession.commitConfiguration()
                self.updateFlasMode(self.flashMode)
                self.updateCameraQualityMode(self.cameraOutputQuality)
                validCaptureSession.startRunning()
                self.startFollowingDeviceOrientation()
                self.cameraIsSetup = true
                self.orientationChanged()
                
                completition()
            }
        })
    }
    
    private func setupOutputMode(newCameraOutputMode: CameraOutputMode, oldCameraOutputMode: CameraOutputMode?) {
        
        captureSession?.beginConfiguration()
        
        if let cameraOutputToRemove = oldCameraOutputMode {
            
            // remove current setting
            switch cameraOutputToRemove {
                
            case .StillImage:
                if let validStillImageOutput = stillImageOutput {
                    captureSession?.removeOutput(validStillImageOutput)
                }
                
            case .VideoOnly, .VideoWithMic:
                if let validVideoOutput = movieOutput {
                    captureSession?.removeOutput(validVideoOutput)
                }
                if let validAudioOutput = audioOutput {
                    captureSession?.removeOutput(validAudioOutput)
                }
                if cameraOutputToRemove == .VideoWithMic {
                    removeMicInput()
                }
            }
        }
        
        // Configure new devices
        switch newCameraOutputMode {
            
        case .StillImage:
            if (stillImageOutput == nil) {
                setupOutputs()
            }
            if let validStillImageOutput = stillImageOutput {
                captureSession?.addOutput(validStillImageOutput)
            }
        case .VideoOnly, .VideoWithMic:
            let videoDataOutput = getMovieOutput()
            captureSession?.addOutput(videoDataOutput)
            height = videoDataOutput.videoSettings["Height"] as! Int!
            width = videoDataOutput.videoSettings["Width"] as! Int!
            
            if newCameraOutputMode == .VideoWithMic {
                if let validMic = deviceInputFromDevice(mic) {
                    captureSession?.addInput(validMic)
                    captureSession?.addOutput(setupAudioOutput())
                }
            }
        }
        captureSession?.commitConfiguration()
        updateCameraQualityMode(cameraOutputQuality)
        orientationChanged()
    }
    
    private func setupOutputs() {
        
        if (stillImageOutput == nil) {
            stillImageOutput = AVCaptureStillImageOutput()
        }
        if (movieOutput == nil) {
            movieOutput = setupMovieOutput()
        }
        if (audioOutput == nil) {
            audioOutput = setupAudioOutput()
        }
        if library == nil {
            library = PHPhotoLibrary?()
        }
    }
    
    private func setupPreviewLayer() {
        if let validCaptureSession = captureSession {
            previewLayer = AVCaptureVideoPreviewLayer(session: validCaptureSession)
            previewLayer?.videoGravity = AVLayerVideoGravityResizeAspectFill
        }
    }
    
    // MARK: Update State
    
    private func updateCameraDevice(deviceType: CameraDevice) {
        
        if let validCaptureSession = captureSession {
            validCaptureSession.beginConfiguration()
            let inputs = validCaptureSession.inputs as! [AVCaptureInput]
            
            for input in inputs {
                if let deviceInput = input as? AVCaptureDeviceInput {
                    if deviceInput.device == backCameraDevice && cameraDevice == .Front {
                        validCaptureSession.removeInput(deviceInput)
                        break;
                    } else if deviceInput.device == frontCameraDevice && cameraDevice == .Back {
                        validCaptureSession.removeInput(deviceInput)
                        break;
                    }
                }
            }
            switch cameraDevice {
                
            case .Front:
                
                if hasFrontCamera {
                    
                    if let validFrontDevice = deviceInputFromDevice(frontCameraDevice) {
                        
                        frontCameraDevice!.activeVideoMinFrameDuration = CMTimeMake(1, 30)
                        
                        if !inputs.contains(validFrontDevice) {
                            validCaptureSession.addInput(validFrontDevice)
                        }
                    }
                }
            case .Back:
                
                if let validBackDevice = deviceInputFromDevice(backCameraDevice) {
                    
                    backCameraDevice!.activeVideoMinFrameDuration = CMTimeMake(1, 30)
                    
                    if !inputs.contains(validBackDevice) {
                        validCaptureSession.addInput(validBackDevice)
                    }
                }
            }
            validCaptureSession.commitConfiguration()
        }
    }
    
    private func updateFlasMode(flashMode: CameraFlashMode) {
        
        captureSession?.beginConfiguration()
        
        let devices = AVCaptureDevice.devicesWithMediaType(AVMediaTypeVideo)
        
        for  device in devices  {
            
            let captureDevice = device as! AVCaptureDevice
            
            if (captureDevice.position == AVCaptureDevicePosition.Back) {
                
                let avFlashMode = AVCaptureFlashMode(rawValue: flashMode.rawValue)
                
                if (captureDevice.isFlashModeSupported(avFlashMode!)) {
                    
                    do {
                        try captureDevice.lockForConfiguration()
                    }
                    catch {
                        return
                    }
                    captureDevice.flashMode = avFlashMode!
                    captureDevice.unlockForConfiguration()
                }
            }
        }
        captureSession?.commitConfiguration()
    }
    
    private func updateCameraQualityMode(newCameraOutputQuality: CameraOutputQuality) {
        
        if let validCaptureSession = captureSession {
            
            var sessionPreset = AVCaptureSessionPresetLow
            
            switch (newCameraOutputQuality) {
                
            case CameraOutputQuality.Low:
                sessionPreset = AVCaptureSessionPresetLow
            case CameraOutputQuality.Medium:
                sessionPreset = AVCaptureSessionPresetMedium
            case CameraOutputQuality.High:
                if cameraOutputMode == .StillImage {
                    sessionPreset = AVCaptureSessionPresetPhoto
                }
                else {
                    sessionPreset = AVCaptureSessionPresetHigh
                }
            }
            
            if validCaptureSession.canSetSessionPreset(sessionPreset) {
                validCaptureSession.beginConfiguration()
                validCaptureSession.sessionPreset = sessionPreset
                validCaptureSession.commitConfiguration()
            }
            else {
                
                let err = NSError(localizedDescription: "Preset not supported",
                    localizedFailureReason: "Camera preset not supported. Please try another one.",
                    code: CameraError.CameraPresetNotSupported.rawValue,
                    domain: cameraKitErrorDomain)
                
                cameraError?(err)
            }
        }
        else {
            
            let err = NSError(localizedDescription: "Camera error. ",
                localizedFailureReason: "No valid capture session found, I can't take any pictures or videos.",
                code: CameraError.NoValidCaptureSession.rawValue,
                domain: cameraKitErrorDomain)
            
            cameraError?(err)
        }
    }
    
    private func stopProcess(reachedMaxAllowedLenght:Bool) {
        
        let url = self.filePathUrl()
        
        self.fileIndex++
        
        self.isCapturing = false
        
        dispatch_async(self.sessionQueue, {() -> Void in
            
            self.videoWriter!.finish({() -> Void in
                
                self.isCapturing = false
                self.videoWriter = nil
                self.timer       = nil
                
                self.updateTorch(.Off)
                
                // Get a reference to our helper
                let helper = PGMCameraKitHelper()
                
                // Save the image to library
                helper.saveVideoAsAsset(url, completion: { (localIdentifier, error) -> () in
                    
                    print("save completed")
                    
                    if reachedMaxAllowedLenght == false {
                        // Manual stop
                        self.executeVideoCompletitionWithURL(url, error: error, localIdentifier: localIdentifier)
                    }
                    else {
                        // Automatic stop: remove manually the link
                        self.cameraMaxAllowedLength?(url, error, localIdentifier)
                    }
                    
                })
            })
        })
    }
    
    private func addPreeviewLayerToView(view: UIView) {
        embedingView = view
        dispatch_async(dispatch_get_main_queue(), { () -> () in
            guard let _ = self.previewLayer else {
                return
            }
            self.previewLayer!.frame = view.layer.bounds
            view.clipsToBounds = true
            view.layer.addSublayer(self.previewLayer!)
        })
    }
    
    // MARK: Completion callbaks
    
    private func executeVideoCompletitionWithURL(url: NSURL?, error: NSError?, localIdentifier: LocalIdentifierType?) {
        
        if let validCompletition = videoCompletition {
            
            validCompletition(url, error, localIdentifier)
            videoCompletition = nil
        }
    }
    
    // MARK: Clean up
    
    /**
    Stops running capture session and removes all setup devices, inputs and outputs.
    */
    private func stopAndRemoveCaptureSession() {
        
        stopCaptureSession()
        cameraDevice        = .Back
        cameraIsSetup       = false
        previewLayer        = nil
        captureSession      = nil
        frontCameraDevice   = nil
        backCameraDevice    = nil
        mic                 = nil
        stillImageOutput    = nil
        movieOutput         = nil
        audioOutput         = nil
        library             = nil
        timer               = nil
    }
    
    private func removeMicInput() {
        
        guard let inputs = captureSession?.inputs as? [AVCaptureInput] else { return }
        
        for input in inputs {
            
            if let deviceInput = input as? AVCaptureDeviceInput {
                
                if deviceInput.device == mic {
                    captureSession?.removeInput(deviceInput)
                    break;
                }
            }
        }
    }
    
    // MARK: Helper Functions
    
    private func filePath() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)
        let documentsDirectory = paths[0] as String
        let filePath : String = "\(documentsDirectory)/video\(self.fileIndex).mp4"
        let _ = NSURL(fileURLWithPath: filePath)
        return filePath
    }
    
    private func filePathUrl() -> NSURL! {
        return NSURL(fileURLWithPath: self.filePath())
    }
    
    private func deviceInputFromDevice(device: AVCaptureDevice?) -> AVCaptureDeviceInput? {
        
        guard let validDevice = device else {
            return nil
        }
        
        do {
            return try AVCaptureDeviceInput(device: validDevice)
        }
        catch let outError as NSError {
            
            let err = NSError(localizedDescription: "Device setup error occured: \(outError.localizedDescription)",
                localizedFailureReason: outError.localizedFailureReason,
                code: CameraError.DeviceSetupError.rawValue,
                domain: cameraKitErrorDomain)
            
            cameraError?(err)
            
            return nil
        }
        catch {
            return nil
        }
    }
    
    private func canLoadCamera() -> Bool {
        let currentCameraState = checkIfCameraIsAvailable()
        return currentCameraState == .Ready || (currentCameraState == .NotDetermined)
    }
    
    private func checkIfCameraIsAvailable() -> CameraState {
        
        let deviceHasCamera = UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Rear) || UIImagePickerController.isCameraDeviceAvailable(UIImagePickerControllerCameraDevice.Front)
        
        if deviceHasCamera {
            
            let authorizationStatus = AVCaptureDevice.authorizationStatusForMediaType(AVMediaTypeVideo)
            
            let userAgreedToUseIt = authorizationStatus == .Authorized
            
            if userAgreedToUseIt {
                return .Ready
            }
            else if authorizationStatus == AVAuthorizationStatus.NotDetermined {
                return .NotDetermined
            }
            else {
                
                let err = NSError(localizedDescription: "Camera access denied",
                    localizedFailureReason: "Go to settings and grant acces to the camera device to use it.",
                    code: CameraError.CameraAccessDeniend.rawValue,
                    domain: cameraKitErrorDomain)
                
                cameraError?(err)
                
                return .AccessDenied
            }
        }
        else {
            
            let err = NSError(localizedDescription: "Camera unavailable",
                localizedFailureReason: "The device does not have a camera.",
                code: CameraError.CameraUnavailable.rawValue,
                domain: cameraKitErrorDomain)
            
            cameraError?(err)
            
            return .NoDeviceFound
        }
    }
    
    
    // MARK: deinit
    
    deinit {
        stopAndRemoveCaptureSession()
        stopFollowingDeviceOrientation()
    }
}
