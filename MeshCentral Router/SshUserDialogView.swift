//
//  SettingsDialogView.swift
//  MeshCentral Router
//
//  Created by Default on 12/23/20.
//

import SwiftUI

struct SshUserDialogView: View {
    var devicesView:DevicesView?
    var localPort:Int = 0
    @State var sshUsername:String = ""
    
    init (devicesView:DevicesView?, localPort:Int) {
        self.devicesView = devicesView
        self.localPort = localPort
        _sshUsername = State(initialValue: settings.string(forKey: "sshUserName") ?? "")
    }
    
    func openURL(url:String) {
        NSWorkspace.shared.open(URL(string: url)!)
    }
    
    var body: some View {
        VStack() {
            HStack() {
                Text("Username").frame(width: 100, alignment: .leading)
                Spacer()
                TextField("", text: $sshUsername).frame(width: 200).onExitCommand(perform: { sshUsername = "" })
            }.padding()
            HStack() {
                Button("OK", action: {
                    settings.setValue(sshUsername, forKey: "sshUserName")
                    openURL(url:"ssh://\(sshUsername)@127.0.0.1:\(localPort)")
                    devicesView!.showSshUserModal = false;
                }).disabled(sshUsername == "")
                Button("Cancel", action: { devicesView!.showSshUserModal = false; })
            }.padding([.horizontal, .bottom])
        }.background(Color("MainBackground")).foregroundColor(Color("MainTextColor")).shadow(radius: 20)
    }
}

struct SshUserDialogView_Previews: PreviewProvider {
    static var previews: some View {
        SshUserDialogView(devicesView:nil, localPort:0)
    }
}
