//
//  CertificateView.swift
//  MeshCentral Router
//
//  Created by Default on 12/18/20.
//

import SwiftUI

struct TokenView: View {
    @State var tokenStr = ""
    @State var fieldsEnabled = true
    @State var cancelEnabled = false
    @State var loginStatus = ""
    @State private var emailConfirm = false
    @State private var smsConfirm = false
    @State var isRememberChecked:Bool = false
    var tokenTypes:Int = 0
    var cookieDays:Int = 0
    var parent:ContentView? = nil
    
    init(parent:ContentView?, loginStatus:String, tokenTypes:Int, cookieDays:Int) {
        self.parent = parent
        self.tokenTypes = tokenTypes
        self.cookieDays = cookieDays
        _loginStatus = State(wrappedValue: loginStatus)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            VStack() {
                Text("Enter token for two-factor authentication.").frame( width: 482, height: 60, alignment: .topLeading).padding(6)
                HStack(spacing: 0) {
                    Image("ServerLogo")
                    VStack(spacing: 2) {
                        Text("Token").frame( maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: .leading)
                        TextField("", text: $tokenStr).foregroundColor(.black).background(fieldsEnabled ? Color.white : Color("MainBackground")).border(Color.black).disabled(!fieldsEnabled)
                        if (cookieDays > 0) {
                            Spacer().frame(height: 5)
                            let daysStr:String = (cookieDays == 1) ? "day" : "days"
                            Toggle(isOn: $isRememberChecked) { Text("Remember for \(cookieDays) \(daysStr)") }
                        }
                        HStack {
                            if ((tokenTypes & 1) != 0) {
                                Button("Send Email", action: { self.emailConfirm = true })
                                    .buttonStyle(BorderedButtonStyle())
                                    .padding(5)
                                    .alert(isPresented: $emailConfirm) {
                                        Alert(title: Text("Two-factor authentication"),
                                              message: Text("Email a login code?"),
                                              primaryButton: .cancel(Text("Cancel")),
                                              secondaryButton: .default(Text("Ok")) { performToken(parent:parent, view:self, token:"**email**") })
                                    }
                            }
                            if ((tokenTypes & 2) != 0) {
                                Button("Send SMS", action: { self.smsConfirm = true })
                                    .buttonStyle(BorderedButtonStyle())
                                    .padding(5)
                                    .alert(isPresented: $smsConfirm) {
                                        Alert(title: Text("Two-factor authentication"),
                                              message: Text("SMS a login code?"),
                                              primaryButton: .cancel(Text("Cancel")),
                                              secondaryButton: .default(Text("Ok")) { performToken(parent:parent, view:self, token:"**sms**") })
                                    }
                            }
                        }
                        Spacer().frame(height: 5)
                        Text(loginStatus).frame( maxWidth: /*@START_MENU_TOKEN@*/.infinity/*@END_MENU_TOKEN@*/, alignment: .leading).foregroundColor(.purple)
                    }.frame(width: 210)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
                Spacer().frame(width: 482, height: 36)
            }.background(Color("MainBackground")).foregroundColor(Color("MainTextColor"))
            HStack {
                Spacer()
                if (cancelEnabled) {
                    Button("Cancel", action: logout).buttonStyle(BorderedButtonStyle()).padding()
                } else {
                    Button("Back", action: performBackToLogin).buttonStyle(BorderedButtonStyle()).padding()
                }
                Button("Next", action: { performToken(parent:parent, view:self, token:self.tokenStr) }).buttonStyle(BorderedButtonStyle()).padding()
                    .disabled(!(tokenStr.count > 0))
            }.background(Image("BottomBanner")).frame(width: 494, height: 41)
        }.frame(width: 494, height: 360)
    }
}

struct TokenView_Previews: PreviewProvider {
    static var previews: some View {
        TokenView(parent:nil, loginStatus: "", tokenTypes: 3, cookieDays: 30)
    }
}
