import AuthenticationServices
import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate,
  ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding
{
  private var passkeyResult: FlutterResult?
  private var notificationResult: FlutterResult?
  private var apnsToken: String?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    UNUserNotificationCenter.current().delegate = self
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
    guard
      let registrar = engineBridge.pluginRegistry.registrar(
        forPlugin: "AlongNativeBridge"
      )
    else { return }

    FlutterMethodChannel(
      name: "com.joshspicer.along/passkeys",
      binaryMessenger: registrar.messenger()
    ).setMethodCallHandler { [weak self] call, result in
      self?.handlePasskey(call: call, result: result)
    }
    FlutterMethodChannel(
      name: "com.joshspicer.along/notifications",
      binaryMessenger: registrar.messenger()
    ).setMethodCallHandler { [weak self] call, result in
      self?.handleNotifications(call: call, result: result)
    }
  }

  private func handlePasskey(call: FlutterMethodCall, result: @escaping FlutterResult) {
    guard passkeyResult == nil else {
      result(
        FlutterError(
          code: "in_progress",
          message: "Another passkey request is already open.",
          details: nil
        )
      )
      return
    }
    guard
      let arguments = call.arguments as? [String: Any],
      let requestJSON = arguments["requestJson"] as? String,
      let data = requestJSON.data(using: .utf8),
      let options = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
      let challengeText = options["challenge"] as? String,
      let challenge = Data(base64URLEncoded: challengeText),
      let rp = options["rp"] as? [String: Any],
      let relyingPartyID = rp["id"] as? String
    else {
      result(
        FlutterError(
          code: "invalid_request",
          message: "The server passkey request was invalid.",
          details: nil
        )
      )
      return
    }

    let provider = ASAuthorizationPlatformPublicKeyCredentialProvider(
      relyingPartyIdentifier: relyingPartyID
    )
    let request: ASAuthorizationRequest
    switch call.method {
    case "register":
      guard
        let user = options["user"] as? [String: Any],
        let userIDText = user["id"] as? String,
        let userID = Data(base64URLEncoded: userIDText),
        let name = user["name"] as? String
      else {
        result(
          FlutterError(
            code: "invalid_request",
            message: "The server registration request was invalid.",
            details: nil
          )
        )
        return
      }
      let registration = provider.createCredentialRegistrationRequest(
        challenge: challenge,
        name: name,
        userID: userID
      )
      registration.userVerificationPreference = .required
      request = registration
    case "authenticate":
      let assertion = provider.createCredentialAssertionRequest(challenge: challenge)
      assertion.userVerificationPreference = .required
      if let allowed = options["allowCredentials"] as? [[String: Any]] {
        assertion.allowedCredentials = allowed.compactMap { descriptor in
          guard
            let encoded = descriptor["id"] as? String,
            let id = Data(base64URLEncoded: encoded)
          else { return nil }
          return ASAuthorizationPlatformPublicKeyCredentialDescriptor(
            credentialID: id
          )
        }
      }
      request = assertion
    default:
      result(FlutterMethodNotImplemented)
      return
    }

    passkeyResult = result
    let controller = ASAuthorizationController(authorizationRequests: [request])
    controller.delegate = self
    controller.presentationContextProvider = self
    controller.performRequests()
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithAuthorization authorization: ASAuthorization
  ) {
    let response: [String: Any]
    if let credential =
      authorization.credential
        as? ASAuthorizationPlatformPublicKeyCredentialRegistration
    {
      response = [
        "id": credential.credentialID.base64URLEncodedString(),
        "rawId": credential.credentialID.base64URLEncodedString(),
        "type": "public-key",
        "response": [
          "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
          "attestationObject": credential.rawAttestationObject?
            .base64URLEncodedString() ?? "",
          "transports": ["internal"],
        ],
        "clientExtensionResults": [:],
      ]
    } else if let credential =
      authorization.credential
        as? ASAuthorizationPlatformPublicKeyCredentialAssertion
    {
      response = [
        "id": credential.credentialID.base64URLEncodedString(),
        "rawId": credential.credentialID.base64URLEncodedString(),
        "type": "public-key",
        "response": [
          "clientDataJSON": credential.rawClientDataJSON.base64URLEncodedString(),
          "authenticatorData": credential.rawAuthenticatorData
            .base64URLEncodedString(),
          "signature": credential.signature.base64URLEncodedString(),
          "userHandle": credential.userID.base64URLEncodedString(),
        ],
        "clientExtensionResults": [:],
      ]
    } else {
      finishPasskey(
        error: FlutterError(
          code: "unsupported_credential",
          message: "The device returned an unsupported credential.",
          details: nil
        )
      )
      return
    }

    do {
      let data = try JSONSerialization.data(withJSONObject: response)
      finishPasskey(value: String(decoding: data, as: UTF8.self))
    } catch {
      finishPasskey(
        error: FlutterError(
          code: "encoding_failed",
          message: "The passkey response could not be encoded.",
          details: nil
        )
      )
    }
  }

  func authorizationController(
    controller: ASAuthorizationController,
    didCompleteWithError error: Error
  ) {
    let authorizationError = error as? ASAuthorizationError
    finishPasskey(
      error: FlutterError(
        code: authorizationError?.code == .canceled ? "cancelled" : "passkey_failed",
        message: authorizationError?.code == .canceled
          ? "Passkey setup was cancelled."
          : "The passkey could not be verified.",
        details: nil
      )
    )
  }

  func presentationAnchor(
    for controller: ASAuthorizationController
  ) -> ASPresentationAnchor {
    let scenes = UIApplication.shared.connectedScenes.compactMap {
      $0 as? UIWindowScene
    }
    return scenes
      .flatMap(\.windows)
      .first(where: \.isKeyWindow) ?? ASPresentationAnchor()
  }

  private func finishPasskey(value: String? = nil, error: FlutterError? = nil) {
    let result = passkeyResult
    passkeyResult = nil
    if let error {
      result?(error)
    } else {
      result?(value)
    }
  }

  private func handleNotifications(
    call: FlutterMethodCall,
    result: @escaping FlutterResult
  ) {
    guard call.method == "request" else {
      result(FlutterMethodNotImplemented)
      return
    }
    guard notificationResult == nil else {
      result(
        FlutterError(
          code: "in_progress",
          message: "Notification permission is already being requested.",
          details: nil
        )
      )
      return
    }
    notificationResult = result
    UNUserNotificationCenter.current().requestAuthorization(
      options: [.alert, .badge, .sound]
    ) { [weak self] granted, error in
      DispatchQueue.main.async {
        guard let self else { return }
        if let error {
          self.finishNotifications(
            error: FlutterError(
              code: "permission_failed",
              message: error.localizedDescription,
              details: nil
            )
          )
        } else if granted {
          if let token = self.apnsToken {
            self.finishNotifications(granted: true, token: token)
          } else {
            UIApplication.shared.registerForRemoteNotifications()
          }
        } else {
          self.finishNotifications(granted: false)
        }
      }
    }
  }

  override func application(
    _ application: UIApplication,
    didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
  ) {
    apnsToken = deviceToken.map { String(format: "%02x", $0) }.joined()
    finishNotifications(granted: true, token: apnsToken)
  }

  override func application(
    _ application: UIApplication,
    didFailToRegisterForRemoteNotificationsWithError error: Error
  ) {
    finishNotifications(
      error: FlutterError(
        code: "registration_failed",
        message: "This device could not register for notifications.",
        details: nil
      )
    )
  }

  private func finishNotifications(
    granted: Bool = false,
    token: String? = nil,
    error: FlutterError? = nil
  ) {
    guard let result = notificationResult else { return }
    notificationResult = nil
    if let error {
      result(error)
    } else {
      result(["granted": granted, "token": token as Any])
    }
  }
}

private extension Data {
  init?(base64URLEncoded value: String) {
    var base64 = value.replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    base64 += String(repeating: "=", count: (4 - base64.count % 4) % 4)
    self.init(base64Encoded: base64)
  }

  func base64URLEncodedString() -> String {
    base64EncodedString()
      .replacingOccurrences(of: "+", with: "-")
      .replacingOccurrences(of: "/", with: "_")
      .replacingOccurrences(of: "=", with: "")
  }
}
