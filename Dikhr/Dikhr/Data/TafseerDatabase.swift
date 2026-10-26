import Foundation
import SQLite3

/// Tafsir (tafseer_mouaser) keyed by surah + ayah, same schema as the original.
final class TafseerDatabase {
    static let shared = TafseerDatabase()
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.dikhr.tafseer")

    private init() {
        guard let url = Bundle.main.url(forResource: "tafseer", withExtension: "sqlite") else { return }
        var pointer: OpaquePointer?
        let flags = SQLITE_OPEN_READONLY | SQLITE_OPEN_FULLMUTEX
        if sqlite3_open_v2(url.path, &pointer, flags, nil) == SQLITE_OK {
            db = pointer
        }
    }

    func tafseer(surah: Int, ayah: Int) -> String? {
        guard let db else { return nil }
        return queue.sync { query(db, surah: surah, ayah: ayah) }
    }

    private func query(_ db: OpaquePointer, surah: Int, ayah: Int) -> String? {
        let sql = "SELECT aya_tafseer FROM tafseer_mouaser WHERE sura_no = ? AND aya_no = ? LIMIT 1"
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return nil }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(surah))
        sqlite3_bind_int64(stmt, 2, Int64(ayah))
        if sqlite3_step(stmt) == SQLITE_ROW, let c = sqlite3_column_text(stmt, 0) {
            return String(cString: c)
        }
        return nil
    }
}