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
//    var json: Data = Data()
    
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

    
//    AF.request(url, method: .get)
//        .authenticate(with: credential)
//        .validate(statusCode: 200..<300)
//        .responseDecodable(of: response.self) { response in
//            json = response.value!
//        }
    
    // Make the API call using Alamofire with client authentication
    AF.request(url, method: .get)
        .authenticate(with: credential)
        .validate(statusCode: 200..<300)
//            .validate(contentType: ["application/json"])
            .responseData { res in
                var d: Data = Data()
                switch res.result {
                case let .success(data):
//                    print(String(decoding: data, as: UTF8.self))
//                    json = data
                    d = data
//                    completion(res.response!.statusCode, data)
//                    json = parsed
                case let .failure(error):
                    print(error)
                }
                completion(res.response!.statusCode, d)
            }

//    return json
}

//func CallAPI(id: String, fmno: String) async -> Data {
//    let data: Data = await MacGarbageKeychain(id: id, fmno: fmno)!
//    print("\(String(describing: response))")
//    return data
//
//    let path = Bundle.main.bundlePath
//    let p = Process();
//    p.launchPath = path + "/Contents/Resources/GHDSUAPI/GHDSU_API_Handler_Console"
//    p.arguments = [id, fmno]
//
//    let pipe = Pipe();
//    let errPipe =  Pipe();
//    p.standardOutput = pipe
//    p.standardError = errPipe
//
//    do {
//        try p.run()
//
//        let errorHandle = errPipe.fileHandleForReading
//        errorHandle.waitForDataInBackgroundAndNotify()
//        let errorData = errorHandle.availableData
//
//        let outHandle = pipe.fileHandleForReading
//        outHandle.waitForDataInBackgroundAndNotify()
//        let data = outHandle.availableData
//
//        let output = String(decoding: data, as: UTF8.self)
//        let error = String(decoding: errorData, as: UTF8.self)
//
//        print("ERROR: \(error.utf8CString)")
//        print("OUTPUT: \(output)")
//        return Data(data)
//    }
//    catch {
//        print("CAUGHT ERROR")
//        return nil
//    }
    
//
//
//    //collect error, this includes API error codes
//    let errHandle = errPipe.fileHandleForReading
//    errHandle.waitForDataInBackgroundAndNotify()
//    let error = errHandle.availableData
//    let errorString: String = String(data: error, encoding: String.Encoding.utf8)!
//    print(errorString)
////
////    if (error.isEmpty) {
//        print("success?")
//        let outHandle = pipe.fileHandleForReading
//        outHandle.waitForDataInBackgroundAndNotify()
//        let data = outHandle.availableData
////        let jsonString: String = String(data: data, encoding: String.Encoding.utf8)!
////        print(jsonString)
//
//    p.launch()
//    p.waitUntilExit();
    
    
        
//    }
//    else {
//        print("failure")
//        //move error logging to an external file for troubleshooting
//        let errorString: String = String(data: error, encoding: String.Encoding.utf8)!
//        print(errorString)
//        return nil
//    }
//}

extension String {
    func toJSON() -> Any? {
        guard let data = self.data(using: .utf8, allowLossyConversion: false) else { return nil }
        return try? JSONSerialization.jsonObject(with: data, options: .mutableContainers)
    }
}

func parse(json: Data) -> response {
//    var parsed: response = response()
    
//    print("json string: \(json)")
//    if (!json.isEmpty) {
//        let dict = json.toJSON() as? response
//        return dict!
//    }
//
//    else { return response() }
    
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
            
            completion(code, ["id": parsed.software?.JamF.jamfID ?? "",
                "path": parsed.software?.detectionParameters[0].argument ?? "",
                "name": parsed.software?.name ?? "",
                "time": "5" ])
        }
        else {
            completion(code, [:])
        }
        
    }
    
//    let json = await CallAPI(id: id, fmno: fmno)
//
//    if (json != nil) {
//        print("JSON RETRIEVED")
//        let parsed = parse(json: json!)
//    }
//    else {
//        return [:]
//    }
//
//    print("JSON IS NIL")
//    return [:]
    
    
//    await MacGarbageKeychain(id: id, fmno: fmno) { response in
//        let parsed = parse(json: response)
//        return ["id": parsed.software?.JamF.jamfID ?? "",
//                "path": parsed.software?.detectionParameters[0].argument ?? "",
//                "name": parsed.software?.name ?? "",
//                "time": "5" ]
//    }
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
            Color(NSColor.underPageBackgroundColor).ignoresSafeArea()
            
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
//                                pkgInfo = await GetPackageInfo(id: params["catItemID"]!, fmno: params["fmno"]!)
                                await GetPackageInfo(id: cid, fmno: fmno) { code, data in
                                    if (code == 200) {
                                        pkgInfo = data
                                    }
                                    else {
                                        self.errorInfo.title = "Could not retrieve package info. Please contact GHD"
                                        self.errorInfo.message = "The API returned an error: \(code)"
                                        self.errorInfo.allowRetry = true
                                        self.errorInfo.isError = true
                                        inProgress = false
                                    }
                                }
                                
                                //if it still has no data (eg: API call resulted in non-200 status response)
//                                if (pkgInfo.index(forKey: "error") != nil) {
//
//                                }
                            }
                            else {
                                inProgress = false;
                            }
                        }
                }
                else {
                    Text("Package info missing. Please contact GHD")
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
                        Text("\(params["fmno"]!)")
                    }
                }
                
                
//
//                HStack {
//                    if (inProgress) { ProgressView() }
//                    else {
//                        VStack(spacing: 5) {
//                            Text("Package info missing. Please contact GHD")
//                                .font(.system(size: 20)).bold();
//                            //error image
//                            Image(systemName: "exclamationmark.octagon")
//                                .imageScale(.large)
//                                .font(.system(size: 42))
//                                .foregroundColor(Color(.systemRed))
//                            //error text
//                            Text("Error message:").font(.system(size: 12));
//                        }
//                    }
//                    Spacer().frame(width: 0, height: 50)
                    
                
//                    Button("Retrieve package info", action: {
//                        pkgInfo = GetPackageInfo(id: params["catItemID"]!, fmno: params["fmno"]!)
//                        });
//                }
                
            }
        }
        .padding(0)
        .frame(minWidth: 500, maxWidth: 500)
        .frame(minHeight: 200, maxHeight: 200)
    }
    
    func validate(data: Dictionary<String, String>) async -> Bool {
        //we need to make sure we have the following information:
        //1. catItemID != nil
        //2. fmno != nil
//        try? await Task.sleep(seconds: 2)
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
