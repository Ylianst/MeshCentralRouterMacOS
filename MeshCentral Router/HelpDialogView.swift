//
//  SettingsDialogView.swift
//  MeshCentral Router
//
//  Created by Default on 12/23/20.
//

import SwiftUI

struct HelpDialogView: View {
    var devicesView:DevicesView?
    
    init (devicesView:DevicesView?) {
        self.devicesView = devicesView
    }
    
    var body: some View {
        VStack() {
            Text("A port map will forward a port on this machine to a port on a remote machine. A relay port map will got thru a remote machine to a specified IP and port.").frame(width: 288, height: 64).padding(8)
            Image("Help")
            HStack() {
                Button("Close", action: {
                    devicesView!.showHelpModal = false;
                })
            }.padding([.horizontal, .bottom])
        }.background(Color("MainBackground")).foregroundColor(Color("MainTextColor")).shadow(radius: 20)
    }
}

struct HelpDialogView_Previews: PreviewProvider {
    static var previews: some View {
        HelpDialogView(devicesView:nil)
    }
}
