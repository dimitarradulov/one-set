struct SupersetPair: Codable, Hashable, Sendable {
  let firstSlotID: String
  let secondSlotID: String

  private enum CodingKeys: String, CodingKey {
    case firstSlotID = "firstSlotId"
    case secondSlotID = "secondSlotId"
  }
}
