//
//  FanMakerSDKBeaconsManagerDelegate.swift
//  Turducken
//
//  Created by Érik Escobedo on 09/06/22.
//

import Foundation

public enum FanMakerSDKBeaconsError {
    case userSessionNotFound
    case serverError
    case unknown
}

public protocol FanMakerSDKBeaconsManagerDelegate : NSObjectProtocol {
    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didChangeAuthorization status: FanMakerSDKBeaconsAuthorizationStatus) -> Void

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didReceiveBeaconRegions regions: [FanMakerSDKBeaconRegion]) -> Void

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didEnterRegion region: FanMakerSDKBeaconRegion) -> Void

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didExitRegion region: FanMakerSDKBeaconRegion) -> Void

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsHistory queue: [FanMakerSDKBeaconRangeAction]) -> Void

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didUpdateBeaconRangeActionsSendList queue: [FanMakerSDKBeaconRangeAction]) -> Void

    func beaconsManager(_ manager: FanMakerSDKBeaconsManager, didFailWithError error: FanMakerSDKBeaconsError) -> Void
}
