//
//  ContentView.swift
//  MeshCentral Router
//
//  Created by Default on 12/18/20.
//

import SwiftUI

struct ContentView: View {
    @State var panel = 0
    @State var serverName = ""
    @State var serverUser = ""
    @State var serverPass = ""
    @State var loginStatus = ""
    @State var tokenTypes = 0
    @State var cookieDays = 0
    @State var certificateData = ""
    
    init(serverName:String, userName:String, userPass:String) {
        _serverName = State(wrappedValue: serverName)
        _serverUser = State(wrappedValue: userName)
        _serverPass = State(wrappedValue: userPass)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Image("TopBanner")
            if (panel == 0) { LoginView(parent: self, loginStatus: loginStatus, serverName: serverName, userName: serverUser, userPass: serverPass) }
            if (panel == 1) { TokenView(parent: self, loginStatus: loginStatus, tokenTypes: tokenTypes, cookieDays: cookieDays) }
            if (panel == 2) { CertificateView(parent: self, certificateData: certificateData) }
            if (panel == 3) { DevicesView() }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView(serverName: "myserver.domain.com", userName: "user", userPass: "")
    }
}
