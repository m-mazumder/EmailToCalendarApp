//
//  OutlookService.swift
//  EmailToCalendarApp2
//
//  Created by Madhumita Mazumder on 11/4/17.
//  Copyright © 2017 Madhumita Mazumder. All rights reserved.
//

import Foundation
import p2_OAuth2
import SwiftyJSON


class OutlookService {
    
    private var userEmail: String
    
    // Configure the OAuth2 framework for Azure
    private static let oauth2Settings = [
        "client_id" : "f31b7d54-6c60-4e33-887c-066f0a835368",
        "authorize_uri": "https://login.microsoftonline.com/common/oauth2/v2.0/authorize",
        "token_uri": "https://login.microsoftonline.com/common/oauth2/v2.0/token",
        "scope": "openid profile offline_access User.Read Mail.Read",
        "redirect_uris": ["EmailToCalendarApp2://oauth2/callback"],
        "verbose": true,
        ] as OAuth2JSON
    
    private static var sharedService: OutlookService = {
        let service = OutlookService()
        return service
    }()
    
    private let oauth2: OAuth2CodeGrant
    
    var newAppTitle:[String]
    var newAppDate:[Date]
    var newAppNotes:[String]
    
    
    private init() {
        oauth2 = OAuth2CodeGrant(settings: OutlookService.oauth2Settings)
        oauth2.authConfig.authorizeEmbedded = true
        userEmail = ""
        newAppTitle = []
        newAppDate = []
        newAppNotes = []

    }
    
    class func shared() -> OutlookService {
        return sharedService
    }
    
    var isLoggedIn: Bool {
        get {
            return oauth2.hasUnexpiredAccessToken() || oauth2.refreshToken != nil
        }
    }
    
    func handleOAuthCallback(url: URL) -> Void {
        print(url)
        oauth2.handleRedirectURL(url)
    }
    
    func login(from: AnyObject, callback: @escaping (String? ) -> Void) -> Void {
        oauth2.authorizeEmbedded(from: from) {
            result, error in
            if let unwrappedError = error {
                print("error1")
                callback(unwrappedError.description)
            } else {
                if let unwrappedResult = result, let token = unwrappedResult["access_token"] as? String {
                    // Print the access token to debug log
                    NSLog("Access token: \(token)")
                    callback(nil)
                }
            }
        }
    }
    
    func logout() -> Void {
        oauth2.forgetTokens()
    }
    
    func makeApiCall(api: String, params: [String: String]? = nil, callback: @escaping (JSON?) -> Void) -> Void {
        // Build the request URL
        var urlBuilder = URLComponents(string: "https://graph.microsoft.com")!
        urlBuilder.path = api
        
        if let unwrappedParams = params {
            // Add query parameters to URL
            urlBuilder.queryItems = [URLQueryItem]()
            for (paramName, paramValue) in unwrappedParams {
                urlBuilder.queryItems?.append(
                    URLQueryItem(name: paramName, value: paramValue))
            }
        }
        
        let apiUrl = urlBuilder.url!
        NSLog("Making request to \(apiUrl)")
        
        var req = oauth2.request(forURL: apiUrl)
        req.addValue("application/json", forHTTPHeaderField: "Accept")
        if (!userEmail.isEmpty) {
            req.addValue(userEmail, forHTTPHeaderField: "X-AnchorMailbox")
        }
        
        let loader = OAuth2DataLoader(oauth2: oauth2)
        
        loader.perform(request: req) {
            response in
            do {
                let dict = try response.responseJSON()
                DispatchQueue.main.async {
                    let result = JSON(dict)
                    callback(result)
                }
            }
            catch let error {
                DispatchQueue.main.async {
                    let result = JSON(error)
                    callback(result)
                }
            }
        }
    }
    
    func getUserEmail(callback: @escaping (String?) -> Void) -> Void {
        if (userEmail.isEmpty) {
            makeApiCall(api: "/v1.0/me") {
                result in
                if let unwrappedResult = result {
                    let email = unwrappedResult["mail"].stringValue
                    self.userEmail = email
                    callback(email)
                } else {
                    callback(nil)
                }
            }
        } else {
            callback(userEmail)
        }
    }
    
    func getInboxMessages(callback: @escaping (JSON?) -> Void) -> Void {
        let apiParams = [
            "$select": "subject,from,body", //only show subject and person it's from
            "$orderby": "receivedDateTime DESC",
            "$top": "15"
        ]
        
        makeApiCall(api: "/v1.0/me/mailfolders/inbox/messages", params: apiParams) {
            result in
            callback(result)
        }
    }
    
    func extractFromMessage(subject:String, from:String, content:String ) -> Void{
        var splitString:[String] = content.components(separatedBy: "\n\n")
        var splitContent:[String] = splitString[1].components(separatedBy: " ")
        var containsDate:Bool = false
        
        //double string checking
        if(splitContent.count > 1 && containsDate == false){
            for k in 0..<(splitContent.count - 1){
                //string of two
                let s:String = splitContent[k] + " " + splitContent[k + 1]
                
                // check if format is MM-dd-yyyy HH:mm
                let dateFormatter3 = DateFormatter()
                dateFormatter3.dateFormat = "MM-dd-yyyy HH:mm"
                let d3 = dateFormatter3.date(from: s)
                if(d3 != nil){
                    newAppTitle.append(subject)
                    newAppDate.append(d3!)
                    newAppNotes.append(from)
                    containsDate = true
                }
            }
        }
        if(splitContent.count > 2 && containsDate == false){
            for k in 0..<(splitContent.count - 2){
                //string of three
                let s:String = splitContent[k] + " " + splitContent[k + 1] + " " + splitContent[k + 2]
                
                // check if format is MM-dd-yyyy HH:mm
                let dateFormatter4 = DateFormatter()
                dateFormatter4.dateFormat = "MM d, yyyy"
                let d4 = dateFormatter4.date(from: s)
                if(d4 != nil){
                    newAppTitle.append(subject)
                    newAppDate.append(d4!)
                    newAppNotes.append(from)
                    containsDate = true
                }
            }
        }
        
        //penta string content
        if(splitContent.count > 4 && containsDate == false){
            for k in 0..<(splitContent.count - 4){
                //string of three
                let s:String = splitContent[k] + " " + splitContent[k + 1] + " " + splitContent[k + 2] + " " + splitContent[k + 3] + " " + splitContent[k + 4]
                
                // check if format is MM-dd-yyyy HH:mm
                let dateFormatter4 = DateFormatter()
                dateFormatter4.dateFormat = "MMM d, yyyy h:mm a"
                let d4 = dateFormatter4.date(from: s)
                if(d4 != nil && containsDate == false){
                    newAppTitle.append(subject)
                    newAppDate.append(d4!)
                    newAppNotes.append(from)
                    containsDate = true
                }
            }
        }
        
        //single string check
        if(containsDate == false){
            for i in 0..<(splitContent.count){
                // check if mm/dd/yyyy
                let dateFormatter = DateFormatter()
                dateFormatter.dateFormat = "MM/dd/yyyy"
                let d = dateFormatter.date(from: splitContent[i])
                if(d != nil && containsDate == false){
                    newAppTitle.append(subject)
                    newAppDate.append(d!)
                    newAppNotes.append(from)
                    containsDate = true
                }
                
                // check if mm.dd.yy
                let dateFormatter2 = DateFormatter()
                dateFormatter2.dateFormat = "dd.MM.yyyy"
                let d2 = dateFormatter.date(from: splitContent[i])
                if(d2 != nil && containsDate == false){
                    newAppTitle.append(subject)
                    newAppDate.append(d2!)
                    newAppNotes.append(from)
                    containsDate = true
                }
                
                // check if mm-dd-yy
                let dateFormatter8 = DateFormatter()
                dateFormatter8.dateFormat = "dd-MM-yyyy"
                let d8 = dateFormatter.date(from: splitContent[i])
                if(d8 != nil && containsDate == false){
                    newAppTitle.append(subject)
                    newAppDate.append(d8!)
                    newAppNotes.append(from)
                    containsDate = true

                }
            }
        }
    }
        
    
    func checkMail() -> Void {
        /**
        self.getUserEmail() {
            email in
            if let unwrappedEmail = email {
                NSLog("Hello \(unwrappedEmail)")
                
                self.getInboxMessages() {
                    messages in
                    if let unwrappedMessages = messages {
                        for (message) in unwrappedMessages["value"].arrayValue {
                            self.extractFromMessage(subject: message["subject"].stringValue, from: message["from"]["emailAddress"]["address"].stringValue, content: message["body"]["content"].stringValue)
                        }
                    }
                }
            }
        }
        **/
    }
    
    func getAppTitles() -> Array<String> {
        return newAppTitle
    }
    
    func getAppDates() -> Array<Date> {
        return newAppDate
    }
    
    func getAppNotes() -> Array<String> {
        return newAppNotes
    }
    
    func clearAll() -> Void {
        newAppTitle.removeAll()
        newAppDate.removeAll()
        newAppNotes.removeAll()
    }
    
}

