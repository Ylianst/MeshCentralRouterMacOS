//
//  SettingsDialogView.swift
//  MeshCentral Router
//
//  Created by Default on 12/23/20.
//

import SwiftUI
import Combine

struct AppMapDialogView: View {
    var relay:Bool
    var devicesView:DevicesView?
    @State var name:String = ""
    @State var localPortStr:String = "0"
    @State var meshid:String = ""
    @State var nodeid:String = ""
    @State var remoteIp:String = ""
    @State var remotePortStr:String = "443"
    @State var usage:String = "HTTPS"
    @State var usageEx:String = "HTTPS"
    
    init (devicesView:DevicesView?, device:Device?, relay:Bool) {
        self.devicesView = devicesView
        self.relay = relay
        if (device == nil) {
            let dev:Device? = getFirstValidDevice()
            if (dev != nil) {
                _meshid = State(wrappedValue: dev!.meshid)
                _nodeid = State(wrappedValue: dev!.id)
            }
        } else {
            _meshid = State(wrappedValue: device!.meshid)
            _nodeid = State(wrappedValue: device!.id)
        }
    }
    
    func getFirstValidDevice() -> Device? {
        for grp:DeviceGroup in mc!.deviceGroups {
            for dev:Device in mc!.devices {
                if ((dev.meshid == grp.id) && ((dev.conn & 1) != 0)) { return dev }
            }
        }
        return nil
    }
    
    func checkDeviceGroupValid(grp:DeviceGroup) -> Bool {
        for dev:Device in mc!.devices {
            if ((dev.meshid == grp.id) && ((dev.conn & 1) != 0)) { return true }
        }
        return false
    }
    
    func checkDeviceValid(dev:Device) -> Bool {
        return ((dev.meshid == meshid) && ((dev.conn & 1) != 0))
    }
    
    var body: some View {
        VStack() {
            VStack(alignment: .leading) {
                HStack() {
                    Text("Name").frame(width: 100, alignment: .leading)
                    Spacer()
                    TextField("", text: $name).frame(width: 200).onExitCommand(perform: { name = "" })
                }
                HStack() {
                    Text("Local Port").frame(width: 100, alignment: .leading)
                    Spacer()
                    TextField("", text: $localPortStr).multilineTextAlignment(.trailing).frame(width: 200).onExitCommand(perform: { localPortStr = "0" })
                }
                HStack() {
                    Text("Device Group").frame(width: 100, alignment: .leading)
                    Spacer()
                    Picker("", selection: $meshid) {
                        ForEach(mc!.deviceGroups, id: \.id) { deviceGroup in
                            if (checkDeviceGroupValid(grp: deviceGroup)) {
                                Text(deviceGroup.name).tag(deviceGroup.id)
                            }
                        }
                    }.labelsHidden().frame(width: 200)
                }
                HStack() {
                    Text("Device").frame(width: 100, alignment: .leading)
                    Spacer()
                    Picker("", selection: $nodeid) {
                        ForEach(mc!.devices, id: \.id) { device in
                            if (checkDeviceValid(dev:device)) {
                                Text(device.name).tag(device.id)
                            }
                        }
                    }.labelsHidden().frame(width: 200)
                }
                HStack() {
                    Text("Protocol").frame(width: 100, alignment: .leading)
                    Spacer()
                    Picker("", selection: $usage) {
                        Text("Custom").tag("")
                        Text("HTTP").tag("HTTP")
                        Text("HTTPS").tag("HTTPS")
                        Text("SSH").tag("SSH")
                    }.labelsHidden().frame(width: 200).onReceive([self.usage].publisher.first()) { value in
                        if (value != usageEx) {
                            usageEx = value;
                            if (value == "HTTP") { remotePortStr = "80" }
                            if (value == "HTTPS") { remotePortStr = "443" }
                            if (value == "SSH") { remotePortStr = "22" }
                        }
                    }
                }
                if (relay == true) {
                    HStack() {
                        Text("Remote IP").frame(width: 100, alignment: .leading)
                        Spacer()
                        TextField("", text: $remoteIp).frame(width: 200).onExitCommand(perform: { remoteIp = "" })
                    }
                }
                HStack() {
                    Text("Remote Port").frame(width: 100, alignment: .leading)
                    Spacer()
                    TextField("", text: $remotePortStr).multilineTextAlignment(.trailing).frame(width: 200)
                }
            }.padding()
            HStack() {
                Button("OK", action: { devicesView!.showAddMapModal = false; devicesView!.showAddRelayMapModal = false; mc!.addPortMap(name:name, nodeid:nodeid, usage:usage, localPort:Int(localPortStr) ?? 0, remoteIp: (relay == true) ? remoteIp : nil ,remotePort:Int(remotePortStr) ?? 0) }).disabled(
                    !(((Int(localPortStr) ?? -1) >= 0) && ((Int(localPortStr) ?? -1) <= 65535) && ((Int(remotePortStr) ?? -1) > 0) && ((Int(remotePortStr) ?? -1) <= 65535) && (meshid != "") && (nodeid != "") && ((relay == false) || (remoteIp != "")))
                )
                Button("Cancel", action: { devicesView!.showAddMapModal = false; devicesView!.showAddRelayMapModal = false; })
            }.padding([.horizontal, .bottom])
        }.background(Color("MainBackground")).foregroundColor(Color("MainTextColor")).shadow(radius: 20)
    }
}

struct AddMapDialogView_Previews: PreviewProvider {
    static var previews: some View {
        AppMapDialogView(devicesView:nil, device:nil, relay:true)
    }
}
