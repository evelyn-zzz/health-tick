#!/usr/bin/env swift
import Foundation
import SQLite3

// MARK: - Test helpers

var testCount = 0
var passCount = 0
var failCount = 0

func assertEqual(_ actual: Int, _ expected: Int, _ msg: String, file: String = #file, line: Int = #line) {
    testCount += 1
    if actual == expected {
        passCount += 1
        print("  PASS: \(msg)")
    } else {
        failCount += 1
        print("  FAIL: \(msg) -- expected \(expected), got \(actual) (line \(line))")
    }
}

func dateStr(_ daysAgo: Int) -> String {
    let fmt = DateFormatter()
    fmt.dateFormat = "yyyy-MM-dd"
    return fmt.string(from: Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!)
}

func todayString() -> String { dateStr(0) }

func dateFmt() -> DateFormatter {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    return f
}

// MARK: - Database helpers

func openDB() -> OpaquePointer? {
    var db: OpaquePointer?
    sqlite3_open(":memory:", &db)
    sqlite3_exec(db, """
        CREATE TABLE records (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            timestamp TEXT NOT NULL,
            date TEXT NOT NULL
        );
        CREATE INDEX idx_records_date ON records(date);
    """, nil, nil, nil)
    return db
}

func addRecords(_ db: OpaquePointer?, date: String, count: Int) {
    let now = ISO8601DateFormatter().string(from: Date())
    for _ in 0..<count {
        sqlite3_exec(db, "INSERT INTO records (timestamp, date) VALUES ('\(now)', '\(date)')", nil, nil, nil)
    }
}

// MARK: - streakDays: skip days with no records, only break on "used but not met"

func streakDays(_ db: OpaquePointer?, goal: Int) -> Int {
    var stmt: OpaquePointer?
    let sql = "SELECT date, COUNT(*) as cnt FROM records GROUP BY date ORDER BY date DESC"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
    defer { sqlite3_finalize(stmt) }

    let today = todayString()
    var streak = 0

    while sqlite3_step(stmt) == SQLITE_ROW {
        let ds = String(cString: sqlite3_column_text(stmt, 0))
        let cnt = Int(sqlite3_column_int(stmt, 1))

        // Today hasn't met goal: in progress, skip
        if ds == today && cnt < goal { continue }

        if cnt >= goal {
            streak += 1
        } else {
            break
        }
    }

    return streak
}

// MARK: - maxStreakDays: same rule, skip-free days, only break on "used but not met"

func maxStreakDays(_ db: OpaquePointer?, goal: Int) -> Int {
    var stmt: OpaquePointer?
    let sql = "SELECT date, COUNT(*) as cnt FROM records GROUP BY date ORDER BY date"
    guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK else { return 0 }
    defer { sqlite3_finalize(stmt) }

    var maxS = 0, curS = 0

    while sqlite3_step(stmt) == SQLITE_ROW {
        let cnt = Int(sqlite3_column_int(stmt, 1))
        if cnt >= goal {
            curS += 1
            maxS = max(maxS, curS)
        } else {
            curS = 0
        }
    }

    return maxS
}

// MARK: - Tests

print("=== streakDays tests ===\n")

// 1. Empty
do {
    let db = openDB()
    assertEqual(streakDays(db, goal: 3), 0, "1. empty db -> 0")
    sqlite3_close(db)
}

// 2. Today met
do {
    let db = openDB()
    addRecords(db, date: dateStr(0), count: 3)
    assertEqual(streakDays(db, goal: 3), 1, "2. today met -> 1")
    sqlite3_close(db)
}

// 3. Today in progress (not met), yesterday met
do {
    let db = openDB()
    addRecords(db, date: dateStr(0), count: 1)
    addRecords(db, date: dateStr(1), count: 3)
    assertEqual(streakDays(db, goal: 3), 1, "3. today in-progress, yesterday met -> 1")
    sqlite3_close(db)
}

// 4. Today no records, yesterday met
do {
    let db = openDB()
    addRecords(db, date: dateStr(1), count: 3)
    assertEqual(streakDays(db, goal: 3), 1, "4. today no records, yesterday met -> 1")
    sqlite3_close(db)
}

// 5. Two days met
do {
    let db = openDB()
    addRecords(db, date: dateStr(1), count: 3)
    addRecords(db, date: dateStr(2), count: 3)
    assertEqual(streakDays(db, goal: 3), 2, "5. 2-day streak -> 2")
    sqlite3_close(db)
}

// 6. Three consecutive days including today
do {
    let db = openDB()
    addRecords(db, date: dateStr(0), count: 3)
    addRecords(db, date: dateStr(1), count: 3)
    addRecords(db, date: dateStr(2), count: 3)
    assertEqual(streakDays(db, goal: 3), 3, "6. 3 days with today -> 3")
    sqlite3_close(db)
}

// 7. Today in progress, yesterday NOT met -> break
do {
    let db = openDB()
    addRecords(db, date: dateStr(0), count: 1)
    addRecords(db, date: dateStr(1), count: 1)
    assertEqual(streakDays(db, goal: 3), 0, "7. today in-progress, yesterday not met -> 0")
    sqlite3_close(db)
}

// 8. No records for several days, old record met -> still counts (didn't use app = no penalty)
do {
    let db = openDB()
    addRecords(db, date: dateStr(5), count: 3)
    assertEqual(streakDays(db, goal: 3), 1, "8. 5 days ago met, no records since -> 1")
    sqlite3_close(db)
}

// 9. Yesterday met, day before used but NOT met -> break at day before
do {
    let db = openDB()
    addRecords(db, date: dateStr(1), count: 3)
    addRecords(db, date: dateStr(2), count: 1)
    addRecords(db, date: dateStr(3), count: 3)
    assertEqual(streakDays(db, goal: 3), 1, "9. yesterday met, day-2 not met -> 1")
    sqlite3_close(db)
}

// 10. Long streak: 7 days met, today no records
do {
    let db = openDB()
    for i in 1...7 {
        addRecords(db, date: dateStr(i), count: 3)
    }
    assertEqual(streakDays(db, goal: 3), 7, "10. 7-day streak -> 7")
    sqlite3_close(db)
}

// 11. Leave/no-app scenario: 3 days no records, before that 5 days met -> 5
do {
    let db = openDB()
    for i in 4...8 {
        addRecords(db, date: dateStr(i), count: 3)
    }
    assertEqual(streakDays(db, goal: 3), 5, "11. 3 days no app, 5-day streak -> 5")
    sqlite3_close(db)
}

// 12. Today met, then gap (no records), then met -> streak continues through gap
do {
    let db = openDB()
    addRecords(db, date: dateStr(0), count: 3)
    // days 1-2: no records
    addRecords(db, date: dateStr(3), count: 3)
    assertEqual(streakDays(db, goal: 3), 2, "12. today met, gap, then met -> 2")
    sqlite3_close(db)
}

// 13. User scenario: 1号完成, 今天2号
do {
    let db = openDB()
    addRecords(db, date: dateStr(1), count: 3)
    let streak = streakDays(db, goal: 3)
    assertEqual(streak, 1, "13. user: yesterday done -> 1")
    assertEqual(3 - streak, 2, "13b. badge: 2 days left")
    sqlite3_close(db)
}

// 14. User scenario: 2号用了app但没达标, 今天3号
do {
    let db = openDB()
    addRecords(db, date: dateStr(2), count: 3) // day 1 met
    addRecords(db, date: dateStr(1), count: 1) // day 2 used, not met = break
    let streak = streakDays(db, goal: 3)
    assertEqual(streak, 0, "14. user: day 2 broke streak -> 0")
    assertEqual(3 - streak, 3, "14b. badge: 3 days left")
    sqlite3_close(db)
}

// 15. Weekend scenario: Fri met, Sat/Sun no app, Mon(today) just opened -> 1
do {
    let db = openDB()
    addRecords(db, date: dateStr(3), count: 3) // Fri
    // Sat(2), Sun(1): no records
    assertEqual(streakDays(db, goal: 3), 1, "15. Fri met, weekend off, Mon today -> 1")
    sqlite3_close(db)
}

// 16. Today in progress, long streak with gaps (leave days)
do {
    let db = openDB()
    addRecords(db, date: dateStr(0), count: 1) // today in progress
    addRecords(db, date: dateStr(1), count: 3) // yesterday met
    // day 2-3: no records (leave)
    addRecords(db, date: dateStr(4), count: 3) // met
    addRecords(db, date: dateStr(5), count: 3) // met
    assertEqual(streakDays(db, goal: 3), 3, "16. today in-progress, streak with leave gaps -> 3")
    sqlite3_close(db)
}

// 17. Half year no records, last day met -> 1
do {
    let db = openDB()
    addRecords(db, date: dateStr(180), count: 3)
    assertEqual(streakDays(db, goal: 3), 1, "17. 6 months ago met, no records since -> 1")
    sqlite3_close(db)
}

print("\n=== maxStreakDays tests ===\n")

// 18. Basic max streak
do {
    let db = openDB()
    for i in 1...5 {
        addRecords(db, date: dateStr(i), count: 3)
    }
    assertEqual(maxStreakDays(db, goal: 3), 5, "18. max streak 5 -> 5")
    sqlite3_close(db)
}

// 19. Max streak with break in middle
do {
    let db = openDB()
    addRecords(db, date: dateStr(5), count: 3)
    addRecords(db, date: dateStr(4), count: 3)
    addRecords(db, date: dateStr(3), count: 3)
    addRecords(db, date: dateStr(2), count: 1) // not met = break
    addRecords(db, date: dateStr(1), count: 3)
    assertEqual(maxStreakDays(db, goal: 3), 3, "19. max streak with break -> 3")
    sqlite3_close(db)
}

// 20. Max streak captures historical best
do {
    let db = openDB()
    for i in 6...10 {
        addRecords(db, date: dateStr(i), count: 3) // 5-day streak
    }
    addRecords(db, date: dateStr(5), count: 1) // break
    for i in 1...3 {
        addRecords(db, date: dateStr(i), count: 3) // 3-day streak
    }
    assertEqual(maxStreakDays(db, goal: 3), 5, "20. max streak historical best -> 5")
    sqlite3_close(db)
}

// 21. Max streak with gaps (no records = not a break)
do {
    let db = openDB()
    addRecords(db, date: dateStr(10), count: 3)
    addRecords(db, date: dateStr(8), count: 3) // day 9 no records = skip
    addRecords(db, date: dateStr(5), count: 3) // day 6-7 no records = skip
    assertEqual(maxStreakDays(db, goal: 3), 3, "21. max streak with gaps (no records) -> 3")
    sqlite3_close(db)
}

// 22. Max streak: gap doesn't connect separate streaks broken by not-met
do {
    let db = openDB()
    addRecords(db, date: dateStr(5), count: 3) // met
    addRecords(db, date: dateStr(4), count: 1) // not met = real break
    addRecords(db, date: dateStr(1), count: 3) // met
    assertEqual(maxStreakDays(db, goal: 3), 1, "22. not-met breaks even with gaps -> 1")
    sqlite3_close(db)
}

// MARK: - Summary

print("\n============================")
print("Total: \(testCount), Passed: \(passCount), Failed: \(failCount)")
if failCount > 0 {
    print("SOME TESTS FAILED!")
    exit(1)
} else {
    print("ALL TESTS PASSED!")
}
