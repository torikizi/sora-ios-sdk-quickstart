import UIKit
import Sora

// 接続するサーバーのシグナリング URL
let soraURL = URL(string: "ws://192.168.0.2:5000/signaling")!

let soraAPIPort = 3000
// チャネル ID
let soraChannelId = "ios-quickstart"

let logType = LogType.user("SoraQuickStart")

class ViewController: UIViewController {
    
    @IBOutlet weak var senderVideoView: VideoView!
    @IBOutlet weak var senderMultiplicityControl: UISegmentedControl!
    @IBOutlet weak var senderStreamingModeControl: UISegmentedControl!
    @IBOutlet weak var senderConnectButton: UIButton!
    
    @IBOutlet weak var receiverVideoView: VideoView!
    @IBOutlet weak var receiverMultiplicityControl: UISegmentedControl!
    @IBOutlet weak var receiverStreamingModeControl: UISegmentedControl!
    @IBOutlet weak var receiverConnectButton: UIButton!
    @IBOutlet weak var receiverRidControl: UISegmentedControl!

    @IBOutlet weak var speakerButton: UIButton!
    @IBOutlet weak var volumeSlider: UISlider!
    
    @IBOutlet weak var audioModeButton: UIBarButtonItem!
    
    var senderMediaChannel: MediaChannel?
    var receiverMediaChannel: MediaChannel?
    var isMuted: Bool = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        Logger.shared.level = .debug
        
        navigationItem.title = "\(soraChannelId)"
        
        speakerButton.isEnabled = false
        volumeSlider.isEnabled = false
        audioModeButton.isEnabled = false
        receiverRidControl.isEnabled = false
        receiverRidControl.selectedSegmentIndex = 0
    }
    
    @IBAction func switchCameraPosition(_ sender: AnyObject) {
        if senderMediaChannel?.isAvailable ?? false {
            // カメラの位置（前面と背面）を切り替えます。
            CameraVideoCapturer.shared.flip()
        }
    }
    
    @IBAction func connectSender(_ sender: AnyObject) {
        if let mediaChannel = senderMediaChannel {
            disconnect(mediaChannel: mediaChannel,
                       multiplicityControl: senderMultiplicityControl,
                       streamingModeControl: senderStreamingModeControl,
                       connectButton: senderConnectButton)
            senderMediaChannel = nil
        } else {
            connect(role: .sendonly,
                    multiplicityControl: senderMultiplicityControl,
                    streamingModeControl: senderStreamingModeControl,
                    connectButton: senderConnectButton,
                    videoView: senderVideoView)
            { mediaChannel in
                self.senderMediaChannel = mediaChannel
            }
        }
    }
    
    @IBAction func connectReceiver(_ sender: AnyObject) {
        if let mediaChannel = receiverMediaChannel {
            disconnect(mediaChannel: mediaChannel,
                       multiplicityControl: receiverMultiplicityControl,
                       streamingModeControl: receiverStreamingModeControl,
                       connectButton: receiverConnectButton)
            receiverMediaChannel = nil
        } else {
            connect(role: .recvonly,
                    multiplicityControl: receiverMultiplicityControl,
                    streamingModeControl: receiverStreamingModeControl,
                    connectButton: receiverConnectButton,
                    videoView: receiverVideoView)
            { mediaChannel in
                self.receiverMediaChannel = mediaChannel
                
                DispatchQueue.main.async {
                    self.speakerButton.isEnabled = true
                    self.volumeSlider.isEnabled = true
                    self.volumeSlider.value = Float(MediaStreamAudioVolume.max)
                    self.audioModeButton.isEnabled = true
                    self.receiverRidControl.isEnabled = true
                    self.receiverRidControl.selectedSegmentIndex = 0
                }
            }
        }
    }
    
    @IBAction func changeReceiverStreamingMode(_ sender: AnyObject) {
        switch receiverStreamingModeControl.selectedSegmentIndex {
        case 1: // サイマルキャスト
            receiverRidControl.isEnabled = true
        default:
            receiverRidControl.isEnabled = false
        }
    }
    
    @IBAction func changeRid(_ sender: AnyObject) {
        guard receiverMediaChannel?.connectionId != nil else {
            return
        }
        
        var request = URLRequest(url: URL(string: "http://\(soraURL.host!):\(soraAPIPort)")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Sora_20201005.RequestRtpStream", forHTTPHeaderField: "x-sora-target")
        
        var rid = "r0"
        switch receiverRidControl.selectedSegmentIndex {
        case 1:
            rid = "r1"
        case 2:
            rid = "r2"
        default:
            break
        }
        Logger.info(type: logType, message: "change rid => \(rid)")
        
        do {
            let json = ["channel_id": receiverMediaChannel!.configuration.channelId,
                        "recv_connection_id": receiverMediaChannel!.connectionId,
                        "rid": rid]
            let body = try JSONSerialization.data(withJSONObject: json, options: [])
            request.httpBody = body
            Logger.info(type: logType, message: "send request => \(request.description)")

            let task = URLSession.shared.dataTask(with: request) { (data, response, error) in
                if let error = error {
                    Logger.info(type: logType, message: "request error: \(error)")
                }
            }
            task.resume()
        } catch let error {
            Logger.info(type: logType, message: "JSON serialization error: \(error)")
        }
    }
    
    @IBAction func muteSpeaker(_ sender: AnyObject) {
        guard receiverMediaChannel != nil else {
            return
        }
        
        isMuted = !isMuted
        receiverMediaChannel!.mainStream?.audioEnabled = !isMuted
        if isMuted {
            DispatchQueue.main.async {
                self.speakerButton.setImage(UIImage(systemName: "speaker.slash.fill"),
                                            for: .normal)
            }
        } else {
            DispatchQueue.main.async {
                self.speakerButton.setImage(UIImage(systemName: "speaker.2.fill"),
                                            
                                            for: .normal)
            }
        }
    }
    
    @IBAction func changeVolume(_ sender: Any) {
        receiverMediaChannel?.mainStream?.remoteAudioVolume = Double(volumeSlider.value)
    }
    
    @IBAction func changeSpeakerMode(_ sender: Any) {
        guard senderMediaChannel != nil || receiverMediaChannel != nil else {
            return
        }
        
        let alert = UIAlertController(title: "音声モードを選択してください", message: nil, preferredStyle: .actionSheet)
        alert.addAction(.init(title: "デフォルト（通話）", style: .default) { _ in
            let _ = Sora.shared.setAudioMode(.default(category: .playAndRecord, output: .default))
        })
        alert.addAction(.init(title: "デフォルト（スピーカー）", style: .default) { _ in
            let _ = Sora.shared.setAudioMode(.default(category: .playAndRecord, output: .speaker))
        })
        alert.addAction(.init(title: "ビデオチャット（スピーカー）", style: .default) { _ in
            let _ = Sora.shared.setAudioMode(.videoChat)
        })
        alert.addAction(.init(title: "ボイスチャット（通話）", style: .default) { _ in
            let _ = Sora.shared.setAudioMode(.voiceChat(output: .default))
        })
        alert.addAction(.init(title: "ボイスチャット（スピーカー）", style: .default) { _ in
            let _ = Sora.shared.setAudioMode(.voiceChat(output: .speaker))
        })
        alert.addAction(.init(title: "キャンセル", style: .cancel, handler: nil))
        alert.popoverPresentationController?.sourceView = self.view
        let screenSize = UIScreen.main.bounds
        alert.popoverPresentationController?.sourceRect = CGRect(x: screenSize.size.width/2, y: screenSize.size.height, width: 0, height: 0)
        present(alert, animated: true)
    }
    
    func connect(role: Role,
                 multiplicityControl: UISegmentedControl,
                 streamingModeControl: UISegmentedControl,
                 connectButton: UIButton,
                 videoView: VideoView,
                 completionHandler: @escaping (MediaChannel?) -> Void) {
        DispatchQueue.main.async {
            connectButton.isEnabled = false
            multiplicityControl.isEnabled = false
            streamingModeControl.isEnabled = false
            self.audioModeButton.isEnabled = false
        }
        
        // 接続の設定を行います。
        let multistreamEnabled = multiplicityControl.selectedSegmentIndex == 1
        let simulcastEnabled = streamingModeControl.selectedSegmentIndex == 1
        let spotlightEnabled = streamingModeControl.selectedSegmentIndex == 2
        var config = Configuration(url: soraURL,
                                   channelId: soraChannelId,
                                   role: role,
                                   multistreamEnabled: multistreamEnabled)
        config.simulcastEnabled = simulcastEnabled
        config.spotlightEnabled = spotlightEnabled
        if simulcastEnabled || spotlightEnabled {
            config.videoCodec = .vp8
        }
        if simulcastEnabled {
            if role == .recvonly {
                switch receiverRidControl.selectedSegmentIndex {
                case 0:
                    config.simulcastRid = .r0
                case 1:
                    config.simulcastRid = .r1
                case 2:
                    config.simulcastRid = .r2
                default:
                    break
                }
            }
        }
        
        // 接続します。
        // connect() の戻り値 ConnectionTask はここでは使いませんが、
        // 接続試行中の状態を強制的に終了させることができます。
        let _ = Sora.shared.connect(configuration: config) { mediaChannel, error in
            // 接続に失敗するとエラーが渡されます。
            if let error = error {
                Logger.info(type: logType, message: error.localizedDescription)
                DispatchQueue.main.async {
                    connectButton.isEnabled = true
                    multiplicityControl.isEnabled = true
                    self.audioModeButton.isEnabled = false
                }
                completionHandler(nil)
                return
            }
            
            // 接続できたら VideoView をストリームにセットします。
            // マルチストリームの場合、最初に接続したストリームが mainStream です。
            // 受信専用で接続したとき、何も配信されていなければ mainStream は nil です。
            if let stream = mediaChannel!.mainStream {
                stream.videoRenderer = videoView
            }
            
            DispatchQueue.main.async {
                connectButton.isEnabled = true
                connectButton.setImage(UIImage(systemName: "stop.fill"),
                                       for: .normal)
            }
            
            completionHandler(mediaChannel!)
        }
    }
    
    func disconnect(mediaChannel: MediaChannel,
                    multiplicityControl: UISegmentedControl,
                    streamingModeControl: UISegmentedControl,
                    connectButton: UIButton) {
        if mediaChannel.isAvailable {
            // 接続解除します。
            mediaChannel.disconnect(error: nil)
        }
        
        DispatchQueue.main.async {
            multiplicityControl.isEnabled = true
            streamingModeControl.isEnabled = true
            connectButton.setImage(UIImage(systemName: "play.fill"),
                                   for: .normal)
            self.audioModeButton.isEnabled = false
            if mediaChannel == self.receiverMediaChannel {
                self.receiverRidControl.isEnabled = false
                self.speakerButton.isEnabled = false
                self.volumeSlider.isEnabled = false
            }
        }
    }
    
}

