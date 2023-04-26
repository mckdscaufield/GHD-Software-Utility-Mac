//
//  ShellView.swift
//  XCode-GHDSU
//
//  Created by Daniel Caufield on 02.03.2023.
//

import SwiftUI
import Combine
import Security
import Foundation
import Alamofire

func CallAPI(id: String, fmno: String, completion: @escaping(Int, Data?) -> Void) async {
    let commonName = "API Management"
    let url = "https://mdt-api.mck-wit.net/MDT-API-DEV/deployment/getinstallationdetails/mdt-snow-software?catItemID=\(id)&os=macOS&fmno=\(fmno)"
    
    // Retrieve the certificate from the keychain based on its common name
    let query: [CFString: Any] = [
        kSecClass: kSecClassCertificate,
        kSecReturnRef: true,
        kSecMatchLimit: kSecMatchLimitOne,
        kSecAttrLabel: commonName
    ]
    
    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)
    
    guard status == noErr, let certificate = result else {
        print("Error retrieving certificate from keychain: \(status)")
        return
    }

    // Retrieve the identity from the keychain based on the certificate
    var identity: SecIdentity?
    let identityStatus = SecIdentityCreateWithCertificate(nil, certificate as! SecCertificate, &identity)

    guard identityStatus == noErr, let unwrappedIdentity = identity else {
        print("Error retrieving identity from keychain: \(identityStatus)")
        return
    }

    // Create a URL credential from the identity and certificate
    let credential = URLCredential(identity: unwrappedIdentity, certificates: [certificate], persistence: .none)
    
    // Make the API call using Alamofire with client authentication
    AF.request(url, method: .get)
        .authenticate(with: credential)
        .validate(statusCode: 200..<300)
            .responseData { res in
                var d: Data = Data()
                switch res.result {
                case let .success(data):
                    d = data
                case let .failure(error):
                    print(error)
                }
                completion(res.response!.statusCode, d)
            }
}
extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}

func parse(json: Data) -> response {
    var parsed: response = response() // initialize with nil
    let decoder = JSONDecoder()
    if let jsonresponse = try? decoder.decode(response.self, from: json) {
        parsed = jsonresponse
    }
    return parsed
}

func GetPackageInfo(id: String, fmno: String, completion: @escaping((Int, Dictionary<String, String>) -> Void)) async {
    var parsed: response = response()
    await CallAPI(id: id, fmno: fmno) { code, response in
        if (code == 200) {
            parsed = parse(json: response!)
            //to avoid index errors where detection params are missing, just put something in
            if (parsed.software?.detectionParameters.count == 0) {
                parsed.software!.detectionParameters = [detectionParameters(type: "FileExists", argument: "\(parsed.software!.name).app")]
            }
            completion(code, ["id": parsed.software?.JamF.jamfID ?? "",
                              "path": parsed.software?.detectionParameters[0].argument ?? "",
                              "name": parsed.software?.name ?? "",
                              "time": "5" ])
        }
        else {
            completion(code, [:])
        }
    }
}

struct ShellView: View {
    @Binding var installed: Bool
    @Binding var pkgInfo: Dictionary<String, String>
    @State var params: Dictionary<String, String>
    @State private var jsonResponse: response?
    @State private var cancellable: AnyCancellable?
    
    @State var inProgress: Bool = true
    @State var statusText: String = "Fetching package info"
    
    @ObservedObject var errorInfo = ErrorInfo()
    
    var body: some View {
        ZStack {
            Color(NSColor.windowBackgroundColor).ignoresSafeArea()
            
            VStack(spacing: 10) {
                if (inProgress) {
                    ProgressView()
                    Spacer().frame(width: 0, height: 20)
                    
                    Text(statusText)
                        .task {
                            //validate input
                            if (await validate(data: params)) {
                                let cid: String = params["sys_id"]!
                                let fmno: String = params["fmno"]!
                                //try api
                                //catch display error details, maybe "try again" button
                                await GetPackageInfo(id: cid, fmno: fmno) { code, data in
                                    if (code == 200) {
                                        pkgInfo = data
                                    }
                                    else {
                                        self.errorInfo.title = "Could not retrieve package info. \nPlease contact GHD"
                                        self.errorInfo.message = "The API returned an error: \(code)"
                                        self.errorInfo.isError = true
                                        inProgress = false
                                    }
                                }
                            }
                            else {
                                inProgress = false;
                            }
                        }
                }
                else {
                    Spacer().frame(width: 0, height: 0) //this is needed to fix bugs with swfit layout and rendering don't ask why
                    ErrorView(errorInfo: errorInfo)
                        .task {
                            if (errorInfo.message.isEmpty) {
                                self.errorInfo.message = "sys_id or fmno values are missing."
                            }
                        }
                    .frame(minWidth: 500, maxWidth: 500)
                    Spacer().frame(width: 0, height: 20)
                }
            }
        }
        .padding(0)
        .frame(minWidth: 500, maxWidth: 500)
        .frame(minHeight: 200, maxHeight: 500)
    }
    
    func validate(data: Dictionary<String, String>) async -> Bool {
        //we need to make sure we have the following information:
        //1. catItemID != nil
        //2. fmno != nil
        if (data["sys_id"] == nil || data["fmno"] == nil) {
            self.errorInfo.message = "FMNO or ItemID missing."
            self.errorInfo.isError = true
            return false
        }
        else { return true }
    }
}

struct ShellView_Previews: PreviewProvider {
    static var previews: some View {
        ShellView(installed: .constant(false),
                  pkgInfo: .constant([:]),
                  params: [:])
    }
}

// JSON structure
struct response: Decodable {
    var software: software?
    
    init(software: software? = nil) {
        self.software = software
    }
}

struct software: Decodable {
    var currentlyEntitled: Bool
    var name: String
    var url: String
    var JamF: Jamf
    var detectionParameters: [detectionParameters]
}

struct Jamf: Decodable {
    var jamfID: String
}

struct detectionParameters: Decodable {
    var type: String
    var argument: String
}
