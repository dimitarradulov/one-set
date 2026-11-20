struct SupersetPair: Codable, Hashable, Sendable {
  let firstSlotID: String
  let secondSlotID: String

  func contains(slotID: String) -> Bool {
    firstSlotID == slotID || secondSlotID == slotID
  }

  private enum CodingKeys: String, CodingKey {
    case firstSlotID = "firstSlotId"
    case secondSlotID = "secondSlotId"
  }
}
