//
//  XCode_GHDSUApp.swift
//  XCode-GHDSU
//
//  Created by Daniel Caufield on 01.03.2023.
//

import SwiftUI

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
    @Published var allowRetry: Bool
    
    init(title: String = "Package info missing. Please contact GHD", msg: String = "", active: Bool = false, allowRetry: Bool = false) {
        self.title = title
        self.message = msg
        self.isError = active
        self.allowRetry = allowRetry
    }

    func clear() {
        self.title = ""
        self.message = ""
        self.isError = false
        self.allowRetry = false
    }
}

struct ErrorView: View {
    @State var errorInfo = ErrorInfo()
    
    var body: some View {
        Color(NSColor.underPageBackgroundColor).ignoresSafeArea()
        
        Text(errorInfo.title)
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
        
        if (errorInfo.allowRetry) {
            Button("Try Again", action: {} ).buttonStyle(McKButt())
        }
    }
}

class TransparentWindowView: NSView {
  override func viewDidMoveToWindow() {
      window?.backgroundColor = NSColor.darkGray
    super.viewDidMoveToWindow()
  }
}

struct TransparentWindow: NSViewRepresentable {
   func makeNSView(context: Self.Context) -> NSView { return TransparentWindowView() }
   func updateNSView(_ nsView: NSView, context: Context) { }
}

//
//struct VisualEffectView: NSViewRepresentable {
//    func makeNSView(context: Context) -> NSVisualEffectView {
//        let view = NSVisualEffectView()
//
//        view.blendingMode = .behindWindow
////        view.blendingMode = .withinWindow
//        view.state = .active
//        view.material = .underWindowBackground
////        view.material = .windowBackground
//
//        return view
//    }
//
//    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
//        //
//    }
//}

@main
    struct XCode_GHDSUApp: App {
        @State var installView = true;
        //to bypass shellview, uncomment below
//        @State private var openedURL: URL = URL(string: "ghdsu://params?id=878&name=VLC%20Media%20Player&time=5&path=VLC.app&size=98765")!
        //to immitate URL with params, uncomment below
//        @State private var openedURL: URL = URL(string: "ghdsoftwareutility://ghd/?id=mck_app_cat_item&sys_id=2b10e182db83db44d3829475db96190b&os=macOS&fmno=154166")!
        //new format
        @State private var openedURL: URL = URL(string: "ghdsoftwareutility://ghd/?id=mck_app_cat_item&sys_id=d680ec4387ede59020d1670a0cbb35a6&fmno=11949646")!
        //ghdsoftwareutility://ghd/?catItemID=2b10e182db83db44d3829475db96190b&os=macOS&fmno=154166
        //for prod behaviour, uncomment below
//        @State private var openedURL: URL = URL(string: "ghdsoftwareutility://")!
        @State private var params: Dictionary<String, String>? = nil
        @State private var pkgInfo: Dictionary<String, String> = [:]
        
        @StateObject var errorInfo = ErrorInfo()
        
        var body: some Scene {
            WindowGroup {
                ZStack {
                    VStack(spacing: 10) {
                        if (errorInfo.isError) {
                            ErrorView(errorInfo: errorInfo)
                            
                        }
                        else {
                            if (openedURL.query == nil) {
                                //Spacer().frame(width: 0, height: 10)
                                ErrorView(errorInfo: ErrorInfo(title: "Package info missing. Please contact GHD",
                                                               msg: "Query not found",
                                                               active: true,
                                                               allowRetry: true))
                                    .frame(minWidth: 500, maxWidth: 500)
                                Spacer().frame(width: 0, height: 10)
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
    //                                params: UrlHandler(input: openedURL)
                                )
                            }
                        }
                    }
                    .fixedSize()
                    .onOpenURL { url in
                        openedURL = url;
                        //for prod
                        params = UrlHandler(input: url);
                        //to skip shellview, uncomment below
    //                    pkgInfo = UrlHandler(input: url);
                    }
                }
            }
            .windowResizability(.contentSize)
            .windowStyle(.hiddenTitleBar)
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
