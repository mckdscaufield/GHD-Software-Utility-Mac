//
//  ContentView.swift
//  XCode-GHDSU
//
//  Created by Daniel Caufield on 01.03.2023.
//

import SwiftUI
import Cocoa

func InstallPolicyByID(id: String) async {
    let applescript = """
    do shell script \"sudo /usr/local/bin/jamf policy -id \(id)" with administrator privileges
    """
    runAppleScriptInBackground(script: applescript)
}

func runAppleScriptInBackground(script: String) {
    DispatchQueue.global(qos: .background).async {
        do {
            let appleScript = NSAppleScript(source: script)!
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            if error == nil {
                print(result.stringValue!)
            }
            else {
                print("AppleScript error: \(error!)")
            }
        }
    }
}

func GetProcessIDByName(name: String) -> String {
    let pipe = Pipe()
    let p = Process()
    p.launchPath = "/usr/bin/pgrep"
    p.arguments = ["-x", name]
    p.standardOutput = pipe
    p.launch()
    p.waitUntilExit()
    
    let outHandle = pipe.fileHandleForReading
    outHandle.waitForDataInBackgroundAndNotify()
    let data = outHandle.availableData
    
    return String(data: data, encoding: String.Encoding.utf8)!.trimmingCharacters(in: .whitespacesAndNewlines)
}

// Try three times with a 1 second delay between attempts
func MonitorJamfProcess() async -> String {
    for _ in 1...3 {
        try? await Task.sleep(seconds: 3)
        //Thread.sleep(forTimeInterval: 3)
        print(".", terminator: "")
        let pid = GetProcessIDByName(name: "jamf")
        if pid != "" {
            return pid
        }
    }
    return "none"
}

func CheckInstalledStatus(path: String) -> Bool {
    let filepath = NSString(string: "/Applications/" + path).expandingTildeInPath
    var isDirectory = ObjCBool(true)
    let exists = FileManager.default.fileExists(atPath: filepath, isDirectory: &isDirectory)
    return exists //&& isDirectory.boolValue
}

struct InstallView: View {
    @Binding var visibility: Bool
    @State var installationInProgress: Bool
    @State var params: Dictionary<String, String>
    @State var installed: Bool = false
    
    
    @ObservedObject var errorInfo = ErrorInfo()

    //colour pulse variables
    @State var colors: [Color] = [Color(NSColor.windowBackgroundColor), .mckBlue, .cyan, .green, .red, .orange, .yellow, Color(NSColor.windowBackgroundColor)]
//    @State var colors: [Color] = [Color(NSColor.underPageBackgroundColor), Color.mckBlue, Color.cyan, Color.white, Color(NSColor.underPageBackgroundColor)]
    @State var index: Int = 0
    @State var progress: CGFloat = 0
    @State var notify: Bool = false
    @State var opacity: Double = 1.0
    //end of colour pulse variables
    
    var body: some View {
        ZStack (alignment: .center) {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()
            
            if (notify) {
                SplashView(animationType: .circle, color: self.colors[self.index])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .ignoresSafeArea()
                    .shadow(color: Color.black.opacity(1), radius: 10, x: 0, y: 4)
                    .task {
                        for _ in 1...self.colors.count {
                            try? await Task.sleep(nanoseconds: 50_000_000)
                            self.index = (self.index + 1) % self.colors.count
                        }
                        
                        try? await Task.sleep(nanoseconds: 500_000_000) //let the final animation play out before hiding again
                        self.notify = false
                    }
            }

            VStack(alignment: .center, spacing: 10) {
                Spacer().frame(width: 0, height: 0)
                Text("Manage Software Installation").font(.system(size: 17)).bold().zIndex(2)
                Text(params["name"] ?? "<no_name>").font(.system(size:16)).zIndex(2)

                Spacer().frame(width: 15, height: 15);

                VStack(alignment: .leading, spacing: 15) {
                    
                    Button(action: {
                        if !installed {
                            self.installationInProgress = true;
                            let packid: String = params["id"]!
                            Task {
                                await InstallPolicyByID(id: packid);

                                print("Monitoring jamf process", terminator: "")
                                //get pid and wait for it to close

                                let pid = await MonitorJamfProcess()
                                while self.installationInProgress {
                                    self.installationInProgress = await MonitorJamfProcess() == pid
                                }
                                self.installed = CheckInstalledStatus(path: params["path"]!)
                                self.notify = true
                            }

                            // here is installed == false we can report an error in UI
                            print("")
                        }
                        else {
                           NSWorkspace.shared.openApplication(at:  URL(fileURLWithPath: "/Applications/" + params["path"]!), configuration: NSWorkspace.OpenConfiguration()) { (app, error) in
                               if let error = error {
                                   print("Failed to open \(params["path"]!): \(error.localizedDescription)")
                               } else {
                                   print("\(params["path"]!) successfully opened")
                               }
                           }
                        }
                    }) {
                        Text(installed ? "Launch" : "Install").font(.system(size:16))
                    }
                    .buttonStyle(McKButt())
                    .disabled(self.installationInProgress)
                }

                if (self.installationInProgress) {
                    ProgressView()
                        .progressViewStyle(LinearProgressViewStyle(tint: Color.mckBlue))
                }
                else {
                    Spacer().frame(width: 0, height: 18)
                }
            }
            .padding(.horizontal, 30)
            .padding(.vertical, 20)
            .frame(width: 500, alignment: .center)
        }
        .frame(alignment: .topLeading)
        .onAppear {
            self.installed = CheckInstalledStatus(path: params["path"]!)
        }
    }
}

struct InstallView_Previews: PreviewProvider {
    static var previews: some View {
        InstallView(visibility: .constant(true),
                    installationInProgress: true,
                    params: ["id": "GUID",
                           "path": "app.app",
                           "name": "[Product Name]",
                           "size": "12345",
                           "time": "[time in minutes]" ]
        )
    }
}
