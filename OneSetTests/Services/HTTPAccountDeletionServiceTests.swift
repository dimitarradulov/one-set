import Foundation
import Testing
@testable import OneSet

@MainActor
struct HTTPAccountDeletionServiceTests {
  private let user = AuthenticatedUser(id: "user_1", emailAddress: "a@example.com")

  private final class Recorder: @unchecked Sendable {
    var requests: [URLRequest] = []
    func record(_ request: URLRequest) { requests.append(request) }
  }

  private func makeService(
    recorder: Recorder, status: Int? = 200, token: String = "tok",
    tokenFails: Bool = false, baseURL: URL? = URL(string: "https://api.example.com")
  ) -> HTTPAccountDeletionService {
    HTTPAccountDeletionService(
      baseURL: baseURL,
      token: { _ in
        if tokenFails { throw AccountSetupError.authenticationRequired }
        return token
      },
      send: { request in
        recorder.record(request)
        guard let status else { throw URLError(.notConnectedToInternet) }
        let response = HTTPURLResponse(
          url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!
        return (Data(), response)
      })
  }

  @Test func successfulDeleteSendsAuthenticatedDeleteOnce() async {
    let recorder = Recorder()
    let result = await makeService(recorder: recorder).deleteAccount(for: user)
    #expect(result == .deleted)
    #expect(recorder.requests.count == 1)
    #expect(recorder.requests.first?.httpMethod == "DELETE")
    #expect(recorder.requests.first?.url?.absoluteString == "https://api.example.com/v1/me")
    #expect(recorder.requests.first?.value(forHTTPHeaderField: "Authorization") == "Bearer tok")
  }

  @Test(arguments: [201, 202, 204, 301, 401, 403, 404, 500])
  func anyStatusOtherThan200FailsWithoutRetry(status: Int) async {
    let recorder = Recorder()
    let result = await makeService(recorder: recorder, status: status).deleteAccount(for: user)
    #expect(result == .failed)
    #expect(recorder.requests.count == 1)
  }

  @Test func offlineFails() async {
    let recorder = Recorder()
    let result = await makeService(recorder: recorder, status: nil).deleteAccount(for: user)
    #expect(result == .failed)
    #expect(recorder.requests.count == 1)
  }

  @Test func tokenFailureFailsWithoutSending() async {
    let recorder = Recorder()
    let result = await makeService(recorder: recorder, tokenFails: true).deleteAccount(for: user)
    #expect(result == .failed)
    #expect(recorder.requests.isEmpty)
  }

  @Test func missingBaseURLFailsWithoutSending() async {
    let recorder = Recorder()
    let result = await makeService(recorder: recorder, baseURL: nil).deleteAccount(for: user)
    #expect(result == .failed)
    #expect(recorder.requests.isEmpty)
  }

  @Test func previewServiceIsScriptable() async {
    #expect(await PreviewAccountDeletionService(arguments: []).deleteAccount(for: user) == .deleted)
    #expect(
      await PreviewAccountDeletionService(arguments: ["--ui-account-deletion-failure"])
        .deleteAccount(for: user) == .failed)
  }
}
