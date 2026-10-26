import Foundation

struct AthkarEntry: Codable, Identifiable, Hashable {
    var Title: String?
    var Athkar: String?
    var Count: Int?
    var Audio: String?

    var id: String { "\(Title ?? "")|\(Athkar?.prefix(32) ?? "")" }
}

struct PrayerMethod: Codable, Identifiable {
    var fajrAngle: Double
    var ishaAngle: Double
    var ishaInterval: Int
    var name: String
    var params: String
    var id: String { params }
}

struct City: Codable, Identifiable, Hashable {
    var name: String
    var lat: Double
    var lng: Double
    var tag: String?
    var country: String = ""
    var id: String { "\(country)-\(name)" }
}

struct SavedCounter: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var name: String
    var count: Int
    var target: Int
}