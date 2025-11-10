import SwiftUI
import FirebaseFirestore

struct ProfileView: View {
    @Binding var userInfo: UserInfo?
    @Binding var isLoggedIn: Bool
    @StateObject private var viewModel = TarotViewModel()
    
    @State private var name: String = ""
    @State private var password: String = ""
    @State private var birthDate: Date = Date()
    @State private var favoriteCategory: String = "Genel"
    @State private var relationshipStatus: String = "Belirtilmemiş"
    @State private var workStatus: String = "Belirtilmemiş"
    @Environment(\.presentationMode) var presentationMode
    private let categories = ["Genel", "Aşk", "Kariyer", "Sağlık"]
    private let relationshipOptions = ["Belirtilmemiş", "Bekar", "İlişkide", "Evli"]
    private let workOptions = ["Belirtilmemiş", "Çalışıyor", "İşsiz", "Öğrenci"]
    
    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.8)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)
            
            ScrollView {
                VStack(spacing: 25) {
                    Text("Profil Bilgileri")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .purple.opacity(0.7), radius: 5)
                    
                    // Name Input
                    CustomTextField2(title: "Adınız", text: $name, icon: "person.fill")
                    
                    // Birthdate Picker
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Doğum Tarihi")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.leading, 10)
                        DatePicker("Doğum Tarihi", selection: $birthDate, displayedComponents: .date)
                            .labelsHidden()
                            .datePickerStyle(GraphicalDatePickerStyle())
                            .background(Color.white.opacity(0.2))
                            .cornerRadius(12)
                            .padding(.horizontal)
                            .onChange(of: birthDate) { newValue in
                                userInfo?.birthDate = newValue
                            }
                    }
                    
                    // Favorite Category Picker
                    CustomPicker2(title: "Favori Kategori", selection: $favoriteCategory, options: categories)
                    
                    // Relationship Status Picker
                    CustomPicker2(title: "İlişki Durumu", selection: $relationshipStatus, options: relationshipOptions)
                    
                    // Work Status Picker
                    CustomPicker2(title: "Çalışma Durumu", selection: $workStatus, options: workOptions)
                    
                    // **Dynamic Button**
                    if userInfo == nil {
                        GradientButton2(
                            title: "Kaydet",
                            gradientColors: [Color.green, Color.blue],
                            action: saveProfile
                        )
                    } else {
                        GradientButton2(
                            title: "Güncelle",
                            gradientColors: [Color.orange, Color.purple],
                            action: updateProfile
                        )
                    }
                }
                .padding()
            }
        }
        .onAppear {
            if let user = userInfo {
                name = user.name
                birthDate = user.birthDate
                favoriteCategory = user.favoriteCategory
                relationshipStatus = user.relationshipStatus
                workStatus = user.workStatus
            }
        }
    }
    /// **✅ Determines whether to save or update the profile**
        private func saveOrUpdateProfile() {
            if userInfo == nil {
                saveProfile()
            } else {
                updateProfile()
            }
        }
    /// **🔹 Save profile for first-time users**
    private func saveProfile() {
        guard userInfo == nil else { return } // Prevent duplicate saving
        
        let newUser = UserInfo(
            username: name.lowercased(),
            password: password,
            name: name,
            birthDate: birthDate,
            favoriteCategory: favoriteCategory,
            relationshipStatus: relationshipStatus,
            workStatus: workStatus
        )

        let db = Firestore.firestore()
        do {
            var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(newUser)) as! [String: Any]
            json["birthDate"] = Timestamp(date: birthDate) // Convert Date to Firestore Timestamp

            db.collection("users").document(newUser.username).setData(json) { error in
                if let error = error {
                    print("❌ Profil kaydedilemedi: \(error.localizedDescription)")
                } else {
                    print("✅ Profil başarıyla kaydedildi.")
                    DispatchQueue.main.async {
                        userInfo = newUser
                        isLoggedIn = true
                        self.refreshMainScreen()
                    }
                }
            }
        } catch {
            print("❌ JSON dönüşüm hatası: \(error.localizedDescription)")
        }
    }

    /// **🔹 Update existing profile**
    private func updateProfile() {
        guard let user = userInfo else { return }

        let db = Firestore.firestore()
        let updatedData: [String: Any] = [
            "name": name,
            "birthDate": Timestamp(date: birthDate),
            "favoriteCategory": favoriteCategory,
            "relationshipStatus": relationshipStatus,
            "workStatus": workStatus
        ]

        db.collection("users").document(user.username).updateData(updatedData) { error in
            if let error = error {
                print("❌ Profil güncellenirken hata oluştu: \(error.localizedDescription)")
            } else {
                print("✅ Profil başarıyla güncellendi, en güncel veriyi çekiyoruz...")

                DispatchQueue.main.async {
                    self.userInfo?.name = name
                    self.userInfo?.birthDate = birthDate
                    self.userInfo?.favoriteCategory = favoriteCategory
                    self.userInfo?.relationshipStatus = relationshipStatus
                    self.userInfo?.workStatus = workStatus
                    
                    // ✅ Notify MainTarotView that the profile is updated
                    NotificationCenter.default.post(name: NSNotification.Name("UserProfileUpdated"), object: nil)

                    self.presentationMode.wrappedValue.dismiss()  // ✅ Auto-return to main screen
                }
            }
        }
    }


    /// **🔹 Fetch latest user info from Firestore**
    private func fetchUpdatedUserInfo() {
        guard let username = userInfo?.username else { return }

        let db = Firestore.firestore()
        db.collection("users").document(username).getDocument { document, error in
            if let error = error {
                print("❌ Kullanıcı bilgileri çekilemedi: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists, let data = document.data() {
                DispatchQueue.main.async {
                    if let birthDateTimestamp = data["birthDate"] as? Timestamp {
                        self.userInfo?.birthDate = birthDateTimestamp.dateValue()
                    }

                    self.userInfo?.name = data["name"] as? String ?? "Yeni Kullanıcı"
                    self.userInfo?.favoriteCategory = data["favoriteCategory"] as? String ?? "Genel"
                    self.userInfo?.relationshipStatus = data["relationshipStatus"] as? String ?? "Belirtilmemiş"
                    self.userInfo?.workStatus = data["workStatus"] as? String ?? "Belirtilmemiş"
                    
                    print("✅ Kullanıcı bilgileri güncellendi! Yeni Doğum Günü: \(self.userInfo?.birthDate ?? Date())")
                    self.refreshMainScreen()
                }
            } else {
                print("❌ Kullanıcı bilgileri Firestore'da bulunamadı!")
            }
        }
    }
    /// **🔄 Automatically return to main screen & refresh tarot data**
        private func refreshMainScreen() {
            self.presentationMode.wrappedValue.dismiss()
            NotificationCenter.default.post(name: NSNotification.Name("UserProfileUpdated"), object: nil)
        }
}

struct CustomTextField2: View {
    var title: String
    @Binding var text: String
    var icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
            TextField(title, text: $text)
                .foregroundColor(.white)
                .padding()
        }
        .padding()
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.5), lineWidth: 1)
        )
        .padding(.horizontal)
    }
}

struct CustomPicker2: View {
    var title: String
    @Binding var selection: String
    var options: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .padding(.leading, 10)
            Picker(title, selection: $selection) {
                ForEach(options, id: \.self) { option in
                    Text(option).tag(option)
                }
            }
            .pickerStyle(MenuPickerStyle())
            .padding()
            .background(Color.white.opacity(0.2))
            .cornerRadius(12)
            .padding(.horizontal)
        }
    }
}

struct GradientButton2: View {
    var title: String
    var gradientColors: [Color]
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: gradientColors),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .black.opacity(0.4), radius: 5, x: 2, y: 2)
        }
    }
}
