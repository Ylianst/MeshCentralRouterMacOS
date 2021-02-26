import Network
import CryptoKit
import Foundation

extension String {
    subscript(_ i: Int) -> String {
        let idx1 = index(startIndex, offsetBy: i)
        let idx2 = index(idx1, offsetBy: 1)
        return String(self[idx1..<idx2])
    }
    
    subscript (r: Range<Int>) -> String {
        let start = index(startIndex, offsetBy: r.lowerBound)
        let end = index(startIndex, offsetBy: r.upperBound)
        return String(self[start ..< end])
    }
    
    subscript (r: CountableClosedRange<Int>) -> String {
        let startIndex =  self.index(self.startIndex, offsetBy: r.lowerBound)
        let endIndex = self.index(startIndex, offsetBy: r.upperBound - r.lowerBound)
        return String(self[startIndex...endIndex])
    }
}

public class AutoPortMap {
    var name:String = ""
    var nodeId:String
    var remoteIp:String? = nil
    var remotePort:Int = 0
    var localPort:Int = 0
    var prot:Int = 0 // 1 = TCP, 2 = UDP
    var appId:Int = 0 // 1 = HTTP, 2 = HTTPS, 3 = RDP, 4 = SSH, 5 = SCP
    var autoExit:Bool = false
    var launch:Bool = false
    var toDelete:Bool = false
    
    init (nodeId:String) {
        self.nodeId = nodeId
    }
    
    func getUsage() -> String {
        if (appId == 1) { return "HTTP" }
        if (appId == 2) { return "HTTPS" }
        if (appId == 3) { return "RDP" }
        if (appId == 4) { return "SSH" }
        if (appId == 5) { return "SCP" }
        return ""
    }
    
    func doPrint() {
        print("nodeid: \(self.nodeId)")
        if (self.remoteIp != nil) { print("remoteIp: \(self.remoteIp!)") }
        print("remotePort: \(self.remotePort)")
        print("localPort: \(self.localPort)")
        print("prot: \(self.prot)")
        print("appId: \(self.appId)")
        print("autoExit: \(self.autoExit)")
        print("launch: \(self.launch)")
    }
}

// A device port map
public class PortMap : Equatable {
    let id = UUID()
    var name: String
    var device: Device
    var usage: String
    var localPort: Int
    var indicatedLocalPort: Int
    var remoteIp: String?
    var remotePort: Int
    var listener: NWListener
    var connectionsByID: [Int: ServerConnection] = [:]
    var listenerState: Int = 0 // 0 = Not Ready, 1 = Ready, 2 = Error
    
    init (name:String, device:Device, usage:String, localPort:Int, remoteIp:String?, remotePort:Int, listener:NWListener) {
        self.name = name
        self.device = device
        self.usage = usage
        self.localPort = localPort
        self.indicatedLocalPort = localPort
        self.remoteIp = remoteIp
        self.remotePort = remotePort
        self.listener = listener
    }
    
    public static func == (lhs: PortMap, rhs: PortMap) -> Bool {
        return lhs.id == rhs.id
    }
    
    public func getStateStr() -> String {
        if (remoteIp == nil) {
            if (connectionsByID.count == 0) { return "Local \(localPort) to port \(remotePort)" }
            else if (connectionsByID.count == 1) { return "Local \(localPort) to port \(remotePort), 1 connection" }
            return "Local \(localPort) to port \(remotePort), \(connectionsByID.count) connections"
        } else {
            if (connectionsByID.count == 0) { return "Local \(localPort) to \(remoteIp!):\(remotePort)" }
            else if (connectionsByID.count == 1) { return "Local \(localPort) to \(remoteIp!):\(remotePort), 1 connection" }
            return "Local \(localPort) to \(remoteIp!):\(remotePort), \(connectionsByID.count) connections"
        }
    }
}

// A MeshCentral device group
public class DeviceGroup {
    let id: String
    let domain: String
    //let mtype: Int
    var flags: Int
    var name: String
    var desc: String?
    var consent: Int
    
    init (id:String, domain:String, flags:Int, name:String, desc:String?, consent:Int) {
        self.id = id
        self.domain = domain
        self.flags = flags
        self.name = name
        self.desc = desc
        self.consent = consent
    }
}

// A MeshCentral device
public class Device {
    let id: String
    var name: String
    var desc: String?
    var meshid: String
    var icon: Int
    var conn: Int
    var pwr: Int
    
    init (id:String, name:String, desc:String?, meshid:String, icon:Int, conn:Int, pwr:Int) {
        self.id = id
        self.name = name
        self.desc = desc
        self.meshid = meshid
        self.icon = icon
        self.conn = conn
        self.pwr = pwr
    }
}

// Used to notifiy listening objects that the MeshCentral server state has changed
var meshCentralServerChanger:MeshCentralServerChanger = MeshCentralServerChanger()
public class MeshCentralServerChanger: ObservableObject {
    func update() {
        DispatchQueue.main.async {
            self.objectWillChange.send()
        }
    }
}

// The main MeshCentral class, communicates with the MeshCentral server
public class MeshCentralServer: NSObject, URLSessionWebSocketDelegate, ObservableObject {
    public let objectWillChange = ObjectWillChangePublisher()
    public var state:Int = 0
    var closeCause:String? = nil
    var closeMsg:String? = nil
    var tokenTypes:Int = 0
    var tokenSent:Int = 0
    var twofaCookieDays:Int = 0
    var session:URLSession?
    var urlstr:String?
    var rurlstr:String?
    var xurl:URL?
    var webSocketTask:URLSessionWebSocketTask?
    var onStateChange:((Int, String?) -> ())?
    var on2faCookie:((String, String) -> ())?
    var onDevicesChanged:(() -> ())?
    var trustedTlsServerCertHash:String? = nil
    var failedTlsServerCertHash:String? = nil
    var failedTlsServerCertInfo:String? = nil
    var userid:String? = nil
    var deviceGroups:[DeviceGroup] = [DeviceGroup]()
    var devices:[Device] = [Device]()
    var portMaps:[PortMap] = [PortMap]()
    var authCookie:String? = nil
    var authRCookie:String? = nil
    var authCookieTimer:Timer? = nil
    
    public func foundDevice(nodeid:String) -> Device? {
        for dev in devices { if (dev.id == nodeid) { return dev } }
        return nil
    }
    
    public init(url:String, rurl:String, user:String, pass:String, token:String?, trustedCertHash:String?) {
        trustedTlsServerCertHash = trustedCertHash
        
        // Initialize the super class
        super.init()
        
        // Setup a HTTP session
        session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        
        var authHeader:String? = nil
        if ((user != "") && (pass != "")) {
            // Convert user, password and token to base64 and create the x-meshauth header value
            let b64user = user.data(using: .utf8)?.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
            let b64pass = pass.data(using: .utf8)?.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
            authHeader = b64user! + "," + b64pass!
            if (token != nil) {
                let b64token = token!.data(using: .utf8)?.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
                authHeader! += ("," + b64token!)
            }
        }
        
        // Setup the URL and request header
        self.urlstr = url
        self.rurlstr = rurl
        xurl = URL(string: url)!
        var request = URLRequest(url: xurl!)
        if (authHeader != nil) { request.setValue(authHeader!, forHTTPHeaderField: "x-meshauth") }
        
        // Start the web socket session
        webSocketTask = session!.webSocketTask(with: request)
        webSocketTask!.resume()
        changeState(newState: 1)
    }
    
    public func forceUpdate() {
        // Fire event
        meshCentralServerChanger.update()
    }
    
    private func changeState(newState:Int) {
        if (newState == state) { return }
        state = newState;
        if (onStateChange != nil) { onStateChange!(state, closeCause); }
    }
    
    private func connected() {
        changeState(newState: 2)
        receive()
        self.send(str: "{\"action\":\"authcookie\"}")
    }
    
    @objc func refreshCookie(timer: Timer)
    {
        if (state == 3) { self.send(str: "{\"action\":\"authcookie\"}") }
    }
    
    public func sendUpdateRequest() {
        self.send(str: "{\"action\":\"meshes\"}")
        self.send(str: "{\"action\":\"nodes\"}")
    }
    
    private func disconnected() {
        changeState(newState: 0)
        
        // Stop the auth cookie timer
        if (authCookieTimer != nil) {
            authCookieTimer?.invalidate()
            authCookieTimer = nil
        }
        
        // Close all port mappings
        while (portMaps.count > 0) { removePortMap(map:portMaps[0]) }
    }
    
    private func ping() {
        webSocketTask!.sendPing { error in
            if let error = error {
                print("Error when sending PING \(error)")
            } else {
                print("Web Socket connection is alive")
                /*
                 DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
                 self.ping()
                 }
                 */
            }
        }
    }
    
    // Close the websocket
    func close() {
        closeCause = "UserClose";
        let reason = "Closing connection".data(using: .utf8)
        self.webSocketTask!.cancel(with: .goingAway, reason: reason)
        disconnected()
    }
    
    // Send a string to the MeshCentral server
    func send(str:String) {
        self.webSocketTask!.send(.string(str)) { error in }
    }
    
    // This is an example of how to send many times on a timer
    func sendMany() {
        DispatchQueue.global().asyncAfter(deadline: .now() + 1) {
            self.sendMany()
            self.webSocketTask!.send(.string("New Message")) { error in
                if let error = error {
                    print("Error when sending a message \(error)")
                }
            }
        }
    }
    
    // Start receiving data
    private func receive() {
        self.webSocketTask!.receive { result in
            switch result {
            case .success(let message):
                switch message {
                //case .data(let data):
                //print("Data received \(data)")
                //break
                case .string(let text):
                    //print("Text received \(text)")
                    self.parseCommand(data: text)
                default:
                    break;
                }
                self.receive()
            case .failure(_):
                self.disconnected()
            }
        }
    }
    
    // Parse an incoming JSON string
    private func parseCommand(data: String) {
        //print("Parse: \(data)")
        do {
            // Convert the data to JSON
            let jsonSerialized = try JSONSerialization.jsonObject(with: data.data(using: .utf8)!, options: []) as? [String : Any]
            let json = jsonSerialized
            let action:String? = json?["action"] as! String?
            //print("Action: \(action ?? "NULL")")
            switch action {
            case "close":
                // Indicates the server is closing the connection
                closeCause = json?["cause"] as! String?
                closeMsg = json?["msg"] as! String?
                tokenTypes = 0
                if ((json?["email2fa"] as! Bool?) == true) { tokenTypes += 1; }
                if ((json?["sms2fa"] as! Bool?) == true) { tokenTypes += 2; }
                tokenSent = 0
                if ((json?["email2fasent"] as! Bool?) == true) { tokenSent += 1; }
                if ((json?["sms2fasent"] as! Bool?) == true) { tokenSent += 2; }
                twofaCookieDays = 0
                if (json?["twoFactorCookieDays"] != nil) { twofaCookieDays = (json?["twoFactorCookieDays"] as! Int); }
                break;
            case "serverinfo":
                // Information about the server
                changeState(newState: 3)
                
                // Start a 24 minute timer to renew authentication cookies
                DispatchQueue.main.async {
                    if (self.authCookieTimer == nil) {
                        self.authCookieTimer = Timer.scheduledTimer(timeInterval: 1440.0, target: self, selector: #selector(self.refreshCookie(timer:)), userInfo: nil, repeats: true)
                        self.authCookieTimer?.tolerance = 120 // 2 minute tolerence
                    }
                }
                break;
            case "authcookie":
                authCookie = json?["cookie"] as! String?
                authRCookie = json?["rcookie"] as! String?
                break;
            case "userinfo":
                // Information about our user account
                let userinfo = json?["userinfo"] as! [String:Any]
                userid = userinfo["_id"] as! String?
                break;
            case "twoFactorCookie":
                // This is a cookie that can be used as a way to skip 2FA for a limited time
                let cookie = json?["cookie"] as! String?
                if ((on2faCookie != nil) && (cookie != nil)) { on2faCookie!(urlstr!, cookie!) }
                break;
            case "meshes":
                // The current device group list from the server
                var xdeviceGroups = [DeviceGroup]()
                let nodeGroups = json?["meshes"] as! [Any]
                for nodeGroup in nodeGroups {
                    let nodeGroupCast = nodeGroup as! [String : Any]
                    let deviceGroup = DeviceGroup(
                        id: nodeGroupCast["_id"] as! String,
                        domain: nodeGroupCast["domain"] as! String,
                        flags: (nodeGroupCast["flags"] as! Int?) ?? 0,
                        name: nodeGroupCast["name"] as! String,
                        desc: nodeGroupCast["desc"] as! String?,
                        consent: (nodeGroupCast["consent"] as! Int?) ?? 0
                    )
                    xdeviceGroups.append(deviceGroup)
                }
                
                // Sort the device group list by name
                xdeviceGroups.sort { $0.name < $1.name }
                deviceGroups = xdeviceGroups
                break;
            case "nodes":
                // The current device list from the server
                var xdevices = [Device]()
                let nodeGroups = json?["nodes"] as! [String : Any]
                for nodeGroup in nodeGroups {
                    let nodeGroupCast = nodeGroup.value as! [Any]
                    for node in nodeGroupCast {
                        let dev = node as! [String : Any]
                        let device = Device(
                            id: dev["_id"] as! String,
                            name: dev["name"] as! String,
                            desc: dev["desc"] as! String?,
                            meshid: nodeGroup.key,
                            icon: dev["icon"] as! Int,
                            conn: (dev["conn"] as! Int?) ?? 0,
                            pwr: (dev["pwr"] as! Int?) ?? 0
                        )
                        xdevices.append(device)
                    }
                }
                
                // Sort the device list by name
                xdevices.sort { $0.name < $1.name }
                
                // Fire event
                devices = xdevices
                if (onDevicesChanged != nil) { onDevicesChanged!() }
                meshCentralServerChanger.update()
                break
            case "event":
                // Process a server event
                let event = json?["event"] as! [String : Any]
                let eventAction = event["action"] as! String
                switch (eventAction) {
                case "changenode":
                    // Process a change node event
                    let nodeid = event["nodeid"] as! String
                    let dev = foundDevice(nodeid:nodeid)
                    if (dev != nil) {
                        let newnode = event["node"] as! [String : Any]
                        
                        // Update the device
                        if (newnode["name"] != nil) { dev!.name = newnode["name"] as! String }
                        dev!.desc = newnode["desc"] as! String?
                        if (newnode["icon"] != nil) { dev!.icon = newnode["icon"] as! Int }
                        if (newnode["meshid"] != nil) { dev!.meshid = newnode["meshid"] as! String }
                        
                        // Sort the device list by name
                        devices.sort { $0.name < $1.name }
                        
                        // Fire event
                        meshCentralServerChanger.update()
                    }
                    break
                case "nodeconnect":
                    // Node connection state has changed
                    let nodeid = event["nodeid"] as! String
                    let dev = foundDevice(nodeid:nodeid)
                    if (dev != nil) {
                        if (event["conn"] != nil) { dev!.conn = event["conn"] as! Int }
                        if (event["pwr"] != nil) { dev!.pwr = event["pwr"] as! Int }
                    
                        // If a device disconnects, remove all it's port mappings for that device
                        if ((dev!.conn & 1) == 0) {
                            var portMapsToRemove = [PortMap]()
                            for map:PortMap in portMaps { if (map.device.id == nodeid) { portMapsToRemove.append(map) } }
                            for map:PortMap in portMapsToRemove { removePortMap(map: map) }
                        }
                        
                        // Fire event
                        meshCentralServerChanger.update()
                    }
                    break;
                default:
                    break
                }
                break
            default:
                break
            }
        } catch let error as NSError {
            print(error.localizedDescription)
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        //print("Web Socket connection error")
        disconnected()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        closeCause = nil
        //print("Web Socket did connect")
        connected()
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        //print("Web Socket did disconnect")
        disconnected()
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let isServerTrusted = SecTrustEvaluateWithError(serverTrust, nil)
                //print("isServerTrusted: \(isServerTrusted)")
                
                if(isServerTrusted) {
                    // Compute the certificate hash, this is used to save the .mcrouter files
                    if let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
                        let serverCertificateData = SecCertificateCopyData(serverCertificate)
                        let hashed = SHA384.hash(data: (serverCertificateData as Data))
                        trustedTlsServerCertHash = hashed.compactMap { String(format: "%02x", $0) }.joined()
                    }
                    
                    // Server is already trusted by the OS
                    completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust:serverTrust))
                    return
                } else {
                    // Server is not trusted by the OS
                    if let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
                        let serverCertificateData = SecCertificateCopyData(serverCertificate)
                        
                        /*
                        // Convert the certificate to Base64 and print it
                        let certdata = serverCertificateData as Data
                        let b64tlscert = certdata.base64EncodedString(options: Data.Base64EncodingOptions(rawValue: 0))
                        print("B64 Cert: " + b64tlscert);
                        */
                        
                        // Compute the certificate hash
                        let hashed = SHA384.hash(data: (serverCertificateData as Data))
                        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
                        
                        // Check if the hash is trusted
                        if (trustedTlsServerCertHash == hashString) {
                            // Certificate hash is correct
                            failedTlsServerCertHash = hashString
                            closeCause = "certCheck"
                            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust:serverTrust))
                            return
                        } else {
                            // Certificate hash is not trusted
                            failedTlsServerCertHash = hashString
                            closeCause = "invalidCert"
                            
                            // Get the certificate common name
                            let commonName = SecCertificateCopySubjectSummary(serverCertificate)! as String
                            failedTlsServerCertInfo = "Common Name:\n  \(commonName)\n\nSHA384 Certificate Hash:\n  \(hashString[0...31])\n  \(hashString[32...63])\n  \(hashString[64...95])\n"
                        }
                    }
                }
            }
        }
        
        // Certificate hash mismatch
        completionHandler(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
    }
    
    // Add a port map
    public func addPortMap(name:String, nodeid:String, usage:String, localPort:Int, remoteIp:String?, remotePort:Int) {
        // Get the device
        var device:Device? = nil
        for dev in devices { if (dev.id == nodeid) { device = dev } }
        
        if (device != nil) {
            // Start the TCP server
            let port: NWEndpoint.Port
            port = NWEndpoint.Port(rawValue: UInt16(truncatingIfNeeded: localPort))!
            let listener:NWListener = try! NWListener(using: .tcp, on: port)
            
            // Create the port map
            let map = PortMap(name:name, device:device!, usage:usage, localPort: localPort, remoteIp: remoteIp, remotePort: remotePort, listener:listener)
            portMaps.append(map)
            
            // Start the listener
            //listener.stateUpdateHandler = stateDidChange(to:)
            listener.stateUpdateHandler = { (newState: NWListener.State) in
                //print("TCP Server State Change \(newState)")
                self.stateDidChange(newState:newState, listener:listener, map:map)
            }
            listener.newConnectionHandler = { (newConnection) in
                //print("New TCP Connection")
                self.didAccept(nwConnection:newConnection, listener:listener, map:map)
            }
            listener.start(queue: .main)
            
            // Sort the port map list by name
            portMaps.sort { ($0.device.name + $0.name) < ($1.device.name + $1.name) }
            
            // Fire update event
            forceUpdate()
        }
    }
    
    // Remove a port map
    public func removePortMap(map:PortMap) {
        // Clean up the listener
        map.listener.cancel()
        
        // Close all existing relay sessions
        for (_, conn) in map.connectionsByID { conn.stop(error:nil) }
        
        // Remove the port map
        if let index = portMaps.firstIndex(of: map) {
            if (portMaps.count >= index) { portMaps.remove(at: index) }
        }
        
        // Fire update event
        forceUpdate()
    }
    
    // private func stateDidChange(to newState: NWListener.State, map:PortMap) {
    private func stateDidChange(newState: NWListener.State, listener:NWListener, map:PortMap) {
        //print("Port: \(listener.port.debugDescription)")
        var change:Bool = false
        let realPort:Int = Int(listener.port!.rawValue);
        if (map.localPort != realPort) { map.localPort = realPort; change = true }
        switch newState {
        case .ready:
            //print("Server ready.")
            if (map.listenerState != 1) { map.listenerState = 1; change = true }
        case .failed(_):
            //print("Server failure, error: \(error.localizedDescription)")
            if (map.listenerState != 2) { map.listenerState = 2; change = true }
        //exit(EXIT_FAILURE)
        default:
            break
        }
        
        // Fire update event
        if (change == true) { forceUpdate() }
    }
    
    private func didAccept(nwConnection: NWConnection, listener:NWListener, map:PortMap) {
        let connection = ServerConnection(nwConnection: nwConnection, map:map)
        map.connectionsByID[connection.id] = connection
        connection.didStopCallback = { _ in
            self.connectionDidStop(connection, map:map)
        }
        connection.start()
        //connection.send(data: "Welcome you are connection: \(connection.id)".data(using: .utf8)!)
        //print("server did open connection \(connection.id)")
        
        // Fire update event
        forceUpdate()
    }
    
    private func connectionDidStop(_ connection: ServerConnection, map:PortMap) {
        map.connectionsByID.removeValue(forKey: connection.id)
        //print("server did close connection \(connection.id)")
        
        // Fire update event
        forceUpdate()
    }
}


@available(macOS 10.14, *)
class ServerConnection: NSObject, URLSessionWebSocketDelegate {
    // The TCP maximum package size is 64K 65536
    let MTU = 65536
    let map:PortMap
    
    // TCP connection
    private static var nextID: Int = 0
    var connection:NWConnection? = nil
    let id:Int
    
    // Websocket connection
    var relaySession:URLSession? = nil
    var webSocketTask:URLSessionWebSocketTask? = nil
    var relayStart:Bool = false
    
    init(nwConnection: NWConnection, map:PortMap) {
        self.connection = nwConnection
        self.map = map
        self.id = ServerConnection.nextID
        ServerConnection.nextID += 1
    }
    
    var didStopCallback: ((Error?) -> Void)? = nil
    
    func start() {
        if ((mc == nil) || (connection == nil)) { return; }
        //print("connection \(id) will start")
        // We start with the connection paused, don't call setupReceive() yet.
        connection!.stateUpdateHandler = self.stateDidChange(to:)
        connection!.start(queue: .main)
        
        // Launch the websocket connection to the server
        relaySession = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        
        // Setup the URL and request header
        var url = mc!.rurlstr! + "?auth=\(mc!.authCookie!)&nodeid=\(map.device.id)&tcpport=\(map.remotePort)";
        if (map.remoteIp != nil) { url += "&tcpaddr=\(map.remoteIp!)" }
        let xurl = URL(string: url)
        //print("Opening tunnel to \(url)")
        
        // Start the web socket session
        webSocketTask = relaySession!.webSocketTask(with: URLRequest(url: xurl!))
        webSocketTask!.resume()
    }
    
    private func stateDidChange(to state: NWConnection.State) {
        //print("stateDidChange \(state)")
        switch state {
        case .waiting(let error):
            stop(error: error)
            break
        case .ready:
            //print("connection \(id) ready")
            break
        case .failed(let error):
            stop(error: error)
            break
        default:
            break
        }
    }
    
    private func receive() {
        if (connection == nil) { return }
        connection!.receive(minimumIncompleteLength: 1, maximumLength: MTU) { (data, _, isComplete, error) in
            if ((data != nil) && (data?.isEmpty == false)) {
                //print("connection \(self.id) did receive, len: \(data!.count)")
                self.webSocketTask!.send(.data(data!)) { error in
                    if (error == nil) { self.receive() }
                }
            }
            if isComplete {
                self.stop(error: nil)
            } else if let error = error {
                self.stop(error: error)
            } else if ((data == nil) || (data?.isEmpty == true)) {
                self.receive()
            }
        }
    }
    
    /*
     func send(data: Data) {
     self.connection.send(content: data, completion: .contentProcessed( { error in
     if let error = error {
     self.connectionDidFail(error: error)
     return
     }
     print("connection \(self.id) did send, data: \(data as NSData)")
     }))
     }
     
     // Send a string to the relay websocket
     func wssend(str:String) {
     self.webSocketTask!.send(.string(str)) { error in }
     }
     */
    
    public func stop(error: Error?) {
        connection!.stateUpdateHandler = nil
        connection!.cancel()
        if let didStopCallback = didStopCallback {
            self.didStopCallback = nil
            didStopCallback(error)
        }
    }
    
    // Start receiving relay data
    private func wsreceive() {
        //print("wsreceive")
        self.webSocketTask!.receive { result in
            //print("wsreceiveDone")
            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    //print("Relay WS Data received \(data.count)")
                    if (self.connection != nil) {
                        self.connection!.send(content: data, completion: .contentProcessed( { error in
                            if let error = error {
                                self.stop(error: error)
                                return
                            } else {
                                self.wsreceive()
                            }
                        }))
                    }
                    break
                case .string(let text):
                    // Agent connected to the server, start transfering data
                    if ((self.relayStart == false) && ((text == "c") || (text == "cr"))) {
                        self.relayStart = true
                        self.receive()
                    }
                    self.wsreceive()
                default:
                    self.wsreceive()
                    break;
                }
            case .failure(_):
                self.stop(error: nil)
            }
        }
    }
    
    public func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        //print("Relay Web Socket connection error")
        stop(error: nil)
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didOpenWithProtocol protocol: String?) {
        //print("Relay Web Socket did connect")
        wsreceive() // Start receiving data
    }
    
    public func urlSession(_ session: URLSession, webSocketTask: URLSessionWebSocketTask, didCloseWith closeCode: URLSessionWebSocketTask.CloseCode, reason: Data?) {
        //print("Relay Web Socket did disconnect")
        stop(error: nil)
    }
    
    public func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Swift.Void) {
        if (challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust) {
            if let serverTrust = challenge.protectionSpace.serverTrust {
                let isServerTrusted = SecTrustEvaluateWithError(serverTrust, nil)
                if(isServerTrusted) {
                    // Server is already trusted by the OS
                    completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust:serverTrust))
                    return
                } else {
                    // Server is not trusted by the OS
                    if let serverCertificate = SecTrustGetCertificateAtIndex(serverTrust, 0) {
                        let serverCertificateData = SecCertificateCopyData(serverCertificate)
                        
                        // Compute the certificate hash
                        let hashed = SHA384.hash(data: (serverCertificateData as Data))
                        let hashString = hashed.compactMap { String(format: "%02x", $0) }.joined()
                        
                        // Check if the hash is trusted
                        if (trustedTlsServerCertHash == hashString) {
                            // Certificate hash is correct
                            completionHandler(URLSession.AuthChallengeDisposition.useCredential, URLCredential(trust:serverTrust))
                            return
                        }
                    }
                }
            }
        }
        
        // Certificate hash mismatch
        completionHandler(URLSession.AuthChallengeDisposition.cancelAuthenticationChallenge, nil)
    }
    
}
