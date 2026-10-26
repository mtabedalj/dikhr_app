import Foundation

struct PrayerMethod: Codable { var fajrAngle: Double; var ishaAngle: Double; var ishaInterval: Int; var name: String; var params: String }

let method = PrayerMethod(fajrAngle: 18.5, ishaAngle: 0, ishaInterval: 90, name: "UmAlQura", params: "ummAlQura")
let date = Date()
let cal = Calendar(identifier: .gregorian)
let ymd = cal.dateComponents([.year, .month, .day], from: date)
print("date: \(ymd.year!)-\(ymd.month!)-\(ymd.day!)")

func run(lat: Double, lng: Double, tz: TimeZone, label: String) {
    let times = PrayerTimesEngine.calculate(method: method, lat: lat, lng: lng, date: date, timeZone: tz)
    let f = DateFormatter(); f.timeZone = tz; f.dateFormat = "HH:mm"
    print(label)
    print("  Fajr    \(f.string(from: times.fajr))")
    print("  Sunrise \(f.string(from: times.sunrise))")
    print("  Dhuhr   \(f.string(from: times.dhuhr))")
    print("  Asr     \(f.string(from: times.asr))")
    print("  Maghrib \(f.string(from: times.maghrib))")
    print("  Isha    \(f.string(from: times.isha))")
    print("  Qiyam   \(f.string(from: times.qiyamStart))")
}

run(lat: 21.4225, lng: 39.8262, tz: TimeZone(identifier: "Asia/Riyadh")!, label: "Mecca (UTC+3)")