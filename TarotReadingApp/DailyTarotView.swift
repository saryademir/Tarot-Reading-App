import SwiftUI


// OpenAI API Yanıtını İşlemek İçin Yapılar
struct OpenAIResponse: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String
        }
        let message: Message
    }
    let choices: [Choice]
}

private let apiKey = "DUMMY_API_KEY"

struct DailyTarotView: View {
    @ObservedObject var viewModel = TarotViewModel() // TarotViewModel'i kullanıyoruz
    @State private var selectedCard: TarotCard?
    @State private var isLoading = false
    @State private var gptMessage: String = ""
    @Binding var userInfo: UserInfo

    var body: some View {
        ZStack {
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.8)]),
                startPoint: .top,
                endPoint: .bottom
            )
            .edgesIgnoringSafeArea(.all)

            VStack(spacing: 20) {
                Text("🎴 Günlük Tarot Kartını Seç")
                    .font(.custom("Papyrus", size: 28))
                    .foregroundColor(.white)
                    .shadow(color: .purple, radius: 5)

                if selectedCard == nil {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 15) {
                            ForEach(viewModel.tarotCards) { card in
                                TarotCardView(
                                    card: card,
                                    isSelected: false,
                                    onTap: {
                                        selectCard(card)
                                    }
                                )
                                .frame(width: 120, height: 180)
                            }
                        }
                        .padding(.horizontal)
                    }
                } else if let card = selectedCard {
                    VStack(spacing: 20) {
                        TarotCardView(
                            card: card,
                            isSelected: true,
                            onTap: {}
                        )
                        .frame(width: 200, height: 300)

                        if isLoading {
                            ProgressView("Gunluk Faliniz Yukleniyor...")
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text(gptMessage)
                                .italic()
                                .padding()
                                .foregroundColor(.yellow)
                                .multilineTextAlignment(.center)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.black.opacity(0.6))
                                )
                                .padding(.horizontal)
                        }
                    }
                    .transition(.opacity)
                }
            }
            .padding()
        }
    }

    private func selectCard(_ card: TarotCard) {
        withAnimation {
            selectedCard = card
        }
        fetchGPTMessage(for: card)
    }

    private func fetchGPTMessage(for card: TarotCard) {
        isLoading = true
        let prompt = """
        Bugün bir tarot kartı seçildi: \(card.name).Bu bir gunluk kart acilimi. Bu kartın anlamını kullanıcıya pozitif, rehberlik edici ve motive edici bir şekilde açıklayın. Emojilerle bol bol destekle. Maksimum 3 cumle uzunlugunda olsun.
        """

        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "system", "content": "You are a helpful tarot card reader."],
                ["role": "user", "content": prompt]
            ],
            "max_tokens": 2000
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: requestBody)

        URLSession.shared.dataTask(with: request) { data, _, _ in
            if let data = data,
               let response = try? JSONDecoder().decode(OpenAIResponse.self, from: data),
               let message = response.choices.first?.message.content {
                DispatchQueue.main.async {
                    self.gptMessage = message
                    self.isLoading = false
                }
            } else {
                DispatchQueue.main.async {
                    self.gptMessage = "Mesaj alınamadı. Lütfen tekrar deneyin."
                    self.isLoading = false
                }
            }
        }.resume()
    }
}
