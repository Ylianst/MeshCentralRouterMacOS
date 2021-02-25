//
//  AppDelegate.swift
//  MeshCentral Router
//
//  Created by Default on 12/24/20.
//

import Cocoa
import SwiftUI

let settings = UserDefaults.standard;
var mc:MeshCentralServer? = nil
var parentView:ContentView? = nil
var loginView:LoginView? = nil
var tokenView:TokenView? = nil
var rememberDevice:Bool = false
var tokenAttemptCount:Int = 0
var trustedTlsServerCertHash:String? = nil
var failedTlsServerCertHash:String? = nil
var globalDevicesView:DevicesView? = nil
var globalShowOnlyOnlineDevices:Bool = false
var globalBindLoopbackOnly:Bool = false
var globalSelectedDevice:Device? = nil
var globalAutoMaps:[AutoPortMap]? = nil
var globalVersionStr:String = (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") ?? "0.0.0") as! String

// Authentication Cookie
var globalAuthUrl:String? = nil
var globalAuthParams:[String:String] = [String:String]()
var globalAutoOpenUrl:URL? = nil
var globalAutoConnect:Bool = false

func substring(string: String, fromIndex: Int, toIndex: Int) -> String? {
    if fromIndex < toIndex && toIndex <= string.count {
        let startIndex = string.index(string.startIndex, offsetBy: fromIndex)
        let endIndex = string.index(string.startIndex, offsetBy: toIndex)
        return String(string[startIndex..<endIndex])
    } else {
        return nil
    }
}

@main
class AppDelegate: NSObject, NSApplicationDelegate {

    var window: NSWindow!

    func applicationDidFinishLaunching(_ aNotification: Notification) {
        // Load the user server hostname, username and password
        var serverName:String? = settings.string(forKey: "serverName")
        var serverUser:String? = settings.string(forKey: "serverUser")
        var serverPass:String? = nil
        var automationFlags = 0
        //var openfile:URL? = nil
        
        // Parse inbound arguments
        for arg:String in CommandLine.arguments {
            if (arg.starts(with: "mcrouter://")) { globalAutoOpenUrl = URL(string:arg)! }
            if (arg.starts(with: "-host:")) {
                serverName = substring(string:arg, fromIndex: 6, toIndex: arg.count)
                if (serverName!.count > 0) { automationFlags += 1 }
            }
            if (arg.starts(with: "-user:")) {
                serverUser = substring(string:arg, fromIndex: 6, toIndex: arg.count)
                if (serverUser!.count > 0) { automationFlags += 2 }
            }
            if (arg.starts(with: "-pass:")) {
                serverPass = substring(string:arg, fromIndex: 6, toIndex: arg.count)
                if (serverPass!.count > 0) { automationFlags += 4 }
            }
            /*
            if (arg.hasSuffix(".mcrouter") && (arg.count > 9)) {
                if (arg.starts(with: "file://")) {
                    openfile = URL(string: arg)
                } else {
                    openfile = URL(string: "file://" + arg)
                }
            }
            */
        }
        // If host, user and pass are passed in as arguments, trigger auto-connect
        globalAutoConnect = (automationFlags == 7)
        
        // Load settings and setup main device view
        let showOnlyOnlineDevicesStr = settings.string(forKey: "showOnlyOnlineDevices") ?? "0"
        globalShowOnlyOnlineDevices = (showOnlyOnlineDevicesStr == "1")
        let bindLoopbackOnlyStr = settings.string(forKey: "bindLoopbackOnly") ?? "1"
        globalBindLoopbackOnly = (bindLoopbackOnlyStr == "1")
        //globalDevicesView = DevicesView()
        parentView = ContentView(serverName: serverName ?? "", userName: serverUser ?? "", userPass: serverPass ?? "")
        
        // Create the window and set the content view.
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 494, height: 360),
            //styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            styleMask: [.titled, .miniaturizable],
            backing: .buffered, defer: false)
        
        window.isReleasedWhenClosed = false
        window.center()
        window.setFrameAutosaveName("Main Window")
        window.contentView = NSHostingView(rootView: parentView)
        window.makeKeyAndOrderFront(nil)
        
        // Open a file if needed
        //if (openfile != nil) { openFile(url:openfile!) }
    }

    func applicationWillTerminate(_ aNotification: Notification) {
        // Insert code here to tear down your application
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        //print("OpenUrl: \(urls[0])")
        if (urls[0].scheme == "file") {
            openFile(url: urls[0])
        } else if (urls[0].scheme == "mcrouter") {
            if ((mc != nil) || ((loginView != nil) && (parentView?.panel != 0))) { return; }
            if (loginView != nil) {
                performAutoLogin(u:urls[0])
            } else {
                globalAutoOpenUrl = urls[0]
            }
        }
    }
    
    func application(_ sender: NSApplication, openFile filename: String) -> Bool {
        //print("OpenFile: \(filename)")
        openFile(url: URL(string: "file://" + filename)!)
        return true
    }
 
    /*
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        print("A")
    }
    */
    
    func application(_ sender: NSApplication, openTempFile filename: String) -> Bool {
        //print("B")
        return true
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool {
        //print("C")
        return true
    }

    func applicationOpenUntitledFile(_ sender: NSApplication) -> Bool {
        //print("D")
        return true
    }

    func application(_ sender: Any, openFileWithoutUI filename: String) -> Bool {
        //print("E")
        return true
    }
    
    @IBOutlet weak var OpenFileMenuOutlet: NSMenuItem!
    
    @IBOutlet weak var SaveFileMenuOutlet: NSMenuItem!
    
    @IBAction func OpenFileMenuAction(_ sender: NSMenuItem) {
        if ((loginView == nil) || (parentView == nil)) { return }
        let dialog = NSOpenPanel();
        dialog.title = "Open MeshCentral Router File";
        dialog.canChooseFiles = true
        dialog.showsResizeIndicator = true;
        dialog.showsHiddenFiles = false;
        dialog.allowsMultipleSelection = false;
        dialog.canChooseDirectories = false;
        dialog.allowedFileTypes = ["mcrouter"];
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if (dialog.url != nil) { openFile(url:dialog.url!) }
        }
    }
    
    @IBAction func SaveAsFileMenuAction(_ sender: NSMenuItem) {
        if ((parentView == nil) || (parentView!.panel != 3) || (mc == nil)) { return }
        let dialog = NSSavePanel();
        dialog.title = "Save MeshCentral Router File";
        dialog.showsResizeIndicator = true;
        dialog.showsHiddenFiles = false;
        dialog.canCreateDirectories = true;
        dialog.allowedFileTypes = ["mcrouter"];
        if (dialog.runModal() == NSApplication.ModalResponse.OK) {
            if (dialog.url != nil) {
                do {
                    // Encode the JSON
                    var json = "{\r\n"
                    json += "  \"hostname\":\"\(loginView!.serverName)\",\r\n"
                    json += "  \"username\":\"\(loginView!.serverUser)\",\r\n"
                    //json += "  \"password\":\"\(loginView!.serverPass)\",\r\n"
                    json += "  \"password\":\"\",\r\n"
                    if (trustedTlsServerCertHash != nil) { json += "  \"certhash\":\"\(trustedTlsServerCertHash!)\",\r\n" }
                    json += "  \"mappings\":[\r\n"
                    var firstMap = true
                    for map:PortMap in mc!.portMaps {
                        if (firstMap == true) { json += "    {\r\n"; firstMap = false } else { json += ",\r\n    {\r\n" }
                        if (map.name != "") { json += "      \"name\":\"\(map.name)\",\r\n" }
                        json += "      \"meshId\":\"\(map.device.meshid)\",\r\n"
                        json += "      \"nodeId\":\"\(map.device.id)\",\r\n"
                        if (map.usage == "HTTP") { json += "      \"appId\":1,\r\n" }
                        if (map.usage == "HTTPS") { json += "      \"appId\":2,\r\n" }
                        if (map.usage == "RDP") { json += "      \"appId\":3,\r\n" }
                        if (map.usage == "SSH") { json += "      \"appId\":4,\r\n" }
                        if (map.usage == "SCP") { json += "      \"appId\":5,\r\n" }
                        json += "      \"protocol\":1,\r\n"
                        if (map.remoteIp != nil) { json += "      \"remoteIp\":\"\(map.remoteIp!)\",\r\n" }
                        json += "      \"remotePort\":\(map.remotePort),\r\n"
                        json += "      \"localPort\":\(map.indicatedLocalPort)\r\n"
                        json += "    }"
                    }
                    json += "\r\n  ]\r\n"
                    json += "}"
                    
                    // Write the file
                    try json.write(to: dialog.url!, atomically: true, encoding: String.Encoding.utf8)
                } catch let error as NSError {
                    dialogWarningMessage(message: "File error", text: "\(error)")
                    return
                }
            }
        }
    }

}

func dialogOKCancel(question: String, text: String) -> Bool {
    let alert = NSAlert()
    alert.messageText = question
    alert.informativeText = text
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.addButton(withTitle: "Cancel")
    return alert.runModal() == .alertFirstButtonReturn
}

func dialogWarningMessage(message: String, text: String) {
    let alert = NSAlert()
    alert.messageText = message
    alert.informativeText = text
    alert.alertStyle = .warning
    alert.addButton(withTitle: "OK")
    alert.runModal()
}

func openFile(url:URL) {
    // Read the file
    var readString = ""
    do {
        readString = try String(contentsOf: url)
    } catch let error as NSError {
        dialogWarningMessage(message: "File error", text: "\(error)")
        return
    }
    
    // Parse the JSON
    do {
        let jsonSerialized = try JSONSerialization.jsonObject(with: readString.data(using: .utf8)!, options: []) as? [String : Any]
        let json = jsonSerialized
        let host:String? = json?["hostname"] as! String?
        let user:String? = json?["username"] as! String?
        let pass:String? = json?["password"] as! String?
        let hash:String? = json?["certhash"] as! String?
        let mappings = json?["mappings"] as! [Any]
        if ((host != nil) && (user != nil) && (hash != nil)) {
            // Disconnect if needed
            performBackToLogin()
            DispatchQueue.global().asyncAfter(deadline: .now() + 0.1) {
                loginView!.serverName = host ?? ""
                loginView!.serverUser = user ?? ""
                loginView!.serverPass = pass ?? ""
                trustedTlsServerCertHash = hash ?? ""
                
                // Parse the mappings
                globalAutoMaps = [AutoPortMap]()
                for xmap in mappings {
                    let map = xmap as! [String:Any]
                    let nodeId:String? = map["nodeId"] as! String?
                    if (nodeId != nil) {
                        let autoPortMap = AutoPortMap(nodeId:nodeId!)
                        if (map["name"] != nil) { autoPortMap.name = map["name"] as! String? ?? "" }
                        autoPortMap.remoteIp = map["remoteIp"] as! String?
                        autoPortMap.remotePort = (map["remotePort"] as! Int?) ?? 0
                        autoPortMap.localPort = (map["localPort"] as! Int?) ?? 0
                        autoPortMap.prot = (map["protocol"] as! Int?) ?? 0 // 1 = TCP, 2 = UDP
                        autoPortMap.appId = (map["appId"] as! Int?) ?? 0 // 0 = Custom, 1 = HTTP, 2 = HTTPS, 3 = RDP, 4 = SSH, 5 = SCP
                        if ((autoPortMap.remotePort > 0) && (autoPortMap.remotePort < 65536)) {
                            // We have a valid port map, store it and use it if we see this device
                            globalAutoMaps?.append(autoPortMap)
                        }
                    }
                }
                
                // Reconnect
                if ((host != "") && (user != "") && (pass != nil) && (pass != "")) {
                    performLogin(parent:parentView!, view:loginView!)
                }
            }
        }
    } catch let error as NSError {
        dialogWarningMessage(message: "File error", text: "\(error)")
        return
    }
}

func setGlobalViews(parent:ContentView, view:LoginView) {
    parentView = parent
    loginView = view
    if (globalAutoOpenUrl != nil) {
        // A MeshCentral cookie URL was passed it, use that to auto-login
        performAutoLogin(u:globalAutoOpenUrl!)
        globalAutoOpenUrl = nil
    } else if (globalAutoConnect == true) {
        // The host, user and pass where passed in as argument, use that to auto-login
        performLogin(parent:parent, view:view)
        globalAutoConnect = false
    }
}

func devicesScreenDisplayed(devicesView:DevicesView) {
    globalDevicesView = devicesView
    onDevicesChanged()
    if (mc != nil) { mc!.sendUpdateRequest() }
}

func performAutoLogin(u:URL) {
    // Parse the URL to create a connection URL and trusted TLS hash
    let components:URLComponents? = URLComponents(url: u, resolvingAgainstBaseURL: true)
    let tt:[URLQueryItem]? = components!.queryItems
    if (tt != nil) { for i in tt! { globalAuthParams[i.name] = i.value! } }
    let port = components!.port ?? 443
    let loginkey = globalAuthParams["key"] ?? nil
    var loginurl = "wss://\(components!.host!):\(port)\(components!.path)?auth=\(globalAuthParams["c"]!)";
    let rurl = "wss://\(components!.host!):\(port)/meshrelay.ashx"
    if (loginkey != nil) { loginurl += "&key=\(loginkey!)" }
    globalAuthUrl = loginurl
    trustedTlsServerCertHash = globalAuthParams["t"]?.lowercased() ?? nil
    
    // Decode any extra parameters
    let nodeId = globalAuthParams["nodeid"] ?? nil
    if (nodeId != nil) {
        let autoPortMap = AutoPortMap(nodeId:nodeId!)
        autoPortMap.remotePort = Int(globalAuthParams["remoteport"] ?? "0") ?? 0
        autoPortMap.localPort = Int(globalAuthParams["localport"] ?? "0") ?? 0
        autoPortMap.prot = Int(globalAuthParams["protocol"] ?? "1") ?? 1 // 1 = TCP, 2 = UDP
        autoPortMap.appId = Int(globalAuthParams["appid"] ?? "0") ?? 0 // 0 = Custom, 1 = HTTP, 2 = HTTPS, 3 = RDP, 4 = SSH, 5 = SCP
        autoPortMap.autoExit = (Int(globalAuthParams["autoexit"] ?? "0") ?? 0) != 0
        autoPortMap.launch = (Int(globalAuthParams["launch"] ?? "0") ?? 0) != 0
        if ((autoPortMap.remotePort > 0) && (autoPortMap.remotePort < 65536)) {
            // We have a valid port map, store it and use it if we see this device
            globalAutoMaps = [AutoPortMap]()
            globalAutoMaps?.append(autoPortMap)
        }
    }
    
    // Connect to the server
    mc = MeshCentralServer.init(url: globalAuthUrl!, rurl: rurl, user: "", pass: "", token: "", trustedCertHash: trustedTlsServerCertHash)
    mc!.onStateChange = onMeshCentralStateChanged
    mc!.on2faCookie = on2faCookie
    mc!.onDevicesChanged = onDevicesChanged
    
    // Disable the login button
    tokenAttemptCount = 0
    loginView!.fieldsEnabled = false;
    loginView!.loginStatus = "Connecting..."
    loginView!.cancelEnabled = true
}

// Called when the list of devices has changed
func onDevicesChanged() {
    if ((globalAutoMaps != nil) && (globalAutoMaps!.count > 0) && (globalDevicesView != nil) && (mc != nil)) {
        // See if we have any devices we need to add a port map to
        for automap in globalAutoMaps! {
            for device in mc!.devices {
                if ((automap.toDelete == false) && (automap.nodeId == device.id)) {
                    mc!.addPortMap(name: automap.name, nodeid: automap.nodeId, usage: automap.getUsage(), localPort: automap.localPort, remoteIp: automap.remoteIp, remotePort: automap.remotePort)
                    automap.toDelete = true
                    globalDevicesView!.selectedTab = DevicesView.Tab.mappings
                }
            }
        }
    }
}

func performLogin(parent:ContentView?, view:LoginView) {
    // Disable the form
    parentView = parent
    loginView = view
    tokenAttemptCount = 0
    view.fieldsEnabled = false;
    view.loginStatus = "Connecting..."
    view.cancelEnabled = true
    
    // Save settings, don't save if we are doing an auto-login
    if (globalAutoConnect == false) {
        settings.setValue(view.serverName, forKey: "serverName")
        settings.setValue(view.serverUser, forKey: "serverUser")
    }
    parentView?.serverName = view.serverName;
    parentView?.serverUser = view.serverUser;
    parentView?.serverPass = view.serverPass;
    
    // Parse the server name for a login key
    let serverNameSplit = parentView!.serverName.components(separatedBy: "?key=")
    let loginKey: String? = serverNameSplit.count > 1 ? serverNameSplit[1] : nil
    var url = "wss://\(serverNameSplit[0])/control.ashx"
    let rurl = "wss://\(serverNameSplit[0])/meshrelay.ashx"
    if (loginKey != nil) { url += "?key=" + loginKey! }
    
    // Check if we have a 2FA login cookie for this server
    var token:String? = nil
    let xserverUrl = settings.string(forKey: "twofaServerUrl")
    if (xserverUrl == url) { token = "cookie=" + (settings.string(forKey: "twofaServerCookie") ?? "") }
    
    // Load the ignored cert hash if we did not ignore one yet
    if (trustedTlsServerCertHash == nil) { trustedTlsServerCertHash = settings.string(forKey: "ignoredTlsCertHash") }
    
    // Connect to the server
    mc = MeshCentralServer.init(url: url, rurl: rurl, user: view.serverUser, pass: view.serverPass, token: token, trustedCertHash: trustedTlsServerCertHash)
    mc!.onStateChange = onMeshCentralStateChanged
    mc!.on2faCookie = on2faCookie
    mc!.onDevicesChanged = onDevicesChanged
}

// If we get a 2FA cookie from the server, save it
func on2faCookie(serverUrl:String, cookie:String) {
    if (rememberDevice == true) {
        settings.setValue(serverUrl, forKey: "twofaServerUrl")
        settings.setValue(cookie, forKey: "twofaServerCookie")
    }
}

func performToken(parent:ContentView?, view:TokenView, token:String) {
    // Disable the form
    parentView = parent
    tokenView = view
    view.fieldsEnabled = false;
    view.loginStatus = "Connecting..."
    view.cancelEnabled = true
    
    // Parse the server name for a login key
    let serverNameSplit = parentView!.serverName.components(separatedBy: "?key=")
    let loginKey: String? = serverNameSplit.count > 1 ? serverNameSplit[1] : nil
    var url = "wss://\(serverNameSplit[0])/control.ashx"
    let rurl = "wss://\(serverNameSplit[0])/meshrelay.ashx"
    if (loginKey != nil) { url += "?key=" + loginKey! }
    
    // Save if user wants to remember this device
    rememberDevice = view.isRememberChecked
    
    // Load the ignored cert hash if we did not ignore one yet
    if (trustedTlsServerCertHash == nil) { trustedTlsServerCertHash = settings.string(forKey: "ignoredTlsCertHash") }
    
    // Connect to the server
    if ((token != "") && (token != "**sms**") && (token != "**email**")) { tokenAttemptCount += 1; } else { tokenAttemptCount = 0 }
    mc = MeshCentralServer.init(url: url, rurl: rurl, user: parentView!.serverUser, pass: parentView!.serverPass, token: token, trustedCertHash: trustedTlsServerCertHash)
    mc!.onStateChange = onMeshCentralStateChanged;
    mc!.on2faCookie = on2faCookie
    mc!.onDevicesChanged = onDevicesChanged
}

func performBackToLogin() {
    if (mc != nil) { mc!.close() }
    if (parentView != nil) { parentView!.panel = 0 }
}

func loginScreenDisplayed(loginView:LoginView) {
    if (mc != nil) { mc!.close(); mc = nil }
}

func performIgnoreCert(remember:Bool) {
    if (remember) { settings.setValue(failedTlsServerCertHash, forKey: "ignoredTlsCertHash") }
    trustedTlsServerCertHash = failedTlsServerCertHash
    performLogin(parent:parentView, view:loginView!)
}

func onMeshCentralStateChanged(state: Int, cause: String?) {
    //print("onMeshCentraStateChanged \(state)")
    var gotoPanel:Int = -1
    var loginStatus:String? = nil
    //print("MeshCentral State: \(state), \(cause ?? "NULL")")
    switch (state) {
    case 0:
        //print(" Cause: \(mc!.closeCause ?? "NIL"), Msg: \(mc!.closeMsg ?? "NIL"), Types: \(mc!.tokenTypes), Days: \(mc!.twofaCookieDays)")
        if ((mc != nil) && (mc!.closeCause == "noauth")) {
            if (mc!.closeMsg == "tokenrequired") {
                if ((mc!.tokenSent & 1) != 0) { loginStatus = "Email sent"; parentView!.tokenTypes = 0 }
                else if ((mc!.tokenSent & 2) != 0) { loginStatus = "SMS sent"; parentView!.tokenTypes = 0 }
                else if (tokenAttemptCount > 0) { loginStatus = "Invalid token"; parentView!.tokenTypes = mc!.tokenTypes }
                else { loginStatus = ""; parentView!.tokenTypes = mc!.tokenTypes }
                parentView!.cookieDays = mc!.twofaCookieDays
                gotoPanel = 1
            } else {
                loginStatus = "Invalid username/password"
                gotoPanel = 0
            }
        } else if ((mc != nil) && (mc!.closeCause == "certCheck") && (mc!.trustedTlsServerCertHash == mc!.failedTlsServerCertHash)) {
            trustedTlsServerCertHash = nil
            loginStatus = "Certificate error"
            gotoPanel = 0
        } else if ((mc != nil) && (mc!.closeCause == "invalidCert")) {
            parentView!.certificateData = mc!.failedTlsServerCertInfo ?? ""
            failedTlsServerCertHash = mc!.failedTlsServerCertHash
            gotoPanel = 2
        } else {
            trustedTlsServerCertHash = nil
            loginStatus = ""
            gotoPanel = 0
        }
        if (loginView != nil) { loginView!.fieldsEnabled = true; loginView!.cancelEnabled = false }
        if (tokenView != nil) { tokenView!.fieldsEnabled = true; tokenView!.cancelEnabled = false }
        break;
    case 3:
        gotoPanel = 3
        
        // If we want to remember this device, ask for the 2FA cookie
        if (rememberDevice == true) { mc!.send(str: "{\"action\":\"twoFactorCookie\"}") }
        
        break;
    default:
        break;
    }
    
    // Set login status and change panel is needed
    if (loginStatus != nil) {
        parentView!.loginStatus = loginStatus!
        if (loginView != nil) { loginView!.loginStatus = loginStatus! }
        if (tokenView != nil) { tokenView!.loginStatus = loginStatus! }
    }
    if (gotoPanel >= 0) { parentView!.panel = gotoPanel }
}

func changeSettings(showOnlyOnlineDevices:Bool, bindLoopbackOnly:Bool) {
    globalShowOnlyOnlineDevices = showOnlyOnlineDevices
    globalBindLoopbackOnly = bindLoopbackOnly
    settings.setValue(showOnlyOnlineDevices, forKey: "showOnlyOnlineDevices")
    settings.setValue(bindLoopbackOnly, forKey: "bindLoopbackOnly")
    if (mc != nil) { mc!.forceUpdate() }
}

func logout() {
    if (mc != nil) { mc!.close() }
    globalAutoMaps = nil
}

