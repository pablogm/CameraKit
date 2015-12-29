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
import Photos
import Accelerate

public typealias LocalIdentifierType       = String
public typealias LocalIdentifierBlock      = (localIdentifier: LocalIdentifierType?, error: NSError?) -> ()
public typealias ImageWithIdentifierBlock  = (image:UIImage?) -> ()
public typealias VideoWithIdentifierBlock  = (video:NSURL?) -> ()
public typealias FrameBuffer               = (inBuffer: vImage_Buffer, outBuffer: vImage_Buffer, pixelBuffer: UnsafeMutablePointer<Void>)

@objc public class CameraKitHelper: NSObject {

    var manager = PHImageManager.defaultManager()
    
    
    // MARK: Save Image
    
    public func saveImageAsAsset(image: UIImage, completion: LocalIdentifierBlock) {
        
        var imageIdentifier: LocalIdentifierType?
        
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> () in
            
                let changeRequest   = PHAssetChangeRequest.creationRequestForAssetFromImage(image)
                
                let placeHolder     = changeRequest.placeholderForCreatedAsset
                
                imageIdentifier = placeHolder?.localIdentifier
            
            },
            completionHandler: { (success, error) -> () in
                if success {
                    completion(localIdentifier: imageIdentifier, error: nil)
                }
                else {
                    completion(localIdentifier: nil, error: error)
                }
        })
    }
    
    
    // MARK: Save Video
    
    public func saveVideoAsAsset(videoURL: NSURL, completion: LocalIdentifierBlock) {
        
        var videoIdentifier: LocalIdentifierType?
        
        PHPhotoLibrary.sharedPhotoLibrary().performChanges({ () -> () in
            
            let changeRequest   = PHAssetChangeRequest.creationRequestForAssetFromVideoAtFileURL(videoURL)
            
            let placeHolder     = changeRequest?.placeholderForCreatedAsset
            
            videoIdentifier = placeHolder?.localIdentifier
            
            },
            completionHandler: { (success, error) -> () in
                if success {
                    completion(localIdentifier: videoIdentifier, error: nil)
                }
                else {
                    completion(localIdentifier: nil, error: error)
                }
        })
    }
    
    
    // MARK: Retrieve Image by Id
    
    public func retrieveImageWithIdentifer(localIdentifier:LocalIdentifierType, completion: ImageWithIdentifierBlock) {
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.Image.rawValue)
        let fetchResults = PHAsset.fetchAssetsWithLocalIdentifiers([localIdentifier], options: fetchOptions)
        
        if fetchResults.count > 0 {
            
            if let imageAsset = fetchResults.objectAtIndex(0) as? PHAsset {
                
                let requestOptions = PHImageRequestOptions()
                
                requestOptions.deliveryMode = .HighQualityFormat
                
                manager.requestImageForAsset(imageAsset, targetSize: PHImageManagerMaximumSize,
                                             contentMode: .AspectFill, options: requestOptions,
                                             resultHandler: { (image, info) -> () in
                    
                                                completion(image: image)
                })
            }
            else {
                completion(image: nil)
            }
        }
        else {
            completion(image: nil)
        }
    }
    
    
    // MARK: Retrive video by id
    
    public func retrieveVideoWithIdentifier(localIdentifier:LocalIdentifierType, completion: VideoWithIdentifierBlock) {
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.Video.rawValue)
        
        let fetchResults = PHAsset.fetchAssetsWithLocalIdentifiers([localIdentifier], options: fetchOptions)
        
        if fetchResults.count > 0 {
            
            if let videoAsset = fetchResults.objectAtIndex(0) as? PHAsset {
                
                /* We want to be able to display a video even if it currently
                resides only on the cloud and not on the device */
                let options = PHVideoRequestOptions()
                options.deliveryMode = .Automatic
                options.networkAccessAllowed = true
                options.version = .Current
                options.progressHandler = {(progress: Double,
                    error: NSError?,
                    stop: UnsafeMutablePointer<ObjCBool>,
                    info: [NSObject : AnyObject]?) in
                    
                    /* You can write your code here that shows a progress bar to the
                    user and then using the progress parameter of this block object, you
                    can update your progress bar. */
                }
                
                /* Now get the video */
                PHCachingImageManager().requestAVAssetForVideo(videoAsset,
                    options: options,
                    resultHandler: {(asset: AVAsset?,
                        audioMix: AVAudioMix?,
                        info: [NSObject : AnyObject]?) in
                        
                        if let asset = asset as? AVURLAsset{
                            completion(video: asset.URL)
                        } else {
                            print("This is not a URL asset. Cannot play")
                        }
                        
                })
            }
            else {
                completion(video: nil)
            }
        }
        else {
            completion(video: nil)
        }
    }
    
    
    // MARK: Compress Video
    
    public func compressVideo(inputURL: NSURL, outputURL: NSURL, outputFileType:String, handler:(session: AVAssetExportSession?)-> Void)
    {
        let urlAsset = AVURLAsset(URL: inputURL, options: nil)
        
        let exportSession = AVAssetExportSession(asset: urlAsset, presetName: AVAssetExportPresetMediumQuality)
        
        exportSession?.outputURL = outputURL
        
        exportSession?.outputFileType = outputFileType
        
        exportSession?.shouldOptimizeForNetworkUse = true
        
        exportSession?.exportAsynchronouslyWithCompletionHandler { () -> Void in
            
            handler(session: exportSession)
        }
    }
}
