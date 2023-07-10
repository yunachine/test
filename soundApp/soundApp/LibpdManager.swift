//
//  LibpdManager.swift
//  TRI_NITRO
//
//  Created by Yoshihito Nakanishi on 2019/03/21.
//  Copyright © 2019 YoshihitoNakanishi. All rights reserved.
//

import UIKit
import AVKit

@objc protocol LibpdManagerDelegate {
    func receivedFloat(_ source: String, value: Float)
}

class LibpdManager: NSObject, PdListener {

    weak var delegate: LibpdManagerDelegate? = nil
    
    private var audioController: PdAudioController?
    private var patch: UnsafeMutableRawPointer?

    var dispatcher = PdDispatcher()
    
    static var shared: LibpdManager = {
        return LibpdManager()
    }()
    
    private override init() {
        super.init()
        addAudioSessionObservers()
    }
    
    public func setup(){
        
        setupAudio()
        
        //libpd
        dispatcher = PdDispatcher()
        dispatcher.add(self, forSource: "Vol")
        PdBase.setDelegate(dispatcher)

        printAudioRoute()
    }
    
    
    func setupAudio(){
        
        let currentSampleRate = AVAudioSession.sharedInstance().sampleRate
        
        //libpd
        audioController = PdAudioController()
        
        if let c = audioController {
            
            let s = c.configurePlayback(withSampleRate: Int32(currentSampleRate), numberChannels: 2, inputEnabled: true, mixingEnabled: true).toPdAudioControlStatus()
            
            // Print Status
            switch s{
            case .ok:
                print("[Libpd] initialize audio: success")
            case .error:
                print("[Libpd] unrecoverable error: failed to initialize audio components")
            case .propertyChanged:
                print("[Libpd] some properties have changed to run correctly (not fatal)")
            }
            
        } else {
            print("[Libpd] could not get PdAudioController")
            
        }
        
        if #available(iOS 10.0, *) {
            PdAudioController.setSessionOptions(AVAudioSession.CategoryOptions.allowBluetoothA2DP)
        } else {
            PdAudioController.setSessionOptions(AVAudioSession.CategoryOptions.allowBluetooth)
        }
        
        
    }
    
    func printAudioRoute(){
        
        let route  = AVAudioSession.sharedInstance().currentRoute
                
        if let outPort = route.outputs.first {
            if outPort.portType == AVAudioSession.Port.builtInReceiver {
                do {
                    try AVAudioSession.sharedInstance().overrideOutputAudioPort(AVAudioSession.PortOverride.speaker)
                } catch let error as NSError {
                    print("[AudioSession] couldn't set audio port from receiver to speaker. Error:\(error)")
                }
            }
            print("[AudioSession] out port name:\(outPort.portName)")
        }
        
        if let inPort = route.inputs.first {
            print("[AudioSession] in port name:\(inPort.portName)")
        }
        
    }
    
    
    public func enable(_ state: Bool){
        audioController?.isActive = state
    }
    
    
    public func openPatch(_ patchName: String) -> Bool{
        
        //libpd
        self.patch = PdBase.openFile(patchName, path: Bundle.main.resourcePath)
        if patch == nil {
            print("[Libpd] Failed to open patch!")
            return false
        } else {
            return true
        }
    }
    
    public func closePatch(){
        PdBase.closeFile(self.patch)
        self.patch = nil
    }
    
    
    //MARK: - PdListener CALLBACK
    func receive(_ received: Float, fromSource source: String!) {
        self.delegate?.receivedFloat(source, value: received)
    }
    
    /// 電話による割り込みと、オーディオルートの変化を監視
    func addAudioSessionObservers() {
        
        AVAudioSession.sharedInstance()
        let center = NotificationCenter.default
        center.addObserver(self, selector: #selector(self.handleInterruption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        center.addObserver(self, selector: #selector(self.audioSessionRouteChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        
    }
    
    func removeAudioSessionObservers(){
        
        let center = NotificationCenter.default
        
        // AVAudio Session
        center.removeObserver(self, name: AVAudioSession.interruptionNotification, object: nil)
        center.removeObserver(self, name: AVAudioSession.routeChangeNotification, object: nil)

    }
    
    @objc func handleInterruption(_ notification: Notification) {
        
        let interruptionTypeObj = (notification as NSNotification).userInfo![AVAudioSessionInterruptionTypeKey] as! NSNumber
        if let interruptionType = AVAudioSession.InterruptionType(rawValue:
            interruptionTypeObj.uintValue) {
            
            switch interruptionType {
            case .began:
                // interruptionが開始した時(電話がかかってきたなど)
                // 音楽は自動的に停止される
                // (ここにUI更新処理などを書きます)
                
                //
                break
            case .ended:
                // interruptionが終了した時の処理
                //
                break
                
            @unknown default:
                fatalError()
            }
        }
        
    }
    
    /// Audio Session Route Change : ルートが変化した(ヘッドセットが抜き差しされた)
    @objc func audioSessionRouteChanged(_ notification: Notification) {
        let reasonObj = (notification as NSNotification).userInfo![AVAudioSessionRouteChangeReasonKey] as! NSNumber
        if let reason = AVAudioSession.RouteChangeReason(rawValue: reasonObj.uintValue) {
            switch reason {
                
            case .newDeviceAvailable:
                self.enable(false)
                setupAudio()
                printAudioRoute()
                self.enable(true)
                break
                
            case .oldDeviceUnavailable:
                self.enable(false)
                setupAudio()
                printAudioRoute()
                self.enable(true)
            default:
                break
            }
        }
        
    }
    
    deinit {
        
        removeAudioSessionObservers()
        
        if self.patch != nil {
            PdBase.closeFile(self.patch)
            self.patch = nil
        }
        
    }
    
    
}


// Print Status
extension PdAudioStatus {
    enum PdAudioControlStatus {
        case ok
        case error
        case propertyChanged
    }
    func toPdAudioControlStatus() -> PdAudioControlStatus {
        switch self.rawValue {
        case 0: //
            return .ok
        case -1: //
            return .error
        default: //
            return .propertyChanged
        }
    }
}
