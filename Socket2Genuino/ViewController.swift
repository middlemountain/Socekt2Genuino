import UIKit
import CoreBluetooth
import SocketIO

class ViewController: UIViewController, CBCentralManagerDelegate, CBPeripheralManagerDelegate, UITextFieldDelegate, CBPeripheralDelegate {
    
    var centralManager: CBCentralManager!
    var peripheral: CBPeripheral!
    var peripheralManager: CBPeripheralManager!
    
    var socket: SocketIOClient!
    
    //    ymid add start
    var isBlink: Bool = false
    var settingCharacteristic: CBCharacteristic!
    var outputCharacteristic: CBCharacteristic!
    //    ymid add end
    
    @IBOutlet weak var myLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()
        
        centralManager = CBCentralManager(delegate: self, queue: nil)
        peripheralManager = CBPeripheralManager(delegate: self, queue: nil)
        // Do any additional setup after loading the view, typically from a nib.
        
        
        
//      ================ソケット通信部スタート================
        let socket = SocketIOClient(socketURL: URL(string: "http://OpenAppLab-no-MacBook-Air.local:8080")!, config: [.forceWebsockets(true)])
        
        socket.on("connect") { data, ack in
            print("socket connected")
            
            print("send message")
            socket.emit("from_client", "Hello")
        }
        
        socket.on("from_server") { data, ack in
            if let msg = data[0] as? String {
                print("receive: " + msg)
                self.myLabel.text = msg
    
                //====================BLE 書き込み部　スタート=====================
                var value: CUnsignedChar
                if "ON" == msg {
                    value = 1
                }
                else {
                    value = 0
                }
                let bytes : [UInt8] = [value]
                let data = NSData(bytes: bytes, length: bytes.count)
                print(data)
                
                // ここの処理はoutPutCharacteristicを受け取ってから書く!!!!(今はエラーになるし眠いからコメントアウト)
                
//                self.peripheral.writeValue(data as Data,
//                                           for: self.outputCharacteristic,
//                                           type: CBCharacteristicWriteType.withResponse)
                
                //====================BLE 書き込み部　エンド=======================
            }
        }
        socket.connect()
    }
//        =============ソケット通信部エンド================
    
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //  接続状況が変わるたびに呼ばれる
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        print ("state: \(central.state)")
    }
    
    
    
    
    
    @IBAction func startScan(_ sender: Any) {
        centralManager.scanForPeripherals(withServices: nil, options: nil)
    }
    
    //  スキャン結果を取得
    func centralManager(_ central: CBCentralManager, didDiscover peripheral: CBPeripheral, advertisementData: [String : Any], rssi RSSI: NSNumber) {
        self.peripheral = peripheral
        self.centralManager.connect(self.peripheral, options: nil)
    }

    
    @IBAction func endScan(_ sender: Any) {
        centralManager.stopScan()
    }
    
    //  接続成功時に呼ばれる
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connect success!")
    }
    
    //  接続失敗時に呼ばれる
    func centralManager(_ central: CBCentralManager, didFailToConnect peripheral: CBPeripheral, error: Error?) {
        print("Connect failed...")
    }
    
    //  ペリフェラル(iPhone)のStatusが変化した時に呼ばれる
    func peripheralManagerDidUpdateState(_ peripheral: CBPeripheralManager) {
        print("periState\(peripheral.state)")
    }

    @IBAction func startAdvertise(_ sender: Any) {
        let advertisementData = [CBAdvertisementDataLocalNameKey: "Test Device"]
        let serviceUUID = CBUUID(string: "0000")
        let service = CBMutableService(type: serviceUUID, primary: true)
        let charactericUUID = CBUUID(string: "0001")
        let characteristic = CBMutableCharacteristic(type: charactericUUID, properties: CBCharacteristicProperties.read, value: nil, permissions: CBAttributePermissions.readable)
        service.characteristics = [characteristic]
        self.peripheralManager.add(service)
        peripheralManager.startAdvertising(advertisementData)
    }
    
    //  サービス追加結果の取得
    func peripheralManager(_ peripheral: CBPeripheralManager, didAdd service: CBService, error: Error?) {
        if error != nil {
            print("Service Add Failed...")
            return
        }
        print("Service Add Sucsess!")
    }
    
    //  アドバタイズ(ペリフェラルが自分のもつサービスを接続可能な状態にし、周辺に機器情報を発信すること)開始処理の結果を取得
    func peripheralManagerDidStartAdvertising(_ peripheral: CBPeripheralManager, error: Error?) {
        if let error = error {
            print("***Advertising ERROR")
            return
        }
        print("Advertising success")
    }
    
    @IBAction func endAdvertise(_ sender: Any) {
        peripheralManager.stopAdvertising()
    }
    
    @IBAction func getChar(_ sender: Any) {
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
    
    //  service検索結果取得
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard let services = peripheral.services else{
            print("error")
            return
        }
        print("\(services.count)個のサービスを発見。\(services)")
        
        //  サービスを見つけたらすぐにキャラクタリスティックを取得
        for obj in services {
            peripheral.discoverCharacteristics(nil, for: obj)
        }
    }
    
    //  キャラクタリスティック(値、属性、ディスクリプタをもつ)検索結果取得
    func peripheral(_ peripheral: CBPeripheral, didDiscoverCharacteristicsFor service: CBService, error: Error?) {
        if let characteristics = service.characteristics {
            print("\(characteristics.count)個のキャラクタリスティックを発見。\(characteristics)")
        }
        
        let characteristics = service.characteristics!
        for characteristic in characteristics {
            if characteristic.uuid.isEqual(CBUUID(string: "19B10000-E8F2-537E-4F6C-D104768A1214")) {
                self.settingCharacteristic = characteristic
                print("KONASHI_PIO_SETTING_UUID を発見")
            } else if characteristic.uuid.isEqual(CBUUID(string: "19B10001-E8F2-537E-4F6C-D104768A1214")) {
                self.outputCharacteristic = characteristic
                print("KONASHI_PIO_OUTPUT_UUID を発見")
            }
        }
    }
    
    @IBAction func send(_ sender: Any) {
        var value: CUnsignedChar
        
        if !isBlink {
            isBlink = true
            value = 1
        }
        else {
            isBlink = false
            value = 0
        }
        var bytes : [UInt8] = [value]
        let data = NSData(bytes: bytes, length: bytes.count)
        print(data)
        self.peripheral.writeValue(data as Data,
                                   for: self.outputCharacteristic,
                                   type: CBCharacteristicWriteType.withResponse)
    }
    
    
    
    
    
    
    
    
    
    
    
    
    
    
    // 書き込み結果の受信
    func peripheral(peripheral: CBPeripheral,
                    didWriteValueForCharacteristic characteristic: CBCharacteristic,
                    error: NSError?)
    {
        if let error = error {
            print("Write失敗...error: \(error)")
            return
        }
        
        print("Write成功！")
    }

    
    
}

