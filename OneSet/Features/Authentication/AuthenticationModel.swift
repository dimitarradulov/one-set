import Observation

@MainActor
@Observable
final class AuthenticationModel {
  enum Step: Equatable {
    case email
    case code
  }

  var emailAddress = ""
  var verificationCode = ""
  private(set) var step: Step = .email
  private(set) var isWorking = false
  private(set) var errorMessage: String?

  private let service: any AuthenticationService

  var signedInUser: AuthenticatedUser? { service.signedInUser }

  init(service: any AuthenticationService) {
    self.service = service
  }

  func sendCode() async {
    errorMessage = nil
    isWorking = true
    defer { isWorking = false }

    do {
      try await service.sendEmailCode(to: emailAddress)
      step = .code
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func verifyCode() async {
    errorMessage = nil
    isWorking = true
    defer { isWorking = false }

    do {
      try await service.verifyEmailCode(verificationCode)
      verificationCode = ""
    } catch {
      errorMessage = error.localizedDescription
    }
  }

  func resendCode() async {
    await sendCode()
  }

  func changeEmail() {
    step = .email
    verificationCode = ""
    errorMessage = nil
  }

  func signOut() async {
    errorMessage = nil
    isWorking = true
    defer { isWorking = false }

    do {
      try await service.signOut()
      emailAddress = ""
      verificationCode = ""
      step = .email
    } catch {
      errorMessage = error.localizedDescription
    }
  }
}
