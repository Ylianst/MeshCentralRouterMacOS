//
//  SettingsDialogView.swift
//  MeshCentral Router
//
//  Created by Default on 12/23/20.
//

import SwiftUI

struct SettingsDialogView: View {
    var devicesView:DevicesView?
    @State var showOnlyOnlineDevices:Bool = false
    @State var bindLoopbackOnly:Bool = false
    
    init (devicesView:DevicesView?) {
        self.devicesView = devicesView
        _showOnlyOnlineDevices = State(initialValue: globalShowOnlyOnlineDevices)
        _bindLoopbackOnly = State(initialValue: globalBindLoopbackOnly)
    }
    
    var body: some View {
        VStack() {
            VStack(alignment: .leading) {
                Toggle(isOn: $showOnlyOnlineDevices) { Text("Show only online devices") }
                //Toggle(isOn: $bindLoopbackOnly) { Text("Bind only to loopback interface") }
            }.padding()
            HStack() {
                Button("OK", action: {
                    changeSettings(showOnlyOnlineDevices:showOnlyOnlineDevices, bindLoopbackOnly:bindLoopbackOnly)
                    devicesView!.showSettingsModal = false;
                })
                Button("Cancel", action: { devicesView!.showSettingsModal = false; })
            }.padding([.horizontal, .bottom])
        }.background(Color("MainBackground")).foregroundColor(Color("MainTextColor")).shadow(radius: 20)
    }
}

struct SettingsDialogView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsDialogView(devicesView:nil)
    }
}
