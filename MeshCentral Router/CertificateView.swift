//
//  CertificateView.swift
//  MeshCentral Router
//
//  Created by Default on 12/18/20.
//

import SwiftUI

struct CertificateView: View {
    var parent:ContentView? = nil
    @State var isRememberChecked:Bool = false
    @State var certificateData:String
    
    init(parent:ContentView?, certificateData:String) {
        self.parent = parent
        _certificateData = State(wrappedValue: certificateData)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Text("WARNING - Invalid Server Certificate").foregroundColor(.red).frame(width: 494, height: 30).background(Color(.yellow)).font(.headline)
            Text("This server presented an un-trusted certificate. This may indicate that this is not the correct server or that the server does not have a valid certificate. It is not recommanded, but you can press the ignore button to connect to this server.").frame(width: 484, height: 70).padding(5)
            ScrollView(.vertical, showsIndicators: true) {
                Text(certificateData).frame(width: 468, alignment: .topLeading).padding(5)
            }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).border(Color.black, width: 2).padding(.horizontal, 15)
            HStack(spacing: 0) {
                Toggle(isOn: $isRememberChecked) { Text("Remember this certificate") }
            }.frame(width: 470, alignment: .leading).padding(12)
            HStack(spacing: 0) {
                Spacer()
                Button("Back", action: performBackToLogin).buttonStyle(BorderedButtonStyle()).padding()
                Button("Ignore", action: { performIgnoreCert(remember:isRememberChecked) }).buttonStyle(BorderedButtonStyle()).padding()
            }.background(Image("BottomBanner")).frame(width: 494, height: 41)
        }.frame(width: 494, height: 360).background(Color("MainBackground")).foregroundColor(Color("MainTextColor"))
    }
}

struct CertificateView_Previews: PreviewProvider {
    static var previews: some View {
        CertificateView(parent: nil, certificateData: "Test")
    }
}
