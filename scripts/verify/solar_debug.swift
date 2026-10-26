import Foundation

func rad(_ d: Double) -> Double { d * .pi / 180.0 }
func deg(_ r: Double) -> Double { r * 180.0 / .pi }
func fixAngle(_ a: Double) -> Double { let b = a.truncatingRemainder(dividingBy: 360.0); return b < 0 ? b + 360.0 : b }
func fixHour(_ a: Double) -> Double { let b = a.truncatingRemainder(dividingBy: 24.0); return b < 0 ? b + 24.0 : b }

// 2026-10-23 12:00 local for Mecca
let jdMidnightUT = 2461336.5
let lng = 39.8262, lat = 21.4225
let jd = jdMidnightUT - lng / (15.0 * 24.0) + 12.0 / 24.0
let D = jd - 2451545.0
print("jd:", jd, "D:", D)
let g = rad(fixAngle(357.529 + 0.98560028 * D))
let q = fixAngle(280.459 + 0.98564736 * D)
let L = fixAngle(q + 1.915 * sin(g) + 0.020 * sin(2 * g))
let e = rad(23.439 - 0.00000036 * D)
let declr = asin(sin(e) * sin(L))
let RA = deg(atan2(cos(e) * sin(L), cos(L))) / 15.0
let eqt = q / 15.0 - fixHour(RA)
print("g(deg):", deg(g), "q:", q, "L:", L, "decl:", deg(declr), "RA(h):", RA, "eqt(h):", eqt)
// expected: decl ~ -13.5, eqt ~ +0.26
