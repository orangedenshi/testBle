//
//  ContentView.swift
//  testBle
//
//  Created by nobuaki on 2024/11/12.
//

import SwiftUI
import CoreBluetooth
import Foundation

struct ContentView: View {
    @EnvironmentObject var bleManager: CoreBluetoothViewModel
    
    @State var threshold:String = ""
    @State var holdtime :String = ""
    @State var nonetime :String = ""
    @State var rms      :String = "0"
    @State var rmsave   :String = "0"
    @State var max      :String = "0"
    @State var maxall   :String = "0"
    @State var maxdet   :String = "0"
    @State var detcnt   :String = "0"
    @State var isShowDialog :Bool = false
    @State var isShowAlert  :Bool = false
    @State var isShowAbout  :Bool = false
    @State var connect_s = NSLocalizedString("Connect",comment: "")
    @State var aaa: Double = 0
    @State var isConnect :Bool = false
    //@State var fileURL :URL? = nil
    @State var fileName : String? = nil
    
    
    var body: some View {
        VStack {
            // bleManager.navigationToDetailView(isDetailViewLinkActive:$bleManager.isConnected)
            HStack{
                Button(action:{
                    isShowAbout = true
                })
                {
                    Text("Metal Detector")
                        .foregroundColor(.black)
                        .font(.title)
                }
                .confirmationDialog("Metal Detector Controller", isPresented: $isShowAbout, titleVisibility: .visible) {
                } message: {
                    Text("App Version: \(getAppVersion())")
                }
                Spacer()
            }
            
            HStack{
                Spacer()
                Button(action:{
                    // if !bleManager.isConnected {
                    if isConnect==false {
                        if !bleManager.isSearching { bleManager.startScan() }
                        isShowDialog = true
                    }else{
                        bleManager.disconnectPeripheral()
                        connect_s = NSLocalizedString("Connect",comment:"")
                        bleManager.clearText()
                        isConnect = false
                    }
                }
                )
                {
                    Text(connect_s)
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                }
                .confirmationDialog(NSLocalizedString("Connect",comment:""), isPresented: $isShowDialog, titleVisibility: .visible) {
                    ForEach(0..<bleManager.foundPeripherals.count,id: \.self){num in
                        Button(action:{
                            bleManager.p_refresh = true
                            bleManager.connectPeripheral(bleManager.foundPeripherals[num])
                            connect_s = NSLocalizedString("Disconnect",comment:"")
                            isConnect = true
                            
                            // let formatter = DateFormatter()
                            // formatter.dateFormat = "yyyy_MMdd_HHmmss"
                            // $bleManager.fileName = formatter.string(from: Date()) + ".csv"
                        }){
                            Text(bleManager.foundPeripherals[num].name)
                        }
                    }
                } message: {
                    Text(NSLocalizedString("Choose",comment:""))
                }
            }
            Grid {
                GridRow{
                    Text(NSLocalizedString("Name", comment: ""))
                    Text(bleManager.name).gridColumnAlignment(.leading)
                        .font(.title3)
                    Text("")
                }
                GridRow{
                    Text("FW.ver")
                        .font(.callout)
                    Text(bleManager.fw_ver).gridColumnAlignment(.leading)
                        .font(.callout)
                    Text("")
                }
                GridRow{
                    Text(NSLocalizedString("Threshold",comment:""))
                    TextField("",value:$bleManager.threshold,format: .number)
                        .multilineTextAlignment(.trailing)
                        // .gridColumnAlignment(.trailing)
                    Text("mV")
                        .gridColumnAlignment(.leading)
                }
                GridRow{
                    Text(NSLocalizedString("Detect Signal Hold Time",comment: ""))
                    TextField("",value:$bleManager.holdTime ,format: .number)
                        .multilineTextAlignment(.trailing)
                        // .gridColumnAlignment(.trailing)
                    Text("ms")
                        .gridColumnAlignment(.leading)
                }
                GridRow{
                    Text(NSLocalizedString("No Detect Time",comment: ""))
                    TextField("",value:$bleManager.noneTime ,format: .number)
                        .multilineTextAlignment(.trailing)
                        // .gridColumnAlignment(.trailing)
                    Text("s")
                        .gridColumnAlignment(.leading)
                }
            }
            .keyboardType(.decimalPad)
            
            HStack{
                Button(action:{
                    let th = bleManager.v2ad(v: bleManager.threshold)
                    if th<0 || th>8000 {return}
                    if bleManager.holdTime<0 || bleManager.holdTime>10000 {return}
                    if bleManager.noneTime<0 || bleManager.noneTime>1000  {return}
                    bleManager.write_command_parameter()
                })
                {
                    Text(NSLocalizedString("Set",comment:""))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                }
                Spacer()
                Button(action:{bleManager.p_refresh=true})
                {
                    Text(NSLocalizedString("Read",comment:""))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                }
            }

            Divider()
            HStack{
                VStack(alignment: .trailing ){
                    Text(NSLocalizedString("RMS"          ,comment:""))
                    Text(NSLocalizedString("RMS(Ave.)"    ,comment:""))
                    Text(NSLocalizedString("RMS(Ave.Max.)",comment:""))
                    Text(NSLocalizedString("Max"          ,comment:""))
                    Text(NSLocalizedString("Max(Alltime)" ,comment:""))
                    Text(NSLocalizedString("Max(Detect)"  ,comment:""))
                    Text(NSLocalizedString("Detect Count" ,comment:""))
                }
                Spacer()
                VStack(alignment: .trailing ){
                    Text(bleManager.rms)
                    Text(bleManager.rmsAve)
                    Text(bleManager.rmsAveAll)
                    Text(bleManager.max)
                    Text(bleManager.maxAll)
                    Text(bleManager.maxDet)
                    Text(bleManager.count)
                }
                VStack(alignment: .leading ){
                    Text("mV")
                    Text("mV")
                    Text("mV")
                    Text("mV")
                    Text("mV")
                    Text("mV")
                    Text(NSLocalizedString("Times",comment:""))
                }
                
            }
            HStack{
                Spacer()
                Button(action:{bleManager.write_command_reset()})
                {
                    Text(NSLocalizedString("Reset Stats",comment:""))
                        .foregroundColor(.white)
                        .padding()
                        .background(Color.blue)
                }
            }
            HStack{
                Text(bleManager.werror)
                    .font(.title3)
            }
            Spacer()
        }
        .frame(maxWidth:.infinity,maxHeight: .infinity)
        .padding()
        .onAppear(){
            Timer.scheduledTimer(withTimeInterval: 1.0, repeats: false){ timer in
                if bleManager.isBlePower {
                    bleManager.startScan()
                }
                // if !bleManager.isBlePower {isShowAlert=true}
                // else {bleManager.startScan()}j
            }
        }.alert("", isPresented: $isShowAlert){
            Button("OK"){}
        }message: {
            Text(NSLocalizedString("Bluetooth is turned off",comment:""))
        }
        
    }
    
    func getAppVersion() -> String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "N/A"
        return version
        // return String(describing: type(of: version))
    }

}

#Preview {
    ContentView()
}

