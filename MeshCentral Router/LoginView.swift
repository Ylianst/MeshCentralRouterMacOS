//
//  LoginView.swift
//  MeshCentral Router
//
//  Created by Default on 12/18/20.
//

import SwiftUI

struct LoginView: View {
    @State var serverName = ""
    @State var serverUser = ""
    @State var serverPass = ""
    @State var loginStatus = ""
    @State var fieldsEnabled = true
    @State var cancelEnabled = false
    var parent:ContentView? = nil
    @State var showInstallModal: Bool = false
    
    init(parent:ContentView?, loginStatus:String, serverName:String, userName:String, userPass:String) {
        self.parent = parent
        _serverName = State(wrappedValue: serverName)
        _serverUser = State(wrappedValue: userName)
        _serverPass = State(wrappedValue: userPass)
        _loginStatus = State(wrappedValue: loginStatus)
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 0) {
                Text("MeshCentral Router allows mapping of TCP ports on this computer to any computer in your MeshCentral server account. Start by logging into your account.").frame( width: 482, height: 60, alignment: .leading).padding(6)
                HStack(spacing: 0) {
                    Image("ServerLogo")
                    VStack(spacing: 2) {
                        Text("Server").frame( maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: .leading)
                        TextField("", text: $serverName).foregroundColor(.black).background(fieldsEnabled ? Color.white : Color("MainBackground")).border(Color.black).disabled(!fieldsEnabled)
                        Text("Username").frame( maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: .leading)
                        TextField("", text: $serverUser).foregroundColor(.black).background(fieldsEnabled ? Color.white : Color("MainBackground")).border(Color.black)
                            .disabled(!fieldsEnabled)
                        Text("Password").frame( maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: .leading)
                        SecureField("", text: $serverPass).foregroundColor(.black).background(fieldsEnabled ? Color.white : Color("MainBackground")).border(Color.black)
                            .disabled(!fieldsEnabled)
                        Spacer().frame(height: 5)
                        Text(loginStatus).frame( maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: .leading).foregroundColor(.purple)
                    }.frame(width: 210)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                HStack {
                    Text("v\(globalVersionStr)").foregroundColor(.gray)
                    Spacer()
                    Text("Open Source, Apache 2.0 License").foregroundColor(.gray)
                }.frame(maxWidth: .infinity).padding(6)
            }.background(Color("MainBackground")).foregroundColor(Color("MainTextColor"))
            HStack {
                Spacer()
                if (cancelEnabled) { Button("Cancel", action: logout).buttonStyle(BorderedButtonStyle()).padding() }
                Button("Login", action: { performLogin(parent:parent, view:self) }).buttonStyle(BorderedButtonStyle()).padding()
                    .disabled(!(((serverName.count > 0) && (serverUser.count > 0) && (serverPass.count > 0)) && fieldsEnabled))
            }.background(Image("BottomBanner")).frame(width: 494, height: 41)
        }
        .frame(width: 494, height: 360).onAppear(perform: { setGlobalViews(parent:parent!, view:self) })
        .onAppear(perform: { loginScreenDisplayed(loginView:self) })
    }
}

struct LoginView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LoginView(parent:nil, loginStatus:"", serverName: "myserver.domain.com", userName: "user", userPass: "")
        }
    }
}
