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
import AVFoundation
import AssetsLibrary

@objc class PGMCameraKitWriter : NSObject{
    
    
    // MARK: Members
    
    var fileWriter: AVAssetWriter!
    var videoInput: AVAssetWriterInput!
    var audioInput: AVAssetWriterInput!
    
    
    // MARK: Init / Deinit
    
    internal init(fileUrl:NSURL, height:Int, width:Int, channels:Int, samples:Float64) {
        
        guard let writer = try? AVAssetWriter(URL: fileUrl, fileType: AVFileTypeQuickTimeMovie) else {
            fatalError("AVAssetWriter error")
        }
        
        fileWriter = writer
        
        // Video
        let videoOutputSettings = [AVVideoCodecKey  : AVVideoCodecH264,
                                   AVVideoWidthKey  : NSNumber(int: Int32(width)),
                                   AVVideoHeightKey : NSNumber(int: Int32(height))]
        
        guard writer.canApplyOutputSettings(videoOutputSettings, forMediaType: AVMediaTypeVideo) else {
            fatalError("Can't apply the Output settings for video media.")
        }
        
        videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings)
        videoInput.expectsMediaDataInRealTime = true
        if width > height {
            videoInput.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        }

        fileWriter.addInput(self.videoInput)
        
        // Audio
        let audioOutputSettings = [ AVFormatIDKey : Int(kAudioFormatMPEG4AAC),
                                    AVNumberOfChannelsKey : Int(channels),
                                    AVSampleRateKey : Int(samples),
                                    AVEncoderBitRateKey : Int(64000)
        ]
        
        guard writer.canApplyOutputSettings(audioOutputSettings, forMediaType: AVMediaTypeAudio) else {
            fatalError("Can't apply the Output settings for audio media.")
        }
        
        self.audioInput = AVAssetWriterInput(mediaType: AVMediaTypeAudio, outputSettings: audioOutputSettings)
        self.audioInput.expectsMediaDataInRealTime = true
        self.fileWriter.addInput(self.audioInput)
    }
    
    internal init(fileUrl:NSURL, height:Int, width:Int) {
        
        guard let writer = try? AVAssetWriter(URL: fileUrl, fileType: AVFileTypeQuickTimeMovie) else {
            fatalError("AVAssetWriter error")
        }
        
        fileWriter = writer
        
        // Video
        let videoOutputSettings = [AVVideoCodecKey  : AVVideoCodecH264,
            AVVideoWidthKey  : NSNumber(int: Int32(width)),
            AVVideoHeightKey : NSNumber(int: Int32(height))]
        
        guard writer.canApplyOutputSettings(videoOutputSettings, forMediaType: AVMediaTypeVideo) else {
            fatalError("Can't apply the Output settings for video media.")
        }
        
        videoInput = AVAssetWriterInput(mediaType: AVMediaTypeVideo, outputSettings: videoOutputSettings)
        videoInput.expectsMediaDataInRealTime = true
        if width > height {
            videoInput.transform = CGAffineTransformMakeRotation(CGFloat(M_PI_2))
        }

        
        fileWriter.addInput(self.videoInput)
    }
    
    deinit {
        
        fileWriter = nil
        videoInput = nil
        audioInput = nil
    }
    
    
    // MARK: Writter
    
    internal func write(sample: CMSampleBufferRef, isVideo: Bool){
        
        if CMSampleBufferDataIsReady(sample) {
            
            if self.fileWriter.status == .Unknown {
                
                print("Start writing, isVideo = \(isVideo), status = \(self.fileWriter.status.rawValue)")
                
                let startTime = CMSampleBufferGetPresentationTimeStamp(sample)
                self.fileWriter.startWriting()
                self.fileWriter.startSessionAtSourceTime(startTime)
            }
            
            if self.fileWriter.status == .Failed {
                
                print("Error occured, isVideo = \(isVideo), status = \(self.fileWriter.status.rawValue), \(self.fileWriter.error!.localizedDescription)")
                return
            }
            
            if isVideo {
                
                if self.videoInput.readyForMoreMediaData {
                    self.videoInput.appendSampleBuffer(sample)
                }
            }
            else {
                
                if self.audioInput.readyForMoreMediaData {
                    self.audioInput.appendSampleBuffer(sample)
                }
            }
        }
    }
    
    internal func finish(callback: Void -> Void){
        self.fileWriter.finishWritingWithCompletionHandler(callback)
    }
}
