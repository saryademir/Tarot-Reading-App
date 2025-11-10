//
//  HistoryView.swift
//  TarotReadingApp
//
//  Created by Sarya Demir on 08/02/2025.
//

import FirebaseFirestore
import SwiftUI

struct HistoryView: View {
    @ObservedObject var viewModel: TarotViewModel
    @State private var selectedTab: String = "Fallar"

    var body: some View {
        VStack {
            Text("📜 Geçmiş Açılımlar ve Sorular")
                .font(.custom("Papyrus", size: 28))
                .foregroundColor(.white)
                .shadow(color: .purple, radius: 5)
                .padding(.top)

            Picker("", selection: $selectedTab) {
                Text("Fallar").tag("Fallar")
                Text("Sorular").tag("Sorular")
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding()

            ScrollView {
                if selectedTab == "Fallar" {
                    TarotHistoryView(viewModel: viewModel)
                } else {
                    QuestionHistoryView(viewModel: viewModel)
                }
            }
        }
        .background(LinearGradient(
            gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.8)]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .edgesIgnoringSafeArea(.all))
        .onAppear {
            print("📥 HistoryView açıldı, Firestore'dan veriler çekiliyor...")
            viewModel.fetchUserData() // ✅ Ekran açıldığında Firestore’dan verileri çek
        }
    }
}



// MARK: - Tarot History View
struct TarotHistoryView: View {
    @ObservedObject var viewModel: TarotViewModel

    var body: some View {
        VStack {
            if let readings = viewModel.userInfo?.tarotHistory, !readings.isEmpty {
                ForEach(readings) { reading in
                    TarotReadingCard(
                        reading: reading,
                        onDelete: { deleteReading(reading) }
                    )
                }
            } else {
                EmptyStateView(message: "📭 Henüz tarot açılımı kaydedilmedi.")
            }
        }
    }

    private func deleteReading(_ reading: TarotReading) {
            guard var user = viewModel.userInfo else { return }
            user.tarotHistory.removeAll { $0.id == reading.id }
            viewModel.userInfo = user

            let db = Firestore.firestore()
            do {
                let tarotHistoryData = try user.tarotHistory.map { tarot in
                    return try JSONSerialization.jsonObject(with: JSONEncoder().encode(tarot))
                }

                db.collection("users").document(user.username).updateData([
                    "tarotHistory": tarotHistoryData
                ]) { error in
                    if let error = error {
                        print("❌ Açılım silinirken hata oluştu: \(error.localizedDescription)")
                    } else {
                        print("✅ Açılım başarıyla silindi.")
                    }
                }
            } catch {
                print("❌ JSON formatına çevrilemedi: \(error.localizedDescription)")
            }
        }
}

// MARK: - Question History View
struct QuestionHistoryView: View {
    @ObservedObject var viewModel: TarotViewModel

    var body: some View {
        VStack {
            if let questions = viewModel.userInfo?.questionHistory, !questions.isEmpty {
                ForEach(questions, id: \.id) { question in
                    QuestionCard(
                        question: question,
                        onDelete: { deleteQuestion(question) }
                    )
                }
            } else {
                EmptyStateView(message: "📭 Henüz kaydedilmiş soru yok.")
            }
        }
        .onAppear {
            print("🔄 QuestionHistoryView açıldı, Firestore’dan verileri çekiyoruz...")
            viewModel.fetchUpdatedUserInfo() // ✅ ViewModel’den güncelle
        }
    }

    private func deleteQuestion(_ question: QuestionHistoryEntry) {
        guard var user = viewModel.userInfo else { return }
        user.questionHistory.removeAll { $0.id == question.id }
        viewModel.userInfo = user

        let db = Firestore.firestore()
        do {
            let encodedHistory = try JSONEncoder().encode(user.questionHistory)
            let questionHistoryArray = try JSONSerialization.jsonObject(with: encodedHistory) as! [[String: Any]]

            db.collection("users").document(user.username).updateData([
                "questionHistory": questionHistoryArray
            ]) { error in
                if let error = error {
                    print("❌ Firebase silme hatası: \(error.localizedDescription)")
                } else {
                    print("✅ Soru başarıyla silindi.")
                }
            }
        } catch {
            print("❌ JSON Encoding Hatası: \(error.localizedDescription)")
        }
    }
}



// MARK: - Common Card UI
struct TarotReadingCard: View {
    var reading: TarotReading
    var onDelete: () -> Void

    var body: some View {
        HistoryCardView(
            title: "🃏 Kategori: \(reading.category)",
            content: reading.reading,
            date: reading.date,
            onDelete: onDelete
        )
    }
}

struct QuestionCard: View {
    var question: QuestionHistoryEntry
    var onDelete: () -> Void

    var body: some View {
        HistoryCardView(
            title: "❓ Soru: \(question.question)",
            content: "🔮 Yanıt: \(question.reading)",
            date: question.date,
            onDelete: onDelete
        )
    }
}

// MARK: - Generic History Card UI
struct HistoryCardView: View {
    var title: String
    var content: String
    var date: Date
    var onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("📅 \(date, formatter: dateFormatter)")
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Button(action: onDelete) {
                    Image(systemName: "trash.circle.fill")
                        .foregroundColor(.red)
                        .font(.title2)
                }
            }

            Text(title)
                .font(.subheadline)
                .foregroundColor(.white)

            Text(content)
                .padding()
                .foregroundColor(.white)
                .background(RoundedRectangle(cornerRadius: 12).fill(Color.purple.opacity(0.5)))
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.white.opacity(0.1)))
        .shadow(radius: 5)
        .transition(.slide)
    }
}

// MARK: - Empty State View
struct EmptyStateView: View {
    var message: String

    var body: some View {
        Text(message)
            .foregroundColor(.gray)
            .italic()
            .padding()
    }
}

// MARK: - Date Formatter
private let dateFormatter: DateFormatter = {
    let formatter = DateFormatter()
    formatter.dateFormat = "dd MMM yyyy"
    formatter.timeZone = TimeZone(identifier: "UTC") // ✅ Ensure consistent timezone
    return formatter
}()

