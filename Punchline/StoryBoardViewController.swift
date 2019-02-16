//
//  StoryBoardViewController.swift
//  Punchline
//
//  Created by Justin Heo on 1/24/19.
//  Copyright © 2019 jstnheo. All rights reserved.
//

import UIKit
import MobileCoreServices
import MediaPlayer
import Photos
import MBProgressHUD

enum ContentType {
    case intro
    case setup
    case punchline
}

struct Content {
    var type: ContentType
    var asset: AVAsset?
    
    init(type: ContentType) {
        self.type = type
    }
}

struct Story {
    var intro = Content(type: .intro)
    var setup = Content(type: .setup)
    var punchline = Content(type: .punchline)
    
    var lastSelected: ContentType?
}

class StoryBoardViewController: UIViewController {
    var story = Story()
    var lastSelectedButton: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
        title = "Punchline MVP"
    }
    
    func exportDidFinish(_ session: AVAssetExportSession) {
        
        // Cleanup assets
        MBProgressHUD.hide(for: view, animated: true)

        guard session.status == AVAssetExportSession.Status.completed,
            let outputURL = session.outputURL else {
                return
        }
        
        let saveVideoToPhotos = {
            PHPhotoLibrary.shared().performChanges({ PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: outputURL) }) { saved, error in
                let success = saved && (error == nil)
                let title = success ? "Success" : "Error"
                let message = success ? "Video saved" : "Failed to save video"
                
                let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
                self.present(alert, animated: true, completion: nil)
            }
        }
        
        // Ensure permission to access Photo Library
        if PHPhotoLibrary.authorizationStatus() != .authorized {
            PHPhotoLibrary.requestAuthorization({ status in
                if status == .authorized {
                    saveVideoToPhotos()
                }
            })
        } else {
            saveVideoToPhotos()
        }
    }
    
    func savedPhotosAvailable() -> Bool {
        guard !UIImagePickerController.isSourceTypeAvailable(.savedPhotosAlbum) else { return true }
        
        let alert = UIAlertController(title: "Not Available", message: "No Saved Album found", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: UIAlertAction.Style.cancel, handler: nil))
        present(alert, animated: true, completion: nil)
        return false
    }
    
    @IBAction func onIntro(_ sender: Any) {
        if savedPhotosAvailable() {
            story.lastSelected = .intro
            VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
        }
    }
    
    @IBAction func onSetup(_ sender: Any) {
        if savedPhotosAvailable() {
            story.lastSelected = .setup
            VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
        }
    }
    
    @IBAction func onPunchline(_ sender: Any) {
        if savedPhotosAvailable() {
            story.lastSelected = .punchline
            VideoHelper.startMediaBrowser(delegate: self, sourceType: .savedPhotosAlbum)
        }
    }
    
    @IBAction func mergeAndSave(_ sender: Any) {
        MBProgressHUD.showAdded(to: view, animated: true)
        
        guard let introAsset = story.intro.asset, let setupAsset = story.setup.asset, let punchlineAsset = story.punchline.asset  else {
            assert(false, "Missing assets")
            return
        }
        
        let videoAssets = [introAsset, setupAsset, punchlineAsset]
        
        let mixComposition = AVMutableComposition()
        var totalTime = CMTime.zero
        var layerInstructionsArray: [AVVideoCompositionLayerInstruction] = []
        for videoAsset in videoAssets {
            guard let videoTrack = mixComposition.addMutableTrack(withMediaType: .video, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else {
                assert(false, "Failed to load first track")
                return
            }
            do {
                try videoTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: videoAsset.duration), of: videoAsset.tracks(withMediaType: .video)[0], at: totalTime)
            } catch {
                assert(false, "Failed to load first track")
                return
            }
            
            guard let audioTrack = mixComposition.addMutableTrack(withMediaType: .audio, preferredTrackID: Int32(kCMPersistentTrackID_Invalid)) else {
                assert(false, "Failed to load first track")
                return
            }
            
            do {
                try audioTrack.insertTimeRange(CMTimeRangeMake(start: .zero, duration: videoAsset.duration), of: videoAsset.tracks(withMediaType: .audio)[0], at: totalTime)
            } catch {
                assert(false, "Failed to load first audio track")
                return
            }
            
            totalTime = totalTime + videoAsset.duration
         
            let videoInstruction = VideoHelper.videoCompositionInstruction(videoTrack, asset: videoAsset)
            if videoAsset != videoAssets.last {
                videoInstruction.setOpacity(0.0, at: totalTime)
            }
            layerInstructionsArray.append(videoInstruction)
        }

        // 2.1
        let mainInstruction = AVMutableVideoCompositionInstruction()
        mainInstruction.timeRange = CMTimeRangeMake(start: .zero, duration: totalTime)
        mainInstruction.layerInstructions = layerInstructionsArray
        
        let mainComposition = AVMutableVideoComposition()
        mainComposition.instructions = [mainInstruction]
        mainComposition.frameDuration = CMTimeMake(value: 1, timescale: 30)
        mainComposition.renderSize = CGSize(width: view.bounds.size.width, height: view.bounds.size.height + 100)
        
        
        // 4 - Get path
        guard let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .long
        dateFormatter.timeStyle = .short
        let date = dateFormatter.string(from: Date())
        let url = documentDirectory.appendingPathComponent("mergeVideo-\(date).mov")
        
        // 5 - Create Exporter
        guard let exporter = AVAssetExportSession(asset: mixComposition, presetName: AVAssetExportPresetHighestQuality) else { return }
        exporter.outputURL = url
        exporter.outputFileType = AVFileType.mov
        exporter.shouldOptimizeForNetworkUse = false
        exporter.videoComposition = mainComposition
        
        // 6 - Perform the Export
        exporter.exportAsynchronously() {
            DispatchQueue.main.async {
                self.exportDidFinish(exporter)
            }
        }
    }
}

extension StoryBoardViewController: UINavigationControllerDelegate {}

extension StoryBoardViewController: UIImagePickerControllerDelegate {
    func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
        dismiss(animated: true, completion: nil)
        guard let mediaURL = info[UIImagePickerController.InfoKey.mediaURL] as? URL else {
            return
        }
        
        guard let lastSelectedType = story.lastSelected else {
            return
        }
        let avAsset = AVAsset(url: mediaURL)
        var message = ""
        switch lastSelectedType {
        case .intro:
            message = "Intro loaded"
            story.intro.asset = avAsset
        case .setup:
            message = "Setup loaded"
            story.setup.asset = avAsset
        case .punchline:
            message = "Punchline loaded"
            story.punchline.asset = avAsset
        }
        
        let alert = UIAlertController(title: "Asset Loaded", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .cancel, handler: nil))
        present(alert, animated: true, completion: nil)
    }
}
