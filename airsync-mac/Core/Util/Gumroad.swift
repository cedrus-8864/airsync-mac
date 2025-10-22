//
//  Gumroad.swift
//  airsync-mac
//
//  Created by Sameera Sandakelum on 2025-07-31.
//

import Foundation
import AppKit

// New: error type to distinguish network/server failures from invalid license results
enum LicenseCheckError: Error {
    case network(Error)           // Transport / connectivity issues (timeouts, offline, DNS, etc.)
    case server(String)           // Non-OK HTTP or malformed responses
}

class Gumroad {
    let appState = AppState.shared

    func checkLicenseKeyValidity(key: String, save: Bool, isNewRegistration: Bool) async throws -> Bool {
        // Disable License Check - only for personal builds
        AppState.shared.isPlus = true

        return true
    }

    func clearLicenseDetails() {
        AppState.shared.licenseDetails = nil
        UserDefaults.standard.removeObject(forKey: "licenseDetailsKey")
        UserDefaults.standard.consecutiveLicenseFailCount = 0
    }

    func incrementInvalidLicenseFailCount() {
        let failCount = UserDefaults.standard.consecutiveLicenseFailCount + 1
        UserDefaults.standard.consecutiveLicenseFailCount = failCount

        if failCount >= 3 {
            Gumroad().clearLicenseDetails()
            print("[gumroad] License check failed \(failCount) times — license removed")
        }
    }

    func performUnregisterWithAlert(reason: String) {
        // Clear local license and disable Plus
        appState.isPlus = false
        Gumroad().clearLicenseDetails()
        UserDefaults.standard.consecutiveNetworkFailureDays = 0
        UserDefaults.standard.set(nil, forKey: "lastNetworkFailureDay")

        // Inform user with a blocking popup
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.messageText = "AirSync+ Unregistered"
            alert.informativeText = reason
            alert.runModal()
        }
    }

    @MainActor
    func checkLicense() async {
        // Disable License Check - only for personal builds
        AppState.shared.isPlus = true
        UserDefaults.standard.lastLicenseCheckDate = Date()
        UserDefaults.standard.lastLicenseSuccessfulCheckDate = Date()
        UserDefaults.standard.consecutiveNetworkFailureDays = 0
        UserDefaults.standard.consecutiveLicenseFailCount = 0
    }


    func checkLicenseIfNeeded() async {
        // If we already had a successful check today, skip to enforce "max one successful check per day"
        if let lastSuccess = UserDefaults.standard.lastLicenseSuccessfulCheckDate,
           Calendar.current.isDateInToday(lastSuccess) {
            print("[gumroad] License already successfully validated today — skipping network call.")
            return
        }

        await Gumroad().checkLicense()
    }

}
