//
//  XCode_GHDSUApp.swift
//  XCode-GHDSU
//
//  Created by Daniel Caufield on 01.03.2023.
//

import SwiftUI
import UserNotifications

enum WindowSize {
    static let min = CGSize(width: 400, height: 300)
    static let max = CGSize(width: 450, height: 350)
}

extension FileManager {
    func sizeOfFile(atPath path: String) -> Int64? {
        guard let attrs = try? attributesOfItem(atPath: path) else {
            return nil
        }

        return attrs[.size] as? Int64
    }
}

func applicationDidFinishLaunching(_ aNotification: Notification) -> String {
    if let appleEventDescriptor = aNotification.userInfo?["NSAppleEventDescriptor"] as? NSAppleEventDescriptor,
       let urlString = appleEventDescriptor.paramDescriptor(forKeyword: keyDirectObject)?.stringValue,
       let url = URL(string: urlString) {
        print("\(url.absoluteString)")
        return url.absoluteString;
    }
    return ""
}

//all this work for control over a button, sheesh
extension Color {
    static let mckBlue = Color(red: 39 / 255.0, green: 63 / 255.0, blue: 221 / 255.0);
    static let paleWhite = Color(white: 1, opacity: 179 / 255.0);
}

struct McKButt: ButtonStyle {
  func makeBody(configuration: Self.Configuration) -> some View {
    ButtStyleView(configuration: configuration)
  }
}

private extension McKButt {
  struct ButtStyleView: View {
    // tracks if the button is enabled or not
    @Environment(\.isEnabled) var isEnabled
    // tracks the pressed state
    let configuration: McKButt.Configuration

    var body: some View {
      return configuration.label
        .cornerRadius(8)
        .frame(width: 120, height: 40)
        // change the text color based on if it's disabled
        .foregroundColor(isEnabled ? .white : .paleWhite)
        .background(RoundedRectangle(cornerRadius: 5)
          // change the background color based on if it's disabled
          .fill(isEnabled ? Color.mckBlue : Color.gray)
        )
        // make the button a bit more translucent when pressed
        .opacity(configuration.isPressed ? 0.8 : 1.0)
        // make the button a bit smaller when pressed
        .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
    }
  }
}

extension Task where Success == Never, Failure == Never {
    static func sleep(seconds: Double) async throws {
        let duration = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: duration)
    }
}

class ErrorInfo: ObservableObject {
    @Published var title: String
    @Published var message: String
    @Published var isError: Bool
//    @Published var allowRetry: Bool
    
    init(title: String = "Package info missing. Please contact GHD", msg: String = "", active: Bool = false) {
        self.title = title
        self.message = msg
        self.isError = active
//        self.allowRetry = allowRetry
    }

    func clear() {
        self.title = ""
        self.message = ""
        self.isError = false
//        self.allowRetry = false
    }
}

struct ErrorView: View {
    @State var errorInfo = ErrorInfo()
    
    var body: some View {
//        Color(NSColor.underPageBackgroundColor).ignoresSafeArea().frame(height: 0)
        Color(NSColor.windowBackgroundColor).ignoresSafeArea().frame(height: 0)
        
        Text(errorInfo.title)
            .lineLimit(2).multilineTextAlignment(.center)
            .font(.system(size: 20)).bold();
        //error image
        Image(systemName: "exclamationmark.octagon")
            .imageScale(.large)
            .font(.system(size: 42))
            .foregroundColor(Color(.systemRed))
        //error text
        if (!errorInfo.message.isEmpty) {
            Text("Error message:").font(.system(size: 12));
            Text(errorInfo.message).font(.system(size:12));
        }
        else {
            Spacer().frame(width: 10, height: 10)
        }
//
//        if (errorInfo.allowRetry) {
//            Button("Try Again", action: {} ).buttonStyle(McKButt())
//        }
    }
}

//temporary logger functionality
class Logger {
    static func log(_ message: String) {
        guard let logFile = URL(string: FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first!.absoluteString + "/Logs/ghdsu.log")
        else { return }
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        let timestamp = formatter.string(from: Date())
        guard let data = (timestamp + ": " + message + "\n").data(using: String.Encoding.utf8) else { return }

        if FileManager.default.fileExists(atPath: logFile.path) {
            if let fileHandle = try? FileHandle(forWritingTo: logFile) {
                fileHandle.seekToEndOfFile()
                fileHandle.write(data)
                fileHandle.closeFile()
            }
        }
        else {
            try? data.write(to: logFile, options: .atomicWrite)
        }
    }
}

//force app to close when window closed, because it no longer does this automatically
class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ application: NSApplication) -> Bool {
        return true
    }
    func applicationWillUpdate(_ notification: Notification) {
        if let menu = NSApplication.shared.mainMenu {
            // remove all menu items after the app name
            menu.items.removeSubrange(1...)
        }
        
    }
}

@main
    struct XCode_GHDSUApp: App {
        //instantiate the app delegate so that it overrides the behaviour of closing the window
        @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
        
        @State var installView = true;
        //to bypass shellview, uncomment below
        //        @State private var openedURL: URL = URL(string: "ghdsu://params?id=878&name=VLC%20Media%20Player&time=5&path=VLCs.app&size=98765")!
        //to immitate URL with params, uncomment below
        //        @State private var openedURL: URL = URL(string: "ghdsoftwareutility://ghd/?id=mck_app_cat_item&sys_id=2b10e182db83db44d3829475db96190b&os=macOS&fmno=154166")!
        //new format
        
        //kate's software
        //        @State private var openedURL: URL = URL(string: "ghdsoftwareutility://ghd/?id=mck_app_cat_item&sys_id=d680ec4387ede59020d1670a0cbb35a6&fmno=11949646")!
        
        // FOR VLC FROM STORE:
        //        @State private var openedURL: URL = URL(string: "ghdsoftwareutility://ghd/?id=mck_app_cat_item&sys_id=69e00687dbc6b600b6e5ffb5ae961979&fmno=122912")!
        
        //slack
        //        @State private var openedURL: URL = URL(string: "ghdsoftwareutility://ghd/?id=mck_app_cat_item&sys_id=99f04687dbc6b600b6e5ffb5ae96195b&fmno=122912")!
        //        ghdsoftwareutility://ghd/?catItemID=2b10e182db83db44d3829475db96190b&os=macOS&fmno=154166
        
        //RTools
//                @State private var openedURL: URL = URL(string: "ghdsoftwareutility://ghd/?id=mck_app_cat_item&sys_id=092660981bf7bc1042a911b1b24bcbab&fmno=122912")!
        
        
        //for prod behaviour, uncomment below
        @State private var openedURL: URL = URL(string: "ghdsoftwareutility://")!
        @State private var params: Dictionary<String, String>? = nil
        @State private var pkgInfo: Dictionary<String, String> = [:]
        
        @StateObject var errorInfo = ErrorInfo()
        
        var body: some Scene {
            WindowGroup {
                ZStack {
                    Spacer()
                        .handlesExternalEvents(preferring: Set(arrayLiteral: "*"), allowing: Set(arrayLiteral: "*"))
                            .frame(width: 0, height: 0)
                            .hidden()
                    
                    //this part is undocumented hocus pocus but it still prevents opening duplicate windows because swift is buggy pos
//                    ContentView().handlesExternalEvents(preferring: Set(arrayLiteral: "*"), allowing: Set(arrayLiteral: "*"))
//                        .frame(width: 0, height: 0)
//                        .hidden()
                    
                    VStack(spacing: 10) {
                        if (errorInfo.isError) {
                            ErrorView(errorInfo: errorInfo)
                            
                        }
                        else {
                            if (openedURL.query == nil) {
                                Spacer().frame(width: 0, height: 0) //this is needed to fix bugs with swfit layout and rendering don't ask why
                                ErrorView(errorInfo: ErrorInfo(title: "Package info missing. Please contact GHD",
                                                               msg: "Query not found",
                                                               active: true
                                                              )
                                )
                                
                                .frame(minWidth: 500, maxWidth: 500)
                                Spacer().frame(width: 0, height: 20)
                            }
                            else if (pkgInfo == [:]) {
                                ShellView(installed: $installView, pkgInfo: $pkgInfo, params: params ?? UrlHandler(input: openedURL))
                            }
                            else {
                                InstallView(
                                    visibility: $installView,
                                    installationInProgress: false,
                                    params: pkgInfo
                                    // for VLC demo, uncomment below along with alt params above
                                    //                                    params: UrlHandler(input: openedURL)
                                )
                            }
                        }
                    }
                    .fixedSize()
                    .onAppear {
//                        var logtext = ""
//                        let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
//                        let fileUrl = documentsUrl.appendingPathComponent("ghdsu.log")
                        
                        let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: "com.McK.GHDSU")
                        let openWindow = NSApplication.shared.windows
                        Logger.log("Instances running: \(runningApp.count)")
                        
                        if openWindow.count > 1 {
                            Logger.log("(onAppear)dismissing new window")
                            let thisWindow = NSApplication.shared.windows.last!
                            NSApplication.shared.window(withWindowNumber: thisWindow.windowNumber)!.close()
                            Logger.log("(onAppear)new count: \(NSApplication.shared.windows.count)")
                        }
                        
                        if runningApp.count > 1 {
                            
                            Logger.log("Closing...")
//
//                            var logtext = "Instances running: \(runningApp.count)"
//                            let documentsUrl = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] as NSURL
//                            let fileUrl = documentsUrl.appendingPathComponent("ghdsu.log")
//
                            
                            runningApp.first!.activate(options: .activateAllWindows)
                            runningApp.last!.terminate()
                        }
                        //try! logtext.write(to: fileUrl!, atomically: true, encoding: String.Encoding.utf8)
                    }
                    .onOpenURL { url in
                        openedURL = url;
                        //for prod
                        let runningApp = NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.McK.GHDSU")
                        let openWindow = NSApplication.shared.windows
                        
                        if openWindow.count > 1 {
                            Logger.log("GHDSU is already open. Dismissing new window...")
                            let thisWindow = NSApplication.shared.windows.last!
                            NSApplication.shared.window(withWindowNumber: thisWindow.windowNumber)!.close()
                        }
                        
                        if runningApp.count > 1 {
                            Logger.log("GHDSU is already running. Terminating new instance...")
                            runningApp.first!.activate(options: .activateAllWindows)
                            runningApp.last!.terminate()
                        }
                        else { //otherwise parse url and do nothing else
                            params = UrlHandler(input: url);
                            //to skip shellview, uncomment below
                            //pkgInfo = UrlHandler(input: url);
                        }
                    }
                    
                }
            }
            .windowResizability(.contentSize)
            .windowStyle(.hiddenTitleBar)
            .handlesExternalEvents(matching: Set(arrayLiteral: "*"))
        }
    }
 
func UrlHandler(input: URL) -> [String: String] {
    //do the necessary validation first
    var dic: [String: String] = [:];
    //input would be something like:
    // ghdsu://id=878&name=VLC%20Media%20Player&time=5&path=/Library/VLC&size=98765=
    if (input.query != nil) {
        let query: [String] = input.query!.components(separatedBy: "&")
        for i in 0...query.count-1 {
            dic.updateValue(query[i].components(separatedBy: "=")[1].replacingOccurrences(of:"%20", with:" "), forKey: query[i].components(separatedBy: "=")[0])
        }
        print(dic)
        return dic;
    }
    else { return [:] }
}
