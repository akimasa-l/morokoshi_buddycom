import UIKit
import Flutter
import AVFoundation

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, /*mode: .measurement,*/ options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        let morokoshiAudio = MorokoshiAudio()
        GeneratedPluginRegistrant.register(with: self)
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let eventChannel = FlutterEventChannel(name:"com.morokoshi.audio.recorder", binaryMessenger: controller.binaryMessenger)
        eventChannel.setStreamHandler(morokoshiAudio)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
}
class MorokoshiAudio:NSObject,FlutterStreamHandler{
    let engine = AVAudioEngine()
    let outputFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: true)
    
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Switch for parsing commonFormat - Can abstract later
        let input = engine.inputNode
        let bus = 0
        let inputFormat = input.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: inputFormat, to: outputFormat!)!
        
        input.installTap(onBus: bus, bufferSize: 1024, format: inputFormat) { (buffer, time) -> Void in
            var newBufferAvailable = true
            
            let inputCallback: AVAudioConverterInputBlock = { inNumPackets, outStatus in
                if newBufferAvailable {
                    outStatus.pointee = .haveData
                    newBufferAvailable = false
                    return buffer
                } else {
                    outStatus.pointee = .noDataNow
                    return nil
                }
            }
            
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.outputFormat!, frameCapacity: AVAudioFrameCount(self.outputFormat!.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate))!
            
            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
            assert(status != .error)
            
            /* if (self.outputFormat?.commonFormat == AVAudioCommonFormat.pcmFormatInt16) {
             let values = UnsafeBufferPointer(start: convertedBuffer.int16ChannelData![0], count: Int(convertedBuffer.frameLength))
             let arr = Array(values)
             events(arr)
             }
             else{
             let values = UnsafeBufferPointer(start: convertedBuffer.int32ChannelData![0], count: Int(convertedBuffer.frameLength))
             let arr = Array(values)
             events(arr)
             } */let length = Int(convertedBuffer.frameLength)
            let values = UnsafeBufferPointer(start: convertedBuffer.floatChannelData![0], count: length)
            /* let arr = Array(unsafeUninitializedCapacity:length){(_ buffer: inout UnsafeMutableBufferPointer<Float>, _ initializedCount: inout Int)  in 
             buffer=values
             initializedCount=length
             } */
            let arr = Data(buffer:values)
            events(FlutterStandardTypedData(float32:arr))
        }
        
        try! engine.start()
        return nil
    }
    public func onCancel(withArguments arguments: Any?) -> FlutterError? {
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        return nil
    }
}
