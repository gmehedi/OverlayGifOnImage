//
//  DemoVC.swift
//  SwiftGif
//
//  Created by Mustafa Hastürk on 16/02/16.
//  Copyright © 2016 Arne Bahlo. All rights reserved.
//

import UIKit
import AVFoundation

class DemoVC: UIViewController {
    
    var outputSize: CGSize!
    var newSize: CGSize!
    //  let outputSize = CGSize(width: 1920, height: 1280)
    let imagesPerSecond: Double = 10 //each image will be stay for 3 secs
    var selectedPhotosArray = [UIImage]()
    var imageArrayToVideoURL = NSURL()
    let audioIsEnabled: Bool = false //if your video has no sound
    var asset: AVAsset!
    
    @IBOutlet weak var topView: UIView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.outputSize = CGSize(width: 1920, height: 1280)
        let gUrl = Bundle.main.url(forResource: "meraj", withExtension: "gif")
        let vUrl = Bundle.main.url(forResource: "video", withExtension: "mp4")! as URL
        
        self.buildVideoFromImageArray(image: UIImage(named: "me2")!.fixOrientation()!)
        
    }
    
}


extension DemoVC {
    
    func buildVideoFromImageArray(image: UIImage) {
        
        selectedPhotosArray.append(image)
        imageArrayToVideoURL = NSURL(fileURLWithPath: NSHomeDirectory() + "/Documents/video1.MP4")
        
        removeFileAtURLIfExists(url: imageArrayToVideoURL)
        guard let videoWriter = try? AVAssetWriter(outputURL: imageArrayToVideoURL as URL, fileType: AVFileType.mp4) else {
            fatalError("AVAssetWriter error")
        }
        let outputSettings = [AVVideoCodecKey : AVVideoCodecH264, AVVideoWidthKey : NSNumber(value: Float(self.outputSize.width)), AVVideoHeightKey : NSNumber(value: Float(self.outputSize.height))] as [String : Any]
        guard videoWriter.canApply(outputSettings: outputSettings, forMediaType: AVMediaType.video) else {
            fatalError("Negative : Can't apply the Output settings...")
        }
        let videoWriterInput = AVAssetWriterInput(mediaType: AVMediaType.video, outputSettings: outputSettings)
        let sourcePixelBufferAttributesDictionary = [kCVPixelBufferPixelFormatTypeKey as String : NSNumber(value: kCVPixelFormatType_32ARGB), kCVPixelBufferWidthKey as String: NSNumber(value: Float(self.outputSize.width)), kCVPixelBufferHeightKey as String: NSNumber(value: Float(self.outputSize.height))]
        let pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: videoWriterInput, sourcePixelBufferAttributes: sourcePixelBufferAttributesDictionary)
        if videoWriter.canAdd(videoWriterInput) {
            videoWriter.add(videoWriterInput)
        }
        if videoWriter.startWriting() {
            let zeroTime = CMTimeMake(value: Int64(self.imagesPerSecond),timescale: Int32(1))
            print("Zero Time ", zeroTime)
            videoWriter.startSession(atSourceTime: zeroTime)
            
            assert(pixelBufferAdaptor.pixelBufferPool != nil)
            let media_queue = DispatchQueue(label: "mediaInputQueue")
            videoWriterInput.requestMediaDataWhenReady(on: media_queue, using: { () -> Void in
                let fps: Int32 = 1
                let framePerSecond: Int64 = Int64(self.imagesPerSecond)
                
                var frameCount: Int64 = 0
                var appendSucceeded = true
                while (!self.selectedPhotosArray.isEmpty) {
                    if (videoWriterInput.isReadyForMoreMediaData) {
                        let nextPhoto = self.selectedPhotosArray.remove(at: 0)
                        let presentationTime =  CMTimeMake(value: frameCount * framePerSecond, timescale: fps)
                        
                        print("Last  ", presentationTime)
                        var pixelBuffer: CVPixelBuffer? = nil
                        let status: CVReturn = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pixelBufferAdaptor.pixelBufferPool!, &pixelBuffer)
                        if let pixelBuffer = pixelBuffer, status == 0 {
                            let managedPixelBuffer = pixelBuffer
                            CVPixelBufferLockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                            let data = CVPixelBufferGetBaseAddress(managedPixelBuffer)
                            let rgbColorSpace = CGColorSpaceCreateDeviceRGB()
                            let context = CGContext(data: data, width: Int(self.outputSize.width), height: Int(self.outputSize.height), bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(managedPixelBuffer), space: rgbColorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue)
                            context!.clear(CGRect(x: 0, y: 0, width: CGFloat(self.outputSize.width), height: CGFloat(self.outputSize.height)))
                            let horizontalRatio = CGFloat(self.outputSize.width) / nextPhoto.size.width
                            let verticalRatio = CGFloat(self.outputSize.height) / nextPhoto.size.height
                            //let aspectRatio = max(horizontalRatio, verticalRatio) // ScaleAspectFill
                            let aspectRatio = min(horizontalRatio, verticalRatio) // ScaleAspectFit
                            self.newSize = CGSize(width: nextPhoto.size.width * aspectRatio, height: nextPhoto.size.height * aspectRatio)
                            let x = self.newSize.width < self.outputSize.width ? (self.outputSize.width - self.newSize.width) / 2 : 0
                            let y = self.newSize.height < self.outputSize.height ? (self.outputSize.height - self.newSize.height) / 2 : 0
                            context?.draw(nextPhoto.cgImage!, in: CGRect(x: x, y: y, width: self.newSize.width, height: self.newSize.height))
                            CVPixelBufferUnlockBaseAddress(managedPixelBuffer, CVPixelBufferLockFlags(rawValue: CVOptionFlags(0)))
                            if self.selectedPhotosArray.count == 0 {
                                appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                                let total = CMTimeAdd(presentationTime, CMTime(value: CMTimeValue(self.imagesPerSecond), timescale: fps))
                                print("TTTT  ", total)
                                appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: total)
                            }else{
                                appendSucceeded = pixelBufferAdaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                            }
                            
                        } else {
                            print("Failed to allocate pixel buffer")
                            appendSucceeded = false
                        }
                        frameCount += 1
                    }
                    if !appendSucceeded {
                        break
                    }
                    
                }
                videoWriterInput.markAsFinished()
                videoWriter.finishWriting { () -> Void in
                    DispatchQueue.main.async {
                        print("-----video1 url = \(self.imageArrayToVideoURL)")
                        self.asset = AVAsset(url: self.imageArrayToVideoURL as URL)
                        //self.play(url: self.imageArrayToVideoURL as URL)
                        let gUrl = Bundle.main.url(forResource: "meraj", withExtension: "gif")
                        
                      //  let img = UIImage(named: "me2")!.fixOrientation()
                      //  let tImage = img!.imageByMakingWhiteBackgroundTransparent()
                        self.exportVideoWithAnimation(videoUrl: self.imageArrayToVideoURL as URL, gifUrl: gUrl!, image: image)
                    }
                }
            })
        }
    }
}


extension DemoVC {
    
    func exportVideoWithAnimation(videoUrl: URL, gifUrl: URL, image: UIImage) {
        
        let composition = AVMutableComposition()
        let asset = AVAsset(url: videoUrl)
        let track =  asset.tracks(withMediaType: AVMediaType.video)
        print("CC  ", track.count)
        let videoTrack:AVAssetTrack = track[0] as AVAssetTrack
        let timerange = CMTimeRangeMake(start: CMTime.zero, duration: (asset.duration))
        
        let compositionVideoTrack:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.video, preferredTrackID: CMPersistentTrackID())!
        
        do {
            try compositionVideoTrack.insertTimeRange(timerange, of: videoTrack, at: CMTime.zero)
            compositionVideoTrack.preferredTransform = videoTrack.preferredTransform
        } catch {
            print(error)
        }
        
        //if your video has sound, you don’t need to check this
        if audioIsEnabled {
            let compositionAudioTrack:AVMutableCompositionTrack = composition.addMutableTrack(withMediaType: AVMediaType.audio, preferredTrackID: CMPersistentTrackID())!
            
            for audioTrack in (asset.tracks(withMediaType: AVMediaType.audio)) {
                do {
                    try compositionAudioTrack.insertTimeRange(audioTrack.timeRange, of: audioTrack, at: CMTime.zero)
                } catch {
                    print(error)
                }
            }
        }
        
        
        let nextPhoto = image
        let horizontalRatio = CGFloat(self.outputSize.width) / nextPhoto.size.width
        let verticalRatio = CGFloat(self.outputSize.height) / nextPhoto.size.height
        let aspectRatio = min(horizontalRatio, verticalRatio)
        let newSize: CGSize = CGSize(width: nextPhoto.size.width * aspectRatio, height: nextPhoto.size.height * aspectRatio)
        let x = newSize.width < self.outputSize.width ? (self.outputSize.width - newSize.width) / 2 : 0
        let y = newSize.height < self.outputSize.height ? (self.outputSize.height - newSize.height) / 2 : 0
        
        ///I showed 10 animations here. You can uncomment any of this and export a video to see the result
        
        //let size = self.newSize!
        let videoSize = videoTrack.naturalSize
        
        let parentlayer = CALayer()
        parentlayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        parentlayer.backgroundColor = UIColor.clear.cgColor
        
        let videolayer = CALayer()
        videolayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        videolayer.backgroundColor = UIColor.red.cgColor
        parentlayer.addSublayer(videolayer)
        
        let blackLayer = CALayer()
        blackLayer.frame = CGRect(x: 0, y: 0, width: videoSize.width, height: videoSize.height)
        blackLayer.backgroundColor = UIColor.clear.cgColor
        
        let imageLayer = CALayer()
        imageLayer.frame = CGRect(x: x, y: y, width: newSize.width, height: newSize.height)
        imageLayer.backgroundColor = UIColor.clear.cgColor
        imageLayer.contents = image.cgImage
        
        let gifLayer = CALayer()
        gifLayer.frame = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)
        gifLayer.backgroundColor = UIColor.clear.cgColor
        let gifAnimation = self.animationForGif(with: gifUrl)
        gifLayer.add(gifAnimation!, forKey: "basic")
        imageLayer.addSublayer(gifLayer)
        
        blackLayer.addSublayer(imageLayer)
        parentlayer.addSublayer(blackLayer)
        
        ///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
        
        let layercomposition = AVMutableVideoComposition()
        layercomposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        layercomposition.renderSize = videoSize
        layercomposition.animationTool = AVVideoCompositionCoreAnimationTool(postProcessingAsVideoLayer: videolayer, in: parentlayer)
        let instruction = AVMutableVideoCompositionInstruction()
        instruction.timeRange = CMTimeRangeMake(start: CMTime.zero, duration: composition.duration)
        let videotrack = composition.tracks(withMediaType: AVMediaType.video)[0] as AVAssetTrack
        let layerinstruction = AVMutableVideoCompositionLayerInstruction(assetTrack: videotrack)
        instruction.layerInstructions = [layerinstruction]
        layercomposition.instructions = [instruction]
        
        let animatedVideoURL = NSURL(fileURLWithPath: NSHomeDirectory() + "/Documents/video2.mp4")
        removeFileAtURLIfExists(url: animatedVideoURL)
        
        guard let assetExport = AVAssetExportSession(asset: composition, presetName:AVAssetExportPresetHighestQuality) else {return}
        assetExport.videoComposition = layercomposition
        assetExport.outputFileType = AVFileType.mp4
        assetExport.outputURL = animatedVideoURL as URL
        assetExport.exportAsynchronously(completionHandler: {
            switch assetExport.status{
            case AVAssetExportSession.Status.completed:
                DispatchQueue.main.async {
                    self.play(url: assetExport.outputURL!)
                    print("URL  :  ", assetExport.outputURL!)
                }
            case  AVAssetExportSessionStatus.failed:
                print("failed \(String(describing: assetExport.error))")
            case AVAssetExportSessionStatus.cancelled:
                print("cancelled \(String(describing: assetExport.error))")
            default:
                print("Exported")
            }
        })
    }
    
    
    func removeFileAtURLIfExists(url: NSURL) {
        if let filePath = url.path {
            let fileManager = FileManager.default
            if fileManager.fileExists(atPath: filePath) {
                do{
                    try fileManager.removeItem(atPath: filePath)
                } catch let error as NSError {
                    print("Couldn't remove existing destination file: \(error)")
                }
            }
        }
    }
    
    func play(url: URL){
        let player = AVPlayer(url: url)
        let playerLayer = AVPlayerLayer(player: player)
        playerLayer.frame = self.topView.bounds
        self.topView.layer.addSublayer(playerLayer)
        player.play()
    }
}


extension DemoVC {
    func animationForGif(with url: URL?) -> CAKeyframeAnimation? {
        
        let animation = CAKeyframeAnimation(keyPath: "contents")
        
        var frames = [CGImage]()
        var delayTimes = [NSNumber]()
        
        var totalTime: Float = 0.0
        //        var gifWidth: Float
        //        var gifHeight: Float
        let gifSource = CGImageSourceCreateWithURL(url! as CFURL, nil)
        // get frame count
        let frameCount = CGImageSourceGetCount(gifSource!)
        for i in 0..<frameCount {
            // get each frame
            let frame = CGImageSourceCreateImageAtIndex(gifSource!, i, nil)
            if let frame = frame {
                print("Frame  ", frame)
                frames.append(frame)
            }
            
            // get gif info with each frame
            var dict = CGImageSourceCopyPropertiesAtIndex(gifSource!, i, nil) as? [CFString: AnyObject]
            
            // get gif size
            //gifWidth = (dict?[kCGImagePropertyPixelWidth] as? NSNumber)?.floatValue ?? 0.0
            //gifHeight = (dict?[kCGImagePropertyPixelHeight] as? NSNumber)?.floatValue ?? 0.0
            let gifDict = dict?[kCGImagePropertyGIFDictionary]
            if let value = gifDict?[kCGImagePropertyGIFDelayTime] as? NSNumber {
                delayTimes.append(value)
            }
            
            totalTime = totalTime + (((gifDict?[kCGImagePropertyGIFDelayTime] as? NSNumber)?.floatValue)!)
            
        }
        
        var times = [AnyHashable](repeating: 0, count: 3)
        var currentTime: Float = 0
        let count: Int = delayTimes.count
        for i in 0..<count {
            times.append(NSNumber(value: Float((currentTime / totalTime))))
            currentTime += Float(truncating: delayTimes[i])
        }
        
        var images = [AnyHashable](repeating: 0, count: 3)
        for i in 0..<count {
            print("Image  ", i)
            images.append(frames[i])
        }
        
        animation.keyTimes = times as? [NSNumber]
        animation.values = images
        animation.timingFunction = CAMediaTimingFunction(name: .linear)
        animation.duration = CFTimeInterval(totalTime)
        animation.repeatCount = Float.infinity
        
        animation.beginTime = AVCoreAnimationBeginTimeAtZero
        animation.isRemovedOnCompletion = false
        return animation
        
    }
}

extension UIImage {
    
    func fixOrientation() -> UIImage? {
        guard let cgImage = self.cgImage else {
            return nil
        }
        
        if self.imageOrientation == UIImage.Orientation.up {
            return self
        }
        
        let width  = self.size.width
        let height = self.size.height
        
        var transform = CGAffineTransform.identity
        
        switch self.imageOrientation {
        case .down, .downMirrored:
            transform = transform.translatedBy(x: width, y: height)
            transform = transform.rotated(by: CGFloat.pi)
            
        case .left, .leftMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.rotated(by: 0.5*CGFloat.pi)
            
        case .right, .rightMirrored:
            transform = transform.translatedBy(x: 0, y: height)
            transform = transform.rotated(by: -0.5*CGFloat.pi)
            
        case .up, .upMirrored:
            break
        }
        
        switch self.imageOrientation {
        case .upMirrored, .downMirrored:
            transform = transform.translatedBy(x: width, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        case .leftMirrored, .rightMirrored:
            transform = transform.translatedBy(x: height, y: 0)
            transform = transform.scaledBy(x: -1, y: 1)
            
        default:
            break;
        }
        
        // Now we draw the underlying CGImage into a new context, applying the transform
        // calculated above.
        guard let colorSpace = cgImage.colorSpace else {
            return nil
        }
        
        guard let context = CGContext(
            data: nil,
            width: Int(width),
            height: Int(height),
            bitsPerComponent: cgImage.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: UInt32(cgImage.bitmapInfo.rawValue)
        ) else {
            return nil
        }
        
        context.concatenate(transform);
        
        switch self.imageOrientation {
        
        case .left, .leftMirrored, .right, .rightMirrored:
            // Grr...
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: height, height: width))
            
        default:
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        
        // And now we just create a new UIImage from the drawing context
        guard let newCGImg = context.makeImage() else {
            return nil
        }
        
        let img = UIImage(cgImage: newCGImg)
        
        return img;
    }
    
    func imageByMakingWhiteBackgroundTransparent() -> UIImage? {
        
        let image = UIImage(data: self.jpegData(compressionQuality: 1.0)!)!
        let rawImageRef: CGImage = image.cgImage!
        
        let colorMasking: [CGFloat] = [222, 255, 222, 255, 222, 255]
        UIGraphicsBeginImageContext(image.size);
        
        let maskedImageRef = rawImageRef.copy(maskingColorComponents: colorMasking)
        UIGraphicsGetCurrentContext()?.translateBy(x: 0.0,y: image.size.height)
        UIGraphicsGetCurrentContext()?.scaleBy(x: 1.0, y: -1.0)
        UIGraphicsGetCurrentContext()?.draw(maskedImageRef!, in: CGRect.init(x: 0, y: 0, width: image.size.width, height: image.size.height))
        let result = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
        return result
        
    }
}
