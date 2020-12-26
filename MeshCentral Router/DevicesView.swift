//
//  CertificateView.swift
//  MeshCentral Router
//
//  Created by Default on 12/18/20.
//

import SwiftUI
import Combine

extension DevicesView {
    enum Tab: Hashable {
        case devices
        case mappings
    }
}

struct DevicesView: View {
    @State var selectedTab: Tab = .devices
    @State var deviceFilter:String = ""
    @State var showSettingsModal: Bool = false
    @State var showAddMapModal: Bool = false
    @State var showAddRelayMapModal: Bool = false
    @State var showSshUserModal: Bool = false
    @State var showHelpModal: Bool = false
    @ObservedObject var xmc:MeshCentralServerChanger = meshCentralServerChanger
    
    init() { }
    
    func openURL(url:String) {
        NSWorkspace.shared.open(URL(string: url)!)
    }
    
    func openSSH(port:Int) {
        /*
        let task = Process()
        task.launchPath = "/usr/bin/ssh"
        //task.arguments = ["-p", "\(port)", "127.0.0.1"]
        task.arguments = ["-p", "22", "192.168.2.113"]
        task.launch()
        */
        //UIApplication
    }
    
    func FilterCountAll() -> Int {
        var r:Int = 0
        for dev:Device in mc!.devices {
            if (CheckFilter(device:dev)) { r += 1 }
        }
        return r
    }
    
    func FilterCount(meshid:String) -> Int {
        var r:Int = 0
        for dev:Device in mc!.devices {
            if ((meshid == dev.meshid) && (CheckFilter(device:dev))) { r += 1 }
        }
        return r
    }
    
    func CheckFilter(device:Device) -> Bool {
        if (globalShowOnlyOnlineDevices && ((device.conn & 1) == 0)) { return false }
        if (deviceFilter == "") { return true }
        if (device.name.lowercased().contains(deviceFilter.lowercased())) { return true; }
        return false
    }
    
    func getStateString(device:Device) -> String {
        var r:[String] = [String]()
        if ((device.conn & 1) != 0) { r.append("Agent") }
        if ((device.conn & 2) != 0) { r.append("CIRA") }
        if ((device.conn & 4) != 0) { r.append("AMT") }
        if ((device.conn & 8) != 0) { r.append("Relay") }
        if ((device.conn & 16) != 0) { r.append("MQTT") }
        return r.joined(separator: ", ")
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                TabView(selection: $selectedTab) {
                    VStack(spacing: 0) {
                        if (mc!.devices.count == 0) {
                            Text("No devices").foregroundColor(Color("MainTextColor")).frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else if (FilterCountAll() == 0) {
                            Text("No filtered devices").foregroundColor(Color("MainTextColor")).frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List() {
                                ForEach(mc!.deviceGroups, id: \.id) { deviceGroup in
                                    if (FilterCount(meshid:deviceGroup.id) > 0) {
                                        Text(deviceGroup.name).foregroundColor(Color("MainTextColor"))
                                    }
                                    ForEach(mc!.devices, id: \.id) { device in
                                        if ((device.meshid == deviceGroup.id) && CheckFilter(device:device)) {
                                            HStack() {
                                                Image("Device\(device.icon)").opacity(((device.conn & 1) != 0) ? 1 : 0.3).saturation(((device.conn & 1) != 0) ? 1 : 0)
                                                VStack(alignment: .leading) {
                                                    Text(device.name)
                                                    Text(getStateString(device:device))
                                                }.frame(maxWidth: .infinity, alignment: .leading)
                                                if ((device.conn & 1) != 0) {
                                                    Button("Add map...", action: { globalSelectedDevice = device; showAddMapModal = true })
                                                }
                                            }.padding(.horizontal, 5).background(Color("MainItemColor")).cornerRadius(4).contextMenu() {
                                                if ((device.conn & 1) != 0) {
                                                    Button("Add map...", action: { globalSelectedDevice = device; showAddMapModal = true })
                                                    Button("Add relay map...", action: { globalSelectedDevice = device; showAddRelayMapModal = true })
                                                }
                                            }
                                        }
                                    }
                                }
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        HStack {
                            TextField("Filter", text: $deviceFilter).frame(width: 160).foregroundColor(Color("MainTextColor")).onExitCommand(perform: {
                                print("Exit from top text field")
                                deviceFilter = ""
                            })
                            Spacer()
                            Button("Settings...", action: { showSettingsModal = true }).sheet(isPresented: $showSettingsModal) {
                                SettingsDialogView(devicesView:self)
                            }
                            .buttonStyle(BorderedButtonStyle())
                        }.padding(.horizontal, 10).padding(.top, 4).frame(width: 494, height: 26)
                    }.tabItem {
                        Text("Devices")
                    }.tag(Tab.devices)
                    VStack(spacing: 0) {
                        if (mc!.portMaps.count == 0) {
                            Text("No mappings").foregroundColor(Color("MainTextColor")).frame(maxWidth: .infinity, maxHeight: .infinity)
                        } else {
                            List() {
                                ForEach(mc!.portMaps, id: \.id) { map in
                                    HStack() {
                                        Image("Device\(map.device.icon)")
                                        VStack(alignment: .leading) {
                                            Text((map.name != "") ? "\(map.device.name): \(map.name)" : "\(map.device.name)")
                                            Text(map.getStateStr())
                                        }.frame(maxWidth: .infinity, alignment: .leading)
                                        if (map.usage == "HTTP") {
                                            Button("HTTP", action: { openURL(url:"http://127.0.0.1:\(map.localPort)") })
                                        } else if (map.usage == "HTTPS") {
                                            Button("HTTPS", action: { openURL(url:"https://127.0.0.1:\(map.localPort)") })
                                        } else if (map.usage == "SSH") {
                                            Button("SSH", action: { showSshUserModal = true; }).sheet(isPresented: $showSshUserModal) {
                                                SshUserDialogView(devicesView:self, localPort:map.localPort)
                                            }
                                        }
                                        Button("Delete", action: { mc!.removePortMap(map: map) })
                                    }.padding(.horizontal, 5).background(Color("MainItemColor")).cornerRadius(4).contextMenu() {
                                        if (map.usage == "HTTP") {
                                            Button("HTTP", action: { openURL(url:"http://127.0.0.1:\(map.localPort)") })
                                        } else if (map.usage == "HTTPS") {
                                            Button("HTTPS", action: { openURL(url:"https://127.0.0.1:\(map.localPort)") })
                                        } else if (map.usage == "SSH") {
                                            Button("SSH", action: { showSshUserModal = true; }).sheet(isPresented: $showSshUserModal) {
                                                SshUserDialogView(devicesView:self, localPort:map.localPort)
                                            }
                                        }
                                        Button("Delete", action: { mc!.removePortMap(map: map) })
                                    }
                                }
                            }.frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                        HStack {
                            Button("Help", action: { showHelpModal = true }).sheet(
                                isPresented: $showHelpModal) {
                                HelpDialogView(devicesView:self)
                            }
                            Spacer()
                            Button("Add Relay Map...", action: { globalSelectedDevice = nil; showAddRelayMapModal = true })
                            Button("Add Map...", action: { globalSelectedDevice = nil; showAddMapModal = true })
                        }.padding(.horizontal, 10).padding(.top, 4).frame(width: 494, height: 26)
                    }.tabItem {
                        Text("Mappings")
                    }.tag(Tab.mappings)
                }.frame(maxWidth: .infinity, maxHeight: .infinity).padding(.top, -10)
            }.background(Color("MainBackground")).foregroundColor(.black)
            .sheet(isPresented: $showAddRelayMapModal) {
                AppMapDialogView(devicesView:self, device: globalSelectedDevice, relay: true)
            }
            HStack {
                Spacer()
                Button("Logout", action: logout).buttonStyle(BorderedButtonStyle()).padding()
            }.background(Image("BottomBanner")).frame(width: 494, height: 41)
            .sheet(isPresented: $showAddMapModal) {
                AppMapDialogView(devicesView:self, device: globalSelectedDevice, relay: false)
            }
        }
        .frame(width: 494, height: 360)
        .background(Color("MainBackground"))
        .foregroundColor(Color("MainTextColor"))
        .onAppear(perform: { devicesScreenDisplayed(devicesView:self) })
    }
}

struct DevicesView_Previews: PreviewProvider {
    static var previews: some View {
        DevicesView()
    }
}
