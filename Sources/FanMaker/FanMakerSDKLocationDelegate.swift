//
//  File.swift
//
//
//  Created by Érik Escobedo on 31/05/21.
//

import Foundation
import CoreLocation

class FanMakerSDKLocationDelegate : NSObject, CLLocationManagerDelegate {
    public var lat : CLLocationDegrees
    public var lng : CLLocationDegrees

    override init() {
        self.lat = 0
        self.lng = 0
    }

    func checkAuthorizationAndReturnCoordinates(_ manager: CLLocationManager) -> Any {
        var authorizationStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            authorizationStatus = manager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if let location = manager.location {
                let lat = location.coordinate.latitude
                let lng = location.coordinate.longitude
                return ["lat": lat, "lng": lng]
            } else {
                return false
            }
        case .denied, .restricted:
            return false
        case .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.first {
            self.lat = location.coordinate.latitude
            self.lng = location.coordinate.longitude
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print(error)
    }

    public func coords() -> String {
        return "{\"lat\":\(self.lat), \"lng\":\(self.lng)}"
    }
}
