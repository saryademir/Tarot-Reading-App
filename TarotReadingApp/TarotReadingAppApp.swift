//
//  TarotReadingAppApp.swift
//  TarotReadingApp
//
//  Created by Sarya Demir on 08/02/2025.
import SwiftUI
import Foundation
import FirebaseCore
import FirebaseFirestore
private let apiKey = "DUMMY_API_KEY"

struct TarotCard: Identifiable {
    let id = UUID()
    let name: String
    let img: String
}

extension TarotCard: Decodable {
    enum CodingKeys: String, CodingKey {
        case name
        case img
    }
}



struct Meanings: Decodable {
    let light: [String]
    let shadow: [String]
}


// Define a structure that matches the JSON structure
struct TarotDeck: Decodable {
    let cards: [TarotCard]
}

class TarotViewModel: ObservableObject {
    @Published var isFetchingUserInfo = false
    @Published var tarotCards: [TarotCard] = []
    @Published var selectedCards: [TarotCard] = []
    @Published var flippedCards: Set<UUID> = []
    @Published var overallReading: String = ""
    @Published var selectedCategory: String = "Genel"
    @Published var isLoading: Bool = false

    @Published var userInfo: UserInfo? {
            didSet {
                print("✅ userInfo GÜNCELLENDİ! Yeni değer: \(String(describing: userInfo))")
            }
        }

        init() {
            loadTarotData()
            print("🚀 TarotViewModel başlatılıyor, UserDefaults kontrol ediliyor...")

            // İlk başta UserDefaults'tan çekmeyi dene
            if let savedUserData = UserDefaults.standard.data(forKey: "savedUserInfo") {
                let decoder = JSONDecoder()
                if let loadedUser = try? decoder.decode(UserInfo.self, from: savedUserData) {
                    self.userInfo = loadedUser
                    print("✅ UserInfo başlangıçta UserDefaults'tan yüklendi: \(loadedUser.username)")
                } else {
                    print("❌ UserDefaults'taki veri parse edilemedi.")
                }
            } else {
                print("⚠️ UserDefaults'ta kullanıcı bilgisi bulunamadı.")
            }

            // Eğer `userInfo` hala nil ise manuel olarak çekmeyi dene
            if userInfo == nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    print("🔄 UserInfo hala nil, manuel çekme başlatılıyor...")
                    self.manualUserFetch()
                }
            }
        }
    
   
    
   

    
    func fetchUpdatedUserInfo() {
        print("🔥 Firestore Fetch Başlıyor! userInfo: \(String(describing: userInfo))")

        var username: String? = userInfo?.username

        // Eğer userInfo nil ise, UserDefaults'tan username çek
        if username == nil {
            username = UserDefaults.standard.string(forKey: "savedUsername")
            print("⚠️ userInfo nil, UserDefaults'tan username alınıyor: \(String(describing: username))")
        }

        guard let validUsername = username else {
            print("❌ Username hâlâ nil, Firestore fetch iptal ediliyor.")
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                if self.userInfo == nil {
                    print("❌ Still NIL after Firestore, fetching manually from UserDefaults...")
                    self.manualUserFetch()
                }
            }
            return
        }

        if isFetchingUserInfo {
            print("⚠️ Fetching already in progress, skipping duplicate request.")
            return
        }

        isFetchingUserInfo = true
        print("🔄 Fetching updated user info for \(validUsername)...")

        let db = Firestore.firestore()
        db.collection("users").document(validUsername).getDocument { document, error in
            self.isFetchingUserInfo = false

            if let error = error {
                print("❌ Firestore fetch error: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists {
                print("✅ Firestore'dan veri çekildi!")
                print("📄 RAW Firestore Data: \(String(describing: document.data()))")
            } else {
                print("❌ Firestore'dan veri GELMİYOR!")
                return
            }

            guard let data = document?.data() else {
                print("❌ Firestore'dan gelen data nil!")
                return
            }

            if let updatedUser = self.parseUserData(username: validUsername, data: data) {
                DispatchQueue.main.async {
                    print("📌 Güncellenen tarotHistory: \(updatedUser.tarotHistory.count) kayıt bulundu.")
                    print("📌 Güncellenen questionHistory: \(updatedUser.questionHistory.count) soru bulundu.")

                    self.userInfo = UserInfo(
                        username: updatedUser.username,
                        password: updatedUser.password,
                        name: updatedUser.name,
                        birthDate: updatedUser.birthDate,
                        favoriteCategory: updatedUser.favoriteCategory,
                        relationshipStatus: updatedUser.relationshipStatus,
                        workStatus: updatedUser.workStatus,
                        tarotHistory: updatedUser.tarotHistory,  // 🔥 Güncellenen tarot history eklendi
                        questionHistory: updatedUser.questionHistory // 🔥 Güncellenen question history eklendi
                    )

                    self.saveUserToDefaults(updatedUser) // ✅ Kullanıcı bilgilerini kaydet
                    self.objectWillChange.send() // ✅ SwiftUI güncelleme algılasın
                }
            }
 else {
                print("❌ Firestore’dan çekilen veri parse edilemedi!")
            }
        }
    }

    func fetchUserData() {
            guard let username = userInfo?.username, !username.isEmpty else {
                print("❌ Kullanıcı adı bulunamadı, Firestore fetch iptal!")
                return
            }

            print("🔥 Firestore'dan tekrar veri çekiliyor: \(username)...")

            let db = Firestore.firestore()
            db.collection("users").document(username).getDocument { document, error in
                if let error = error {
                    print("❌ Firestore fetch error: \(error.localizedDescription)")
                    return
                }

                guard let data = document?.data() else {
                    print("❌ Firestore’dan gelen data nil!")
                    return
                }

                if let updatedUser = self.parseUserData(username: username, data: data) {
                    DispatchQueue.main.async {
                        print("📌 Firestore’dan gelen güncel veriler: \(updatedUser.tarotHistory.count) tarot kaydı, \(updatedUser.questionHistory.count) soru kaydı.")

                        self.userInfo = updatedUser
                        self.saveUserToDefaults(updatedUser) // ✅ Kullanıcı bilgilerini kaydet
                    }
                } else {
                    print("❌ Firestore’dan çekilen veri parse edilemedi!")
                }
            }
        }

    private func manualUserFetch() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            if self.userInfo != nil {
                print("✅ UserInfo is already set, skipping manual fetch.")
                return
            }

            if let savedUserData = UserDefaults.standard.data(forKey: "savedUserInfo") {
                let decoder = JSONDecoder()
                if let loadedUser = try? decoder.decode(UserInfo.self, from: savedUserData) {
                    self.userInfo = loadedUser
                    print("✅ UserInfo manually restored from UserDefaults: \(loadedUser.name)")
                }
            } else {
                print("⚠️ No saved user info found in UserDefaults.")
            }
        }
    }

    func parseUserData(username: String, data: [String: Any]) -> UserInfo? {
        print("📄 RAW Firestore Data for \(username): \(data)")

        guard let name = data["name"] as? String,
              let birthDateTimestamp = data["birthDate"] as? Timestamp,
              let favoriteCategory = data["favoriteCategory"] as? String,
              let relationshipStatus = data["relationshipStatus"] as? String,
              let workStatus = data["workStatus"] as? String else {
            print("❌ Error parsing Firestore data! Some fields are missing or incorrect.")
            return nil
        }

        let birthDate = birthDateTimestamp.dateValue()
        print("✅ PARSED User Info -> Name: \(name), BirthDate: \(birthDate)")

        // 🔍 Tarot geçmişini alıyoruz
        var tarotHistory: [TarotReading] = []
        if let tarotHistoryData = data["tarotHistory"] as? [[String: Any]] {
            tarotHistory = tarotHistoryData.compactMap { tarotData in
                guard let idString = tarotData["id"] as? String,
                      let id = UUID(uuidString: idString),
                      let category = tarotData["category"] as? String,
                      let reading = tarotData["reading"] as? String else {
                    print("❌ TarotReading verisi hatalı! -> \(tarotData)")
                    return nil
                }


                let date: Date
                if let dateTimestamp = tarotData["date"] as? Timestamp {
                    date = dateTimestamp.dateValue()
                } else if let dateDouble = tarotData["date"] as? Double {
                    date = Date(timeIntervalSince1970: dateDouble)
                } else if let dateString = tarotData["date"] as? String,
                          let dateDouble = Double(dateString) {
                    date = Date(timeIntervalSince1970: dateDouble)
                } else {
                    print("❌ TarotReading için tarih okunamadı!")
                    return nil
                }

                return TarotReading(id: id, date: date, reading: reading, category: category)
            }
            print("✅ Tarot geçmişi başarıyla işlendi: \(tarotHistory.count) kayıt bulundu.")
        } else {
            print("⚠️ Firestore'dan tarotHistory verisi alınamadı veya eksik!")
        }

        // 🔍 Question History'yi alıyoruz
        var questionHistory: [QuestionHistoryEntry] = []
        if let questionHistoryData = data["questionHistory"] as? [[String: Any]] {
            questionHistory = questionHistoryData.compactMap { QuestionHistoryEntry.fromFirestore($0) }
            print("📄 Firestore’dan gelen `questionHistory` verisi: \(questionHistoryData)")
            print("✅ Question geçmişi başarıyla işlendi: \(questionHistory.count) soru bulundu.")
        } else {
            print("⚠️ Firestore'dan questionHistory verisi alınamadı veya eksik!")
        }

        return UserInfo(
            username: username,
            password: data["password"] as? String ?? "",
            name: name,
            birthDate: birthDate,
            favoriteCategory: favoriteCategory,
            relationshipStatus: relationshipStatus,
            workStatus: workStatus,
            tarotHistory: tarotHistory,
            questionHistory: questionHistory
        )
    }


        private func parseTarotReading(dict: [String: Any]) -> TarotReading? {
            guard let id = dict["id"] as? String,
                  let dateValue = dict["date"] as? Double,
                  let reading = dict["reading"] as? String,
                  let category = dict["category"] as? String else { return nil }

            return TarotReading(
                id: UUID(uuidString: id) ?? UUID(),
                date: Date(timeIntervalSince1970: dateValue),
                reading: reading,
                category: category
            )
        }

        private func parseQuestionHistory(dict: [String: Any]) -> QuestionHistoryEntry? {
            guard let idString = dict["id"] as? String,
                  let question = dict["question"] as? String,
                  let reading = dict["reading"] as? String,
                  let dateValue = dict["date"] as? Double else { return nil }

            return QuestionHistoryEntry(
                id: UUID(uuidString: idString) ?? UUID(),
                question: question,
                reading: reading,
                date: Date(timeIntervalSince1970: dateValue)
            )
        }

    private func saveUserToDefaults(_ user: UserInfo) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(user) {
            UserDefaults.standard.set(encoded, forKey: "savedUserInfo")
            UserDefaults.standard.set(user.username, forKey: "savedUsername") // ✅ Username'i de kaydet
            print("✅ Kullanıcı bilgileri UserDefaults'a kaydedildi: \(user.username)")
        }
    }

    func loadTarotData() {
        guard let url = Bundle.main.url(forResource: "tarot-images", withExtension: "json") else {
            print("❌ JSON file not found.")
            return
        }

        do {
            let data = try Data(contentsOf: url)
            
            // Decode JSON data
            if let rawJSON = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
               let cards = rawJSON["cards"] as? [[String: Any]] {

                // Extract only `name` and `img` fields
                self.tarotCards = cards.compactMap { card in
                    if let name = card["name"] as? String,
                       let img = card["img"] as? String {
                        return TarotCard(name: name, img: img)
                    }
                    return nil
                }

                // Shuffle the cards
                self.tarotCards.shuffle()
                print("✅ Successfully loaded and shuffled \(self.tarotCards.count) tarot cards.")
            }
        } catch {
            print("❌ Error loading tarot data: \(error.localizedDescription)")
        }
    }



    func selectCard(_ card: TarotCard) {
        guard selectedCards.count < 7 else { return }

        if !selectedCards.contains(where: { $0.id == card.id }) {
            flippedCards.insert(card.id)
            selectedCards.append(card)
            tarotCards.removeAll { $0.id == card.id } // ✅ Remove from deck
        }

        if selectedCards.count == 7 {
            // ✅ Check if userInfo is available before calling generateOverallReading
            if let userInfo = userInfo {
                generateOverallReading(userInfo:userInfo)
                print("✅ UserInfo is available. Proceeding with tarot reading:")
                print("Name: \(userInfo.name), BirthDate: \(userInfo.birthDate)")
            } else {
                print("❌ UserInfo is STILL NIL before tarot reading!")
            }

        }
    }


    func resetSelections() {
        selectedCards = []
        selectedCards.removeAll()
        flippedCards = []
        overallReading = ""
        loadTarotData()
    }
    
     func getZodiacSign(from date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month, .day], from: date)

        guard let month = components.month, let day = components.day else {
            print("❌ Invalid birth date received: \(date)")
            return "Bilinmeyen Burç"
        }

        print("✅ Corrected Month = \(month), Day = \(day)") // Debugging

        switch month {
        case 1: return day >= 20 ? "♒ Kova" : "♑ Oğlak"
        case 2: return day >= 19 ? "♓ Balık" : "♒ Kova"
        case 3: return day >= 21 ? "♈ Koç" : "♓ Balık"
        case 4: return day >= 20 ? "♉ Boğa" : "♈ Koç"
        case 5: return day >= 21 ? "♊ İkizler" : "♉ Boğa"
        case 6: return day >= 21 ? "♋ Yengeç" : "♊ İkizler"
        case 7: return day >= 23 ? "♌ Aslan" : "♋ Yengeç"
        case 8: return day >= 23 ? "♍ Başak" : "♌ Aslan"
        case 9: return day >= 23 ? "♎ Terazi" : "♍ Başak"
        case 10: return day >= 23 ? "♏ Akrep" : "♎ Terazi"
        case 11: return day >= 22 ? "♐ Yay" : "♏ Akrep"
        case 12: return day >= 22 ? "♑ Oğlak" : "♐ Yay"
        default: return "Bilinmeyen Burç"
        }
    }

    func generateOverallReading(userInfo: UserInfo?) {
        guard selectedCards.count == 7 else { return }

        let presentCard = selectedCards[0]
        let pastCards = selectedCards[1...3]
        let futureCards = selectedCards[4...6]

        let pastNames = pastCards.map { $0.name }.joined(separator: ", ")
        let futureNames = futureCards.map { $0.name }.joined(separator: ", ")

        // ✅ Ensure `userInfo` is not nil before accessing properties
        guard let userInfo = userInfo else {
            print("❌ UserInfo is NIL in tarot reading! Cannot compute zodiac.")
            return
        }

        // ✅ Correctly fetch birth date
        let birthDate: Date = userInfo.birthDate
        print("✅ Correct Birth Date Used in Tarot Reading: \(birthDate)")

        // ✅ Compute Zodiac Sign
        let zodiacSign = getZodiacSign(from: birthDate)
        print("✅ Computed Zodiac Sign: \(zodiacSign)")

        // ✅ Fetch user details
        let userName = userInfo.name
        let workStatus = userInfo.workStatus
        let relationshipStatus = userInfo.relationshipStatus

        let prompt = """
        You are providing a tarot reading for the category: \(selectedCategory).

        - User: \(userName)
        - Zodiac Sign: \(zodiacSign)
        - Work Status: \(workStatus)
        - Relationship Status: \(relationshipStatus)

        - Present: \(presentCard.name)
        - Past: \(pastNames)
        - Future: \(futureNames)

        Secilen kategoriye, kisinin dogum gununu goz onunde bulundurarak burcunu da ele alarak, is ve iliski durumunu da goz onunde bulundurarak secilen kartlari yorumla. Mistik, eglenceli, bol emojili bir yorum yap. Yorum Turkce olsun.
        """

        fetchAIResponse(for: prompt)
    }




    private func fetchAIResponse(for prompt: String) {
        isLoading = true
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("DUMMY_API_KEY", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant providing tarot readings."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 4000,
            "temperature": 0.7
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        } catch {
            print("❌ JSON oluşturulurken hata: \(error)")
            isLoading = false
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                print("❌ API isteği hatası: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("❌ API yanıtı boş döndü!")
                return
            }

            do {
                if let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let choices = jsonResponse["choices"] as? [[String: Any]],
                   let message = choices.first?["message"] as? [String: Any],
                   let text = message["content"] as? String {

                    DispatchQueue.main.async {
                        self.overallReading = text.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("✅ Tarot Yorumu API'den alındı: \(self.overallReading)")
                    }
                } else {
                    print("❌ API yanıt formatı hatalı!")
                }
            } catch {
                print("❌ JSON ayrıştırma hatası: \(error)")
            }
        }
        task.resume()
    }
}



enum AIResponseType {
    case overallReading
    case guide
    case cardDetails
    case userQuestion
}


//

import SwiftUI
class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        FirebaseApp.configure()
        return true
    }
}
@main
struct TarotReadingAppApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var viewModel = TarotViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        if viewModel.userInfo == nil {
                            print("🔄 Fetching user info in App launch...")
                            viewModel.fetchUpdatedUserInfo()
                        }
                    }
                }
        }
    }
}

