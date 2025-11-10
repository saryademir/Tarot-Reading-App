//
//  AskTarotView.swift
//  TarotReadingApp
//
//  Created by Sarya Demir on 08/02/2025.
//


import FirebaseFirestore
import SwiftUI

private let apiKey = "DUMMY_API_KEY"

struct AskTarotView: View {
    @StateObject private var viewModel = TarotViewModel()
    @State private var selectedCards: [TarotCard] = []
    @State private var userQuestion: String = ""
    @State private var tarotReading: String = ""
    @State private var isLoading = false
    @Binding var questionHistory: [QuestionHistoryEntry]
    @Binding var userInfo: UserInfo
    @State private var showSaveConfirmation: Bool = false


    var body: some View {
           let backgroundGradient = LinearGradient(
               gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.8)]),
               startPoint: .top,
               endPoint: .bottom
           )

           return ZStack {
               backgroundGradient.edgesIgnoringSafeArea(.all)

               VStack(spacing: 20) {
                   titleView
                   
                   if selectedCards.count < 3 {
                       cardSelectionView
                   } else {
                       questionInputView
                   }
                   
                   if !tarotReading.isEmpty {
                       tarotReadingView
                   }
               }
               .padding()
           }
       }

       private var titleView: some View {
           Text("🔮 Kart Seç ve Sorunu Sor")
               .font(.custom("Papyrus", size: 28))
               .foregroundColor(.white)
               .shadow(color: .purple, radius: 5)
       }

       private var cardSelectionView: some View {
           ScrollView(.horizontal, showsIndicators: false) {
               HStack(spacing: 15) {
                   ForEach(viewModel.tarotCards, id: \ .id) { card in
                       if !selectedCards.contains(where: { $0.id == card.id }) {
                           TarotCardView(
                               card: card,
                               isSelected: false,
                               onTap: { selectCard(card) }
                           )
                           .frame(width: 120, height: 180)
                       }
                   }
               }
               .padding(.horizontal)
           }
       }

       private var questionInputView: some View {
           VStack {
               TextField("Sorunuzu buraya yazın...", text: $userQuestion)
                   .padding()
                   .background(Color.white.opacity(0.2))
                   .cornerRadius(12)
                   .foregroundColor(.white)
                   .padding(.horizontal)

               HStack {
                   Button(action: {
                       generateTarotReading()
                       hideKeyboard() // ✅ Dismiss keyboard after submission
                   }) {
                       Text("Soruyu Sor 🎴")
                           .font(.headline)
                           .padding()
                           .background(Color.purple)
                           .foregroundColor(.white)
                           .cornerRadius(12)
                           .shadow(radius: 3)
                   }
                   .disabled(userQuestion.isEmpty || isLoading)

                   Button(action: resetView) {
                       Text("Sıfırla 🔄")
                           .font(.headline)
                           .padding()
                           .background(Color.red)
                           .foregroundColor(.white)
                           .cornerRadius(12)
                           .shadow(radius: 3)
                   }
               }
           }
       }

       private func hideKeyboard() {
           UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder),
                                           to: nil, from: nil, for: nil)
       }

    private var tarotReadingView: some View {
        VStack(spacing: 20) {
            HStack {
                ForEach(selectedCards, id: \.id) { card in
                    TarotCardView(
                        card: card,
                        isSelected: true,
                        onTap: {}
                    )
                    .frame(width: 100, height: 150)
                }
            }

            let background = RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.6))

            ScrollView {  // ✅ Kaydırma ekledik
                Text(tarotReading)
                    .italic()
                    .padding()
                    .foregroundColor(.yellow)
                    .multilineTextAlignment(.center)
                    .background(background)
                    .padding(.horizontal)
            }
            .frame(maxHeight: 300)  // ✅ Maksimum yükseklik verdik
            .cornerRadius(12)

            Button(action: {
                saveQuestion(question: userQuestion, answer: tarotReading)
            }) {
                Text("Soruyu Kaydet 📜")
                    .font(.headline)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                    .shadow(radius: 3)
            }
            .alert(isPresented: $showSaveConfirmation) {
                Alert(
                    title: Text("Başarıyla Kaydedildi!"),
                    message: Text("Bu soru geçmişinize eklendi."),
                    dismissButton: .default(Text("Tamam"))
                )
            }
        }
    }


    private func selectCard(_ card: TarotCard) {
        withAnimation {
            selectedCards.append(card)
        }
    }
    

    

    private func resetView() {
        withAnimation {
            selectedCards = []
            userQuestion = ""
            tarotReading = ""
        }
    }
 

   

    private func saveQuestion(question: String, answer: String) {
        guard !question.isEmpty, !answer.isEmpty else { return }

        // `userInfo` zaten `UserInfo` tipinde olduğu için doğrudan kullanılabilir
        var user = userInfo

        // Yeni bir soru girişini oluştur.
        let newEntry = QuestionHistoryEntry(question: question, reading: answer)
        user.questionHistory.append(newEntry)

        let db = Firestore.firestore()

        do {
            // `questionHistory` dizisini JSON formatına çevir
            let encodedHistory = try JSONEncoder().encode(user.questionHistory)
            let questionHistoryArray = try JSONSerialization.jsonObject(with: encodedHistory) as! [[String: Any]]

            // Firebase'e sadece `questionHistory`'yi güncelle
            db.collection("users").document(user.username).updateData([
                "questionHistory": questionHistoryArray
            ]) { error in
                if let error = error {
                    print("❌ Firebase Kaydetme Hatası: \(error.localizedDescription)")
                } else {
                    print("✅ Soru başarıyla kaydedildi.")
                    DispatchQueue.main.async {
                        userInfo = user // Güncel veriyi localde tut
                        showSaveConfirmation = true
                    }
                }
            }
        } catch {
            print("❌ JSON Encoding Hatası: \(error.localizedDescription)")
        }
    }


    private func generateTarotReading() {
        guard selectedCards.count == 3 else {
            tarotReading = "Lütfen önce 3 kart seçin."
            return
        }

        let userName = userInfo.username  // ✅ Kullanıcı adını al
        let prompt = """
        Merhaba \(userName)! 🔮 
        Kullanıcı şu soruyu sordu: \(userQuestion)
        Seçilen tarot kartları:
        - \(selectedCards[0].name)
        - \(selectedCards[1].name)
        - \(selectedCards[2].name)

        Lütfen bu kartlara göre kullanıcının sorusuna cevap vermeye çalış.
        En fazla 10 cümle olsun, emojilerle destekle! 🌟✨
        """

        fetchAIResponse(for: prompt)
    }


    private func fetchAIResponse(for prompt: String) {
        print("📡 Sending API request with prompt: \(prompt)")

        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            tarotReading = "Geçerli bir URL bulunamadı."
            print("❌ Hata: API URL hatalı!")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful tarot reader."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 400
        ]

        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
            print("📨 Request Sent!")
        } catch {
            tarotReading = "Hata: JSON oluşturulamadı."
            print("❌ JSON Error: \(error)")
            return
        }

        isLoading = true

        URLSession.shared.dataTask(with: request) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
            }

            if let error = error {
                DispatchQueue.main.async {
                    self.tarotReading = "Hata: \(error.localizedDescription)"
                    print("❌ API Error: \(error.localizedDescription)")
                }
                return
            }

            guard let data = data else {
                DispatchQueue.main.async {
                    self.tarotReading = "Hata: Sunucudan geçerli bir yanıt alınamadı."
                    print("❌ API returned empty response")
                }
                return
            }

            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]

                if let choices = jsonResponse?["choices"] as? [[String: Any]],
                   let firstChoice = choices.first,
                   let message = firstChoice["message"] as? [String: Any],
                   let content = message["content"] as? String {
                    DispatchQueue.main.async {
                        self.tarotReading = content.trimmingCharacters(in: .whitespacesAndNewlines)
                        print("✅ API Response Received: \(self.tarotReading)")
                    }
                } else {
                    DispatchQueue.main.async {
                        self.tarotReading = "Hata: Yanıt işlenemedi."
                        print("❌ JSON Parsing Error: Incorrect structure")
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.tarotReading = "Hata: \(error.localizedDescription)"
                    print("❌ JSON Decoding Error: \(error.localizedDescription)")
                }
            }
        }.resume()
    }
}

