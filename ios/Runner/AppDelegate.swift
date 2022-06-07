import UIKit
import Flutter
import AVFoundation

var memo = toPCMBuffer1(data:NSData(data:Data(capacity: 1024)))!

func toPCMBuffer1(data: NSData) -> AVAudioPCMBuffer? {
    let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)!  // given NSData audio format
    guard let PCMBuffer = AVAudioPCMBuffer(pcmFormat: audioFormat, frameCapacity: UInt32(data.length) / audioFormat.streamDescription.pointee.mBytesPerFrame) else {
        return nil
    }
    PCMBuffer.frameLength = PCMBuffer.frameCapacity
    let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: Int(PCMBuffer.format.channelCount))
    data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
    return PCMBuffer
}

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    let morokoshiAudio = MorokoshiAudio()
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setCategory(.record, /*mode: .measurement,*/ options: .duckOthers)
        try? audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        
        GeneratedPluginRegistrant.register(with: self)
        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let eventChannel = FlutterEventChannel(name:"com.morokoshi.audio.recorder", binaryMessenger: controller.binaryMessenger)
        eventChannel.setStreamHandler(morokoshiAudio)
        let batteryChannel = FlutterMethodChannel(name: "com.morokoshi.audio.player",
                                                  binaryMessenger: controller.binaryMessenger)
        batteryChannel.setMethodCallHandler({
            [self]  (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in
            // Note: this method is invoked on the UI thread.
            // Handle battery messages.
            switch call.method{
            case "play":
                let arguments = call.arguments as! [String: Any]
                let byte = arguments["byte"] as! FlutterStandardTypedData
                let data = NSData(data:byte.data)
                morokoshiAudio.play(data: NSData(data:byte.data)){
                    [self] in
                    result(nil)
                }
                result(nil)
                return
            case "ready":
                result(nil)
                return
            default:
                result(FlutterMethodNotImplemented)
                return
            }
        }
        )
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
    
}
class MorokoshiAudio:NSObject,FlutterStreamHandler{
    let engine = AVAudioEngine()
    let audioFormat = AVAudioFormat(commonFormat: AVAudioCommonFormat.pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: true)!
    public func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        // Switch for parsing commonFormat - Can abstract later
        let input = engine.inputNode
        let bus = 0
        let inputFormat = input.outputFormat(forBus: 0)
        let converter = AVAudioConverter(from: inputFormat, to: audioFormat)!
        
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
            let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.audioFormat, frameCapacity: AVAudioFrameCount(self.audioFormat.sampleRate) * buffer.frameLength / AVAudioFrameCount(buffer.format.sampleRate))!
            memo = convertedBuffer
            var error: NSError?
            let status = converter.convert(to: convertedBuffer, error: &error, withInputFrom: inputCallback)
            assert(status != .error)
            let length = Int(convertedBuffer.frameLength)
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
    
    func toPCMBuffer(data: NSData) -> AVAudioPCMBuffer? {
        // let audioFormat = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 8000, channels: 1, interleaved: false)!  // given NSData audio format
        guard let PCMBuffer = AVAudioPCMBuffer(pcmFormat: self.audioFormat, frameCapacity: UInt32(data.length) / self.audioFormat.streamDescription.pointee.mBytesPerFrame) else {
            return nil
        }
        PCMBuffer.frameLength = PCMBuffer.frameCapacity
        let channels = UnsafeBufferPointer(start: PCMBuffer.floatChannelData, count: Int(PCMBuffer.format.channelCount))
        data.getBytes(UnsafeMutableRawPointer(channels[0]) , length: data.length)
        return PCMBuffer
    }
    
    public func play(data:NSData, completionHandler:@escaping ()->Void){
        let buffer = toPCMBuffer(data:data)!
        let engine = AVAudioEngine()
        let audioPlayerNode = AVAudioPlayerNode() //The node that will play the actual sound
        engine.attach(audioPlayerNode) //Attachs the node to the engine
        // return
        engine.connect(audioPlayerNode, to: engine.outputNode, format: audioFormat) //Connects the applause playback node to the sound output
        // return
        audioPlayerNode.scheduleBuffer(buffer, completionHandler:completionHandler)
        
        if(engine.isRunning){
          print("engine is running")
          completionHandler()
          return
        }
        engine.prepare()
        
        try?engine.start()
        audioPlayerNode.play()
    }
}
