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
    private var locationCompletions: [(Result<[String: Double], Error>) -> Void] = []

    override init() {
        self.lat = 0
        self.lng = 0
    }

    func checkAuthorizationAndRequestLocation(_ manager: CLLocationManager, completion: @escaping (Result<[String: Double], Error>) -> Void) {
        var authorizationStatus: CLAuthorizationStatus
        if #available(iOS 14.0, *) {
            authorizationStatus = manager.authorizationStatus
        } else {
            authorizationStatus = CLLocationManager.authorizationStatus()
        }

        switch authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            // Store the completion handler in the list
            locationCompletions.append(completion)
            // Request a fresh location update
            manager.requestLocation()
        case .denied, .restricted, .notDetermined:
            // Call the completion with an error directly since location access is not allowed
            completion(.failure(NSError(domain: "LocationAccessDenied", code: 1, userInfo: [NSLocalizedDescriptionKey: "Location access denied or restricted."])))
        @unknown default:
            completion(.failure(NSError(domain: "LocationAccessUnknown", code: 2, userInfo: [NSLocalizedDescriptionKey: "Unknown authorization status."])))
        }
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            // If no valid location, return an error to all stored completions
            completeAll(with: .failure(NSError(domain: "NoLocation", code: 3, userInfo: [NSLocalizedDescriptionKey: "No valid location received."])))
            return
        }

        let lat = location.coordinate.latitude
        let lng = location.coordinate.longitude
        let coordinates = ["lat": lat, "lng": lng]

        // Complete all stored completion handlers with the successful location data
        completeAll(with: .success(coordinates))
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Complete all stored completion handlers with the error
        NSLog("FanMaker Location update failed with error: \(error)")
        completeAll(with: .failure(error))
    }

    private func completeAll(with result: Result<[String: Double], Error>) {
        // Iterate through all completion handlers and call them with the result
        locationCompletions.forEach { $0(result) }
        // Clear the list of completion handlers after invoking them
        locationCompletions.removeAll()
    }

    public func coords() -> String {
        return "{\"lat\":\(self.lat), \"lng\":\(self.lng)}"
    }
}
