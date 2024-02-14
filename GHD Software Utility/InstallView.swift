//
//  ContentView.swift
//  XCode-GHDSU
//
//  Created by Daniel Caufield on 01.03.2023.
//

import SwiftUI
import Cocoa

func InstallPolicyByID(id: String, completion: @escaping(Int) async -> ()) async {
    let applescript = """
    do shell script \"sudo /usr/local/bin/jamf policy -id \(id)" with administrator privileges
    """
    await runAppleScriptInBackground(script: applescript) { excode in
        await completion(excode)
    }
}

func runAppleScriptInBackground(script: String, completion: @escaping (Int) async -> ()) async {
    DispatchQueue.global(qos: .background).async {
        Task {
            let appleScript = NSAppleScript(source: script)!
            var error: NSDictionary?
            let result = appleScript.executeAndReturnError(&error)
            if error == nil {
                Logger.log(result.stringValue!)
                await completion(0)
            }
            else {
                Logger.log("AppleScript error: \(error!)")
                await completion(1)
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

func LaunchAppByLiquitID(id: String) async {
    let shellAPI = "/Applications/Liquit.app/Contents/MacOS/ShellAPI"
    let pipe = Pipe()
    let p = Process()
    p.launchPath = shellAPI
    p.arguments = ["--launch", id]
    p.standardOutput = pipe
    p.launch()
    p.waitUntilExit()
    
//    let outHandle = pipe.fileHandleForReading
//    outHandle.waitForDataInBackgroundAndNotify()
//    let data = outHandle.availableData
}

extension String {
    var isNumber: Bool {
        return self.range(
            of: "^[0-9]*$", // 1
            options: .regularExpression) != nil
    }
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
                            
                            //if liquit id exists and liquid shellapi is installed
                            if params["liquit"] != "" && FileManager.default.fileExists(atPath: "/Applications/Liquit.app/Contents/MacOS/ShellAPI") {
                                let lid = params["liquit"]!
                                Task {
                                    Logger.log("Passing installation task to Liquid agent")
                                    Logger.log("Liquit ID: \(lid)")
                                    await LaunchAppByLiquitID(id: lid)
                                    
                                    self.installed = CheckInstalledStatus(path: params["path"]!)
                                    self.notify = true //make the prettiness happen
                                    self.installationInProgress = false;
                                    Logger.log("Liquit ShellAPI process closed. Installation complete.")
                                    Logger.log("Installed: \(installed)")
                                }
                            }
                            else {
                                let packid: String = params["id"]!
                                Task {
                                    Logger.log("Monitoring jamf policy: \(packid)")
                                    await InstallPolicyByID(id: packid) { result in
                                        if result != 0 {
                                            self.installationInProgress = false
                                        }
                                        else {
    //                                        pid = GetProcessIDByName(name: "jamf")
    //                                        let pid = await MonitorJamfProcess()
                                            
    //                                        Logger.log("Process ID: \(pid)")
                                            
    //                                        while self.installationInProgress {
    //                                            self.installationInProgress = await MonitorJamfProcess() == pid
    //                                        }
                                            self.installed = CheckInstalledStatus(path: params["path"]!)
                                            self.notify = true
                                        
            //                                    if (pid != "none") {
            //                                        while self.installationInProgress {
            //                                            self.installationInProgress = await MonitorJamfProcess() == pid
            //                                        }
            //                                        self.installed = CheckInstalledStatus(path: params["path"]!)
            //                                        self.notify = true
            //                                    }
                                            
                                            // here is installed == false we can report an error in UI
                                            self.installationInProgress = false;
                                            Logger.log("Jamf process closed. Installation complete.")
                                            Logger.log("Installed: \(installed)")
                                        }
                                    }
                                }
                            }
                        }
                        else {
                            //if liquit id exists and liquid shellapi is installed
                            if params["liquit"] != "" && FileManager.default.fileExists(atPath: "/Applications/Liquit.app/Contents/MacOS/ShellAPI") {
                                Task {
                                    let lid = params["liquit"]!
                                    await LaunchAppByLiquitID(id: lid)
                                }
                            }
                            
                            NSWorkspace.shared.openApplication(at:  URL(fileURLWithPath: "/Applications/" + params["path"]!), configuration: NSWorkspace.OpenConfiguration()) { (app, error) in
                                if let error = error {
                                    Logger.log("Failed to open \(params["path"]!): \(error.localizedDescription)")
                                }
                                else {
                                    Logger.log("\(params["path"]!) successfully opened")
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
