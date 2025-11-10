import SwiftUI
import Foundation
import FirebaseFirestore

// ✅ Define a struct for question history entries that conforms to Codable.
struct QuestionHistoryEntry: Codable, Identifiable, Equatable {
    let id: UUID
    let question: String
    let reading: String
    let date: Date

    init(id: UUID = UUID(), question: String, reading: String, date: Date = Date()) {
        self.id = id
        self.question = question
        self.reading = reading
        self.date = date
    }

    // ✅ Convert to Firestore format
    func toFirestore() -> [String: Any] {
        return [
            "id": id.uuidString,
            "question": question,
            "reading": reading,
            "date": Timestamp(date: date) // ✅ Convert Date to Firestore Timestamp
        ]
    }

    // ✅ Convert Firestore data to `QuestionHistoryEntry`
    static func fromFirestore(_ data: [String: Any]) -> QuestionHistoryEntry? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let question = data["question"] as? String,
              let reading = data["reading"] as? String else {
            print("❌ QuestionHistoryEntry parse hatası! \(data)")
            return nil
        }

        // 🔍 Tarih formatı farklı olabilir, güvenli dönüştürme yapalım
        var date: Date?
        
        if let dateTimestamp = data["date"] as? Timestamp {
            date = dateTimestamp.dateValue()
        } else if let dateDouble = data["date"] as? Double {
            date = Date(timeIntervalSince1970: dateDouble)
        } else if let dateString = data["date"] as? String, let dateDouble = Double(dateString) {
            date = Date(timeIntervalSince1970: dateDouble)
        }

        guard let safeDate = date else {
            print("❌ QuestionHistoryEntry için tarih okunamadı! \(data)")
            return nil
        }

        return QuestionHistoryEntry(
            id: id,
            question: question,
            reading: reading,
            date: safeDate
        )
    }

}

// ✅ Define a struct for user information with Firestore compatibility
struct UserInfo: Codable , Equatable{
    var username: String
    var password: String
    var name: String
    var birthDate: Date
    var favoriteCategory: String
    var relationshipStatus: String
    var workStatus: String
    var tarotHistory: [TarotReading] = []
    var questionHistory: [QuestionHistoryEntry] = []
    // ✅ Implement `Equatable` to compare objects
        static func == (lhs: UserInfo, rhs: UserInfo) -> Bool {
            return lhs.username == rhs.username &&
                   lhs.password == rhs.password &&
                   lhs.name == rhs.name &&
                   lhs.birthDate == rhs.birthDate &&
                   lhs.favoriteCategory == rhs.favoriteCategory &&
                   lhs.relationshipStatus == rhs.relationshipStatus &&
                   lhs.workStatus == rhs.workStatus &&
                   lhs.tarotHistory == rhs.tarotHistory &&
                   lhs.questionHistory == rhs.questionHistory
        }

    // ✅ Ensure `Date` is correctly encoded/decoded for Firestore
    enum CodingKeys: String, CodingKey {
        case username, password, name, birthDate, favoriteCategory, relationshipStatus, workStatus, tarotHistory, questionHistory
    }

    // ✅ Firestore-friendly Encoder (convert `Date` to `Timestamp`)
    func toFirestore() -> [String: Any] {
        return [
            "username": username,
            "password": password,
            "name": name,
            "birthDate": Timestamp(date: birthDate), // ✅ Convert Date to Firestore Timestamp
            "favoriteCategory": favoriteCategory,
            "relationshipStatus": relationshipStatus,
            "workStatus": workStatus,
            "tarotHistory": tarotHistory.map { $0.toFirestore() }, // ✅ Convert Tarot History to Firestore format
            "questionHistory": questionHistory.map { $0.toFirestore() } // ✅ Convert Question History to Firestore format
        ]
    }

    // ✅ Firestore-friendly Decoder (convert `Timestamp` to `Date`)
    static func fromFirestore(data: [String: Any]) -> UserInfo? {
        guard let username = data["username"] as? String,
              let password = data["password"] as? String,
              let name = data["name"] as? String,
              let birthDateTimestamp = data["birthDate"] as? Timestamp, // ✅ Ensure it's a Firestore Timestamp
              let favoriteCategory = data["favoriteCategory"] as? String,
              let relationshipStatus = data["relationshipStatus"] as? String,
              let workStatus = data["workStatus"] as? String
        else {
            print("❌ Firestore verisi çözülemedi!")
            return nil
        }

        let tarotHistory = (data["tarotHistory"] as? [[String: Any]])?.compactMap { TarotReading.fromFirestore($0) } ?? []
        let questionHistory = (data["questionHistory"] as? [[String: Any]])?.compactMap { QuestionHistoryEntry.fromFirestore($0) } ?? []

        return UserInfo(
            username: username,
            password: password,
            name: name,
            birthDate: birthDateTimestamp.dateValue(), // ✅ Convert Firestore Timestamp to Swift `Date`
            favoriteCategory: favoriteCategory,
            relationshipStatus: relationshipStatus,
            workStatus: workStatus,
            tarotHistory: tarotHistory,
            questionHistory: questionHistory
        )
    }
}

// ✅ Define a struct for tarot readings with Firestore compatibility
struct TarotReading: Identifiable, Codable, Equatable {
    var id = UUID()
    var date: Date
    var reading: String
    var category: String
    
    // ✅ Implement `Equatable` to compare `TarotReading` objects
       static func == (lhs: TarotReading, rhs: TarotReading) -> Bool {
           return lhs.id == rhs.id &&
                  lhs.date == rhs.date &&
                  lhs.reading == rhs.reading &&
                  lhs.category == rhs.category
       }
    // ✅ Convert to Firestore format
    func toFirestore() -> [String: Any] {
        return [
            "id": id.uuidString,
            "date": Timestamp(date: date), // ✅ Convert Date to Firestore Timestamp
            "reading": reading,
            "category": category
        ]
    }

    // ✅ Convert Firestore data to `TarotReading`
    static func fromFirestore(_ data: [String: Any]) -> TarotReading? {
        guard let idString = data["id"] as? String,
              let id = UUID(uuidString: idString),
              let reading = data["reading"] as? String,
              let category = data["category"] as? String,
              let dateTimestamp = data["date"] as? Timestamp else {
            return nil
        }
        return TarotReading(id: id, date: dateTimestamp.dateValue(), reading: reading, category: category)
    }
}
