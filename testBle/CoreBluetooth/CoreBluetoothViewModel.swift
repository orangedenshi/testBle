//
//  CoreBluetoothViewModel.swift
//  testBle
//
//  Created by nobuaki on 2024/11/22.
//
import SwiftUI
import CoreBluetooth
import Foundation

class CoreBluetoothViewModel: NSObject, ObservableObject, CBPeripheralProtocolDelegate, CBCentralManagerProtocolDelegate {
    @Published var isBlePower: Bool = false
    @Published var isSearching: Bool = false
    @Published var isConnected: Bool = false
    
    @Published var foundPeripherals: [Peripheral] = []
    @Published var foundServices: [Service] = []
    @Published var foundCharacteristics: [Characteristic] = []
    
    @Published var threshold : Double = 0
    @Published var holdTime  : UInt32 = 0
    @Published var noneTime  : UInt32 = 0
    @Published var name      : String = ""
    @Published var rms       : String = "0"
    @Published var rmsAve    : String = "0"
    @Published var max       : String = "0"
    @Published var maxAll    : String = "0"
    @Published var maxDet    : String = "0"
    @Published var count     : String = "0"
    @Published var werror    : String = ""
    @Published var fw_ver    : String = ""
    @Published var rmsAveAll : String = "0"
    @Published var fileURL   : URL? = nil
    @Published var fileName  : String? = nil

    var p_refresh : Bool = true
    var txCharacteristic: CBCharacteristic! = nil
    
    var threshold_old : UInt32 = 0
    var holdTime_old  : UInt32 = 0
    var noneTime_old  : UInt32 = 0
    var name_old      : String = ""

    
    private var centralManager: CBCentralManagerProtocol!
    private var connectedPeripheral: Peripheral!
    
    private let serviceUUID: CBUUID = CBUUID()
    
    override init() {
        super.init()
        #if targetEnvironment(simulator)
        centralManager = CBCentralManagerMock(delegate: self, queue: nil)
        #else
        centralManager = CBCentralManager(delegate: self, queue: nil, options: [CBCentralManagerOptionShowPowerAlertKey: true])
        #endif
    }
    
    func clearText(){
        threshold = 0
        holdTime  = 0
        noneTime  = 0
        name      = ""
        rms       = "0"
        rmsAve    = "0"
        max       = "0"
        maxAll    = "0"
        maxDet    = "0"
        count     = "0"
        werror     = ""
        fw_ver    = ""
        rmsAveAll = "0"
}
    
    private func resetConfigure() {
        withAnimation {
            isSearching = false
            isConnected = false
            
            foundPeripherals = []
            foundServices = []
            foundCharacteristics = []
        }
    }
    
    //Control Func
    func startScan() {
        let scanOption = [CBCentralManagerScanOptionAllowDuplicatesKey: true]
        //centralManager?.scanForPeripherals(withServices: nil, options: scanOption)
        centralManager?.scanForPeripherals(withServices:[CBUUID(string: "4fafc201-1fb5-459e-8fcc-c5c9c331914b")] , options: scanOption)
        print("# Start Scan")
        isSearching = true
    }
    
    func stopScan(){
        disconnectPeripheral()
        centralManager?.stopScan()
        print("# Stop Scan")
        isSearching = false
    }
    
    func connectPeripheral(_ selectPeripheral: Peripheral?) {
        guard let connectPeripheral = selectPeripheral else { return }
        connectedPeripheral = selectPeripheral
        centralManager.connect(connectPeripheral.peripheral, options: nil)
    }
    
    func disconnectPeripheral() {
        guard let connectedPeripheral = connectedPeripheral else { return }
        centralManager.cancelPeripheralConnection(connectedPeripheral.peripheral)
    }

    //MARK: CoreBluetooth CentralManager Delegete Func
    func didUpdateState(_ central: CBCentralManagerProtocol) {
        if central.state == .poweredOn {
            isBlePower = true
        } else {
            isBlePower = false
        }
    }
    
    func didDiscover(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, advertisementData: [String : Any], rssi: NSNumber) {
        if rssi.intValue >= 0 { return }
        
        let peripheralName = advertisementData[CBAdvertisementDataLocalNameKey] as? String ?? nil
        var _name = "NoName"
        
        if peripheralName != nil {
            _name = String(peripheralName!)
        } else if peripheral.name != nil {
            _name = String(peripheral.name!)
        }
      
        let foundPeripheral: Peripheral = Peripheral(_peripheral: peripheral,
                                                     _name: _name,
                                                     _advData: advertisementData,
                                                     _rssi: rssi,
                                                     _discoverCount: 0)
        
        if let index = foundPeripherals.firstIndex(where: { $0.peripheral.identifier.uuidString == peripheral.identifier.uuidString }) {
            if foundPeripherals[index].discoverCount % 50 == 0 {
                foundPeripherals[index].name = _name
                foundPeripherals[index].rssi = rssi.intValue
                foundPeripherals[index].discoverCount += 1
            } else {
                foundPeripherals[index].discoverCount += 1
            }
        } else {
            foundPeripherals.append(foundPeripheral)
            DispatchQueue.main.async { self.isSearching = false }
        }
    }
    
    func didConnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol) {
        guard let connectedPeripheral = connectedPeripheral else { return }
        isConnected = true
        connectedPeripheral.peripheral.delegate = self
        connectedPeripheral.peripheral.discoverServices(nil)
        // print("connected")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MMdd_HHmmss"
        fileName = formatter.string(from: Date()) + ".csv"
        if let s = fileName {
            print(s)
        }
    }
    
    func didFailToConnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, error: Error?) {
        disconnectPeripheral()
    }
    
    func didDisconnect(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol, error: Error?) {
        print("disconnect")
        resetConfigure()
    }
    
    func connectionEventDidOccur(_ central: CBCentralManagerProtocol, event: CBConnectionEvent, peripheral: CBPeripheralProtocol) {
        
    }
    
    func willRestoreState(_ central: CBCentralManagerProtocol, dict: [String : Any]) {
        
    }
    
    func didUpdateANCSAuthorization(_ central: CBCentralManagerProtocol, peripheral: CBPeripheralProtocol) {
        
    }
    
    //MARK: CoreBluetooth Peripheral Delegate Func
    func didDiscoverServices(_ peripheral: CBPeripheralProtocol, error: Error?) {
        peripheral.services?.forEach { service in
            let setService = Service(_uuid: service.uuid, _service: service)
            
            foundServices.append(setService)
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }
    
    func didDiscoverCharacteristics(_ peripheral: CBPeripheralProtocol, service: CBService, error: Error?) {
        service.characteristics?.forEach { characteristic in
            let setCharacteristic: Characteristic = Characteristic(_characteristic: characteristic,
                                                                   _description: "",
                                                                   _uuid: characteristic.uuid,
                                                                   _readValue: "",
                                                                   _service: characteristic.service!)
            foundCharacteristics.append(setCharacteristic)
//            peripheral.readValue(for: characteristic)
            
//             #define CHARACTERISTIC_UUID_TX
//             #define CHARACTERISTIC_UUID_RX ""
            //read characteristic
            if characteristic.uuid.uuidString == "beb5483e-36e1-4688-b7f5-ea07361b26a8".uppercased(){
                // print(characteristic.uuid.uuidString)
                // print(characteristic)
                peripheral.setNotifyValue(true, for: characteristic)
            }
            //write characteristic
            if setCharacteristic.uuid.uuidString == "6E400002-B5A3-F393-E0A9-E50E24DCCA9E".uppercased(){
                // print(setCharacteristic.uuid.uuidString)
                // print(setCharacteristic.service)
                txCharacteristic = characteristic
            }

            // print(setCharacteristic.uuid.uuidString)
            // print(setCharacteristic.service)
            // print()
        }
    }
    
    func v2ad(v : Double) -> UInt32{
        UInt32(v/(5.0/8192.0*2.3*1000/2.0))
    }
    
    func ad2v(ad : UInt32) -> Double{
        Double(ad)*5.0/8192.0*2.3*1000.0/2.0
    }
    
    func appendToFile(fileName: String, content: String) {
        // `Documents`ディレクトリのURLを取得
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let fileURL = documentDirectory.appendingPathComponent(fileName)
            
            // ファイルが存在するかを確認
            if FileManager.default.fileExists(atPath: fileURL.path) {
                // ファイルが存在する場合、追記
                do {
                    let fileHandle = try FileHandle(forWritingTo: fileURL)
                    fileHandle.seekToEndOfFile() // ファイルの末尾に移動
                    if let data = content.data(using: .utf8) {
                        fileHandle.write(data) // データを書き込む
                    }
                    fileHandle.closeFile()
                    // print("ファイルに追記されました: \(content)")
                } catch {
                    print("エラー: ファイルの追記に失敗しました: \(error)")
                }
            } else {
                print(fileURL)
                // ファイルが存在しない場合、新規作成して書き込み
                do {
                    let s = "年月日,時分秒,rms,rms(平均),最大値,最大値(all),最大値(検出),検出回数\n" + content
                    try s.write(to: fileURL, atomically: true, encoding: .shiftJIS)
                    // try content.write(to: fileURL, atomically: true, encoding: .utf8)
                    // print("ファイルが新規作成され、内容が書き込まれました: \(content)")
                } catch {
                    print("エラー: ファイルの作成に失敗しました: \(error)")
                }
            }
        }
    }
    
    func didUpdateValue(_ peripheral: CBPeripheralProtocol, characteristic: CBCharacteristic, error: Error?) {
        guard let characteristicValue = characteristic.value else { return }
        // print(characteristicValue)
        // print("\(characteristicValue.map({ String(format:"%02x", $0) }).joined())")

        // if let index = foundCharacteristics.firstIndex(where: { $0.uuid.uuidString == characteristic.uuid.uuidString }) {
            
            // foundCharacteristics[index].readValue = characteristicValue.map({ String(format:"%02x", $0) }).joined()
            // print("Found characteristic \(characteristic.uuid.uuidString) with value \(characteristicValue.map({ String(format:"%02x", $0) }).joined())")
        // }
        
        let irms       = Data(characteristicValue[ 0...3 ]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let irmsAve    = Data(characteristicValue[ 4...7 ]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let imax       = Data(characteristicValue[ 8...11]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let imaxAll    = Data(characteristicValue[12...15]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let imaxDet    = Data(characteristicValue[16...19]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let icount     = Data(characteristicValue[20...23]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let ithreshold = Data(characteristicValue[24...27]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let iholdTime  = Data(characteristicValue[28...31]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let inoneTime  = Data(characteristicValue[32...35]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let ilen       = Data(characteristicValue[36...39]).withUnsafeBytes{$0.load(as: UInt32.self)}
        let iname      = String(data:Data(characteristicValue[40...(40+ilen-1)]),encoding: .utf8)
        var iwerror   : UInt32? = nil
        var ifw_ver   : UInt32? = nil
        var irmsAveAll: UInt32? = nil
        if characteristicValue.count >= 84 {
            iwerror    = Data(characteristicValue[72...75]).withUnsafeBytes{$0.load(as: UInt32.self)}
            ifw_ver    = Data(characteristicValue[76...79]).withUnsafeBytes{$0.load(as: UInt32.self)}
            irmsAveAll = Data(characteristicValue[80...83]).withUnsafeBytes{$0.load(as: UInt32.self)}
        }
        
        
        rms       = String(round(ad2v(ad: irms      )*10.0)/10.0)
        rmsAve    = String(round(ad2v(ad: irmsAve   )*10.0)/10.0)
        max       = String(round(ad2v(ad: imax      )*10.0)/10.0)
        maxAll    = String(round(ad2v(ad: imaxAll   )*10.0)/10.0)
        maxDet    = String(round(ad2v(ad: imaxDet   )*10.0)/10.0)
        count     = String(icount)
        if iwerror != 0 {
            werror = NSLocalizedString("Error!",comment:"")
        }else{
            werror = ""
        }
        if let value = ifw_ver {
            let major = value/256
            let minor = value%256
            fw_ver = String(format:"%02d.%02d",major,minor)
        }else{
            fw_ver    = ""
        }
        
        if let value = irmsAveAll {
            rmsAveAll = String(round(ad2v(ad: value)*10.0)/10.0)
        }else{
            rmsAveAll = "0"
        }
 
        if p_refresh ||
            threshold_old != ithreshold ||
            holdTime_old  != iholdTime  ||
            noneTime_old  != inoneTime  ||
            name_old      != iname!
        {
            threshold = round(ad2v(ad: ithreshold)*10.0)/10.0
            holdTime  = iholdTime
            noneTime  = inoneTime
            name      = iname!
            threshold_old = ithreshold
            holdTime_old  = iholdTime
            noneTime_old  = inoneTime
            name_old      = iname!
            p_refresh = false
        }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy_MMdd,HH:mm:ss"
        let s = formatter.string(from: Date())+","+rms+","+rmsAve+","+max+","+maxAll+","+maxDet+","+count+"\n"
        if let file = fileName {
            appendToFile(fileName: file, content: s)
        }
        /*
        if let documentDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            if let file = fileName {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy_MMdd\tHHmmss"
                let s = formatter.string(from: Date())+"\n"
                
                let fileUrl = documentDirectory.appendingPathComponent(file)
                do {
                    try s.write(to:fileUrl,atomically:true,encoding: .utf8)
                    print("ファイルが作成されました:\(fileUrl)")
                }catch{
                    print("エラー:ファイルの書き込みに失敗しました:\(error)")
                }
            }
        }
        */
    }
    
    func didWriteValue(_ peripheral: CBPeripheralProtocol, descriptor: CBDescriptor, error: Error?) {
        
    }
    
    func write_command_reset(){
        var aaa: UInt32 = 2
        let data = Data(bytes: &aaa,count:MemoryLayout.size(ofValue: aaa))
        if txCharacteristic != nil {
            connectedPeripheral.peripheral.writeValue(data, for: txCharacteristic!, type: .withResponse)
        }
    }
    
    func write_command_parameter(){
        var aaa: UInt32 = 1
        let name_ = Data("test".utf8)
        var len = UInt32(name_.count)
        var th = v2ad(v: threshold)
        
        var f =  Data(bytes:&aaa      ,count:MemoryLayout.size(ofValue: aaa      ))
        f.append(Data(bytes:&th       ,count:MemoryLayout.size(ofValue: th       )))
        f.append(Data(bytes:&holdTime ,count:MemoryLayout.size(ofValue: holdTime )))
        f.append(Data(bytes:&noneTime ,count:MemoryLayout.size(ofValue: noneTime )))
        f.append(Data(bytes:&len      ,count:MemoryLayout.size(ofValue: len      )))
        f.append(name_)
                 
        print("\(f.map({ String(format:"%02x", $0) }).joined())")
        if txCharacteristic != nil {
            connectedPeripheral.peripheral.writeValue(f, for: txCharacteristic!, type: .withResponse)
        }
    }
        
}

