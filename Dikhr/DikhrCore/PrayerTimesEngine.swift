import Foundation

struct PrayerTimes: Equatable {
    var fajr: Date
    var sunrise: Date
    var dhuhr: Date
    var asr: Date
    var maghrib: Date
    var isha: Date
    var qiyamStart: Date

    static func == (lhs: PrayerTimes, rhs: PrayerTimes) -> Bool {
        lhs.fajr == rhs.fajr && lhs.sunrise == rhs.sunrise && lhs.dhuhr == rhs.dhuhr &&
        lhs.asr == rhs.asr && lhs.maghrib == rhs.maghrib && lhs.isha == rhs.isha
    }
}

enum PrayerKind: String, CaseIterable, Identifiable {
    case fajr, sunrise, dhuhr, asr, maghrib, isha
    var id: String { rawValue }

    var arabicName: String {
        switch self {
        case .fajr: return "الفجر"
        case .sunrise: return "الشروق"
        case .dhuhr: return "الظهر"
        case .asr: return "العصر"
        case .maghrib: return "المغرب"
        case .isha: return "العشاء"
        }
    }
    var symbol: String {
        switch self {
        case .fajr: return "sunrise.fill"
        case .sunrise: return "sun.max"
        case .dhuhr: return "sun.max.fill"
        case .asr: return "sun.and.horizon.fill"
        case .maghrib: return "sunset.fill"
        case .isha: return "moon.stars.fill"
        }
    }
}

/// Solar-based prayer-time calculation using the standard astronomical
/// algorithm family shared by PrayTimes/Adhan (declination + equation of time).
/// Angles in degrees; Hanafi asr and high-latitude adjustments are follow-ups.
enum PrayerTimesEngine {

    /// Returns prayer times for `date` (any instant within that civil day, local timezone).
    static func calculate(method: PrayerMethod, lat: Double, lng: Double, date: Date, timeZone: TimeZone) -> PrayerTimes {
        let calendar = Calendar(identifier: .gregorian)
        let ymd = calendar.dateComponents([.year, .month, .day], from: date)
        let jdMidnightUT = julianDay(year: ymd.year ?? 2000, month: ymd.month ?? 1, day: ymd.day ?? 1)
        let tz = Double(timeZone.secondsFromGMT(for: date)) / 3600.0

        // Time zone corrected so the search starts near the actual day fraction in local time:
        // local days shift the sun-elevation search away from midnight artifacts.
        func sunPosition(_ localHour: Double) -> (decl: Double, eqtHours: Double) {
            let jd = jdMidnightUT - lng / (15.0 * 24.0) + localHour / 24.0
            let D = jd - 2451545.0
            let g = rad(fixAngle(357.529 + 0.98560028 * D))
            let q = fixAngle(280.459 + 0.98564736 * D)
            let L = fixAngle(q + 1.915 * sin(g) + 0.020 * sin(2 * g))
            let Lr = rad(L)
            let e = rad(23.439 - 0.00000036 * D)
            let decl = asin(sin(e) * sin(Lr))
            let RA = deg(atan2(cos(e) * sin(Lr), cos(Lr))) / 15.0
            let eqt = q / 15.0 - fixHour(RA)
            return (decl, eqt)
        }

        func solarNoon(_ localHour: Double) -> Double {
            let (_, eqt) = sunPosition(localHour)
            return fixHour(12 - eqt)
        }

        func hourAngle(_ angle: Double, _ localHour: Double) -> Double {
            let decl = sunPosition(localHour).decl
            let noon = solarNoon(localHour)
            let v = (1.0 / 15.0) * deg(acos(
                clamp((-sin(rad(angle)) - sin(decl) * sin(rad(lat))) /
                      (cos(decl) * cos(rad(lat)))))
            )
            return v
        }

        func sunAngleTime(_ angle: Double, seed: Double, beforeNoon: Bool) -> Double {
            var h = seed
            for _ in 0..<3 {
                let v = hourAngle(angle, h)
                let noon = solarNoon(h)
                h = beforeNoon ? noon - v : noon + v
            }
            return h
        }

        func asrTime(shadowFactor: Double, seed: Double) -> Double {
            var h = seed
            for _ in 0..<3 {
                let declDeg = deg(sunPosition(h).decl)
                let angle = -deg(atan(1.0 / (shadowFactor + tan(rad(abs(lat - declDeg))))))
                let v = hourAngle(angle, h)
                h = solarNoon(h) + v
            }
            return h
        }

        let noonSolar = solarNoon(12.0)  // solar clock; independent of local-hour seed

        let fajrLocal = solarNoon(5) - hourAngle(method.fajrAngle, 5) + tz - lng / 15.0
        let sunriseLocal = solarNoon(6) - hourAngle(0.833, 6) + tz - lng / 15.0
        let dhuhrLocal = noonSolar + tz - lng / 15.0 + 1.0 / 60.0
        let asrLocal = asrTime(shadowFactor: 1.0, seed: 15) + tz - lng / 15.0
        let sunsetLocal = solarNoon(18) + hourAngle(0.833, 18) + tz - lng / 15.0
        let ishaLocal: Double
        if method.ishaInterval > 0 {
            ishaLocal = sunsetLocal + Double(method.ishaInterval) / 60.0
        } else {
            ishaLocal = solarNoon(20) + hourAngle(method.ishaAngle, 20) + tz - lng / 15.0
        }

        let night = (sunriseLocal + 24) - sunsetLocal
        let midnightLocal = sunsetLocal + night / 2.0
        let qiyamLocal = midnightLocal + night / 6.0

        func toDate(_ localHour: Double) -> Date {
            // local hour + tz → UT; Julian day is the midnight-UT JD of the civil day
            let utDays = jdMidnightUT + (localHour - tz) / 24.0
            return dateFromJulianDay(utDays)
        }

        return PrayerTimes(
            fajr: toDate(fajrLocal),
            sunrise: toDate(sunriseLocal),
            dhuhr: toDate(dhuhrLocal),
            asr: toDate(asrLocal),
            maghrib: toDate(sunsetLocal),
            isha: toDate(ishaLocal),
            qiyamStart: toDate(qiyamLocal)
        )
    }

    // MARK: - Math helpers (degree domain unless noted)

    private static func julianDay(year: Int, month: Int, day: Int) -> Double {
        var y = year, m = month
        if m <= 2 { y -= 1; m += 12 }
        let a = floor(Double(y) / 100.0)
        let b = 2 - a + floor(a / 4.0)
        return floor(365.25 * Double(y + 4716)) + floor(30.6001 * Double(m + 1)) + Double(day) + b - 1524.5
    }

    private static func dateFromJulianDay(_ jd: Double) -> Date {
        Date(timeIntervalSince1970: (jd - 2440587.5) * 86400.0)
    }

    private static func fixAngle(_ a: Double) -> Double {
        let b = a.truncatingRemainder(dividingBy: 360.0)
        return b < 0 ? b + 360.0 : b
    }
    private static func fixHour(_ a: Double) -> Double {
        let b = a.truncatingRemainder(dividingBy: 24.0)
        return b < 0 ? b + 24.0 : b
    }
    private static func rad(_ d: Double) -> Double { d * .pi / 180.0 }
    private static func deg(_ r: Double) -> Double { r * 180.0 / .pi }
    private static func clamp(_ v: Double) -> Double { min(1.0, max(-1.0, v)) }
}