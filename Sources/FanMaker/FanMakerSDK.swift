import Foundation
import SwiftUI

public let FanMakerSDKSessionToken : String = "FanMakerSDKSessionToken"
public let FanMakerSDKJSONIdentifiers : String = "FanMakerSDKJSONIdentifiers"

public class FanMakerSDK {
    public static var apiKey : String = ""
    public static var userID : String = ""
    public static var memberID : String = ""
    public static var studentID : String = ""
    public static var ticketmasterID : String = ""
    public static var yinzid : String = ""
    public static var pushToken : String = ""
    public static var locationEnabled : Bool = false
    public static var loadingBackgroundColor : UIColor = UIColor.white
    public static var loadingForegroundImage : UIImage? = nil
    
    public static func initialize(apiKey : String) {
        self.apiKey = apiKey
        self.locationEnabled = false
        
        let defaults : UserDefaults = UserDefaults.standard
        if defaults.string(forKey: FanMakerSDKSessionToken) != nil {
            if let json = defaults.string(forKey: FanMakerSDKJSONIdentifiers) {
                FanMakerSDK.setIdentifiers(fromJSON: json)
            }
        }
    }
    
    public static func isInitialized() -> Bool {
        return apiKey != ""
    }
    
    public static func setUserID(_ value : String) {
        self.userID = value
    }
    
    public static func setMemberID(_ value : String) {
        self.memberID = value
    }
    
    public static func setStudentID(_ value : String) {
        self.studentID = value
    }

    public static func setTicketmasterID(_ value : String) {
        self.ticketmasterID = value
    }
    
    public static func setYinzid(_ value : String) {
        self.yinzid = value
    }
    
    public static func setPushNotificationToken(_ value : String) {
        self.pushToken = value
    }
    
    public static func enableLocationTracking() {
        self.locationEnabled = true
    }
    
    public static func disableLocationTracking() {
        self.locationEnabled = false
    }
    
    public static func setLoadingBackgroundColor(_ bgColor : UIColor) {
        self.loadingBackgroundColor = bgColor
    }
    
    public static func setLoadingForegroundImage(_ fgImage : UIImage) {
        self.loadingForegroundImage = fgImage
    }
    
    public static func setIdentifiers(fromJSON json : String) {
        let data : Data? = json.data(using: .utf8)
        do {
            let identifiers = try JSONDecoder().decode(FanMakerSDKIdentifiers.self, from: data!)
            if identifiers.user_id != nil { FanMakerSDK.setUserID(identifiers.user_id!) }
            if identifiers.member_id != nil { FanMakerSDK.setMemberID(identifiers.member_id!) }
            if identifiers.student_id != nil { FanMakerSDK.setStudentID(identifiers.student_id!) }
            if identifiers.ticketmaster_id != nil { FanMakerSDK.setTicketmasterID(identifiers.ticketmaster_id!) }
            if identifiers.yinzid != nil { FanMakerSDK.setYinzid(identifiers.yinzid!) }
            if identifiers.push_token != nil { FanMakerSDK.setPushNotificationToken(identifiers.push_token!) }
        } catch { }
    }
}
