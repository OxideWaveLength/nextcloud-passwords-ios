import SwiftUI
import StoreKit


struct MainView: View {
    
    @EnvironmentObject private var autoFillController: AutoFillController
    
    @StateObject private var authenticationChallengeController = AuthenticationChallengeController.default
    @StateObject private var biometricAuthenticationController = Configuration.isTestEnvironment ? BiometricAuthenticationController.mock : BiometricAuthenticationController()
    @StateObject private var credentialsController = Configuration.isTestEnvironment ? CredentialsController.mock : CredentialsController.default
    @StateObject private var tipController = Configuration.isTestEnvironment ? TipController.mock : TipController()
    
    // MARK: Views
    
    var body: some View {
        EntriesNavigation()
            .onChange(of: tipController.transactionState, perform: didChange)
            .onChange(of: authenticationChallengeController.certificateConfirmationRequests, perform: didChange)
            .copyToast()
            .environmentObject(autoFillController)
            .environmentObject(biometricAuthenticationController)
            .environmentObject(credentialsController)
            .environmentObject(tipController)
            .onAppear {
                biometricAuthenticationController.autoFillController = autoFillController
            }
    }
    
    // MARK: Functions
    
    private func didChange(transactionState: SKPaymentTransactionState?) {
        guard let transactionState = transactionState else {
            return
        }
        switch transactionState {
        case .deferred:
            UIAlertController.presentGlobalAlert(title: "_tipDeferred".localized, message: "_tipDeferredMessage".localized) {
                tipController.transactionState = nil
            }
        case .purchased, .restored:
            UIAlertController.presentGlobalAlert(title: "_tipReceived".localized, message: "_tipReceivedMessage".localized, dismissText: "_highFive".localized) {
                tipController.transactionState = nil
            }
        case .failed:
            UIAlertController.presentGlobalAlert(title: "_tipFailed".localized, message: "_tipFailedMessage".localized) {
                tipController.transactionState = nil
            }
        case .purchasing:
            return
        @unknown default:
            return
        }
    }
    
    private func didChange(certificateConfirmationRequests: [AuthenticationChallengeController.CertificateConfirmationRequest]) {
        guard let certificateConfirmationRequest = certificateConfirmationRequests.first else {
            return
        }
        UIAlertController.presentGlobalAlert(title: "_invalidCertificate".localized, message: String(format: "_invalidCertificateMessage(hash)".localized, certificateConfirmationRequest.hash), dismissText: "_reject".localized, dismissHandler: {
            authenticationChallengeController.deny(certificateHash: certificateConfirmationRequest.hash)
        }, confirmText: "_accept".localized, confirmHandler: {
            authenticationChallengeController.accept(certificateHash: certificateConfirmationRequest.hash)
        }, destructive: true)
    }
    
}
