import SwiftUI
import FirebaseFirestore
struct LoginView: View {
    @Binding var isLoggedIn: Bool
    @Binding var userInfo: UserInfo?
    var onLogin: (String) -> Void // Closure to handle login logic

    @State private var username: String = ""
    @State private var password: String = ""
    @State private var showError: Bool = false
    @State private var errorMessage: String = ""
    @State private var isPasswordVisible: Bool = false // Şifre görünürlüğü için state
    @State private var navigateToProfile: Bool = false // Profil ekranına yönlendirme kontrolü

    var body: some View {
        NavigationView {
            ZStack {
                // Mistik Arka Plan
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.purple]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .edgesIgnoringSafeArea(.all)

                VStack(spacing: 20) {
                    Text("🔑 Giriş Yap")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .shadow(color: .purple.opacity(0.7), radius: 5)

                    // Username Field
                    ZStack(alignment: .leading) {
                        HStack {
                            Image(systemName: "person.fill")
                                .foregroundColor(.white)
                                .padding(.leading, 8)
                            TextField("Kullanıcı Adı", text: $username)
                                .padding(.vertical, 12)
                                .foregroundColor(.white)
                        }
                        .padding(.leading, 4)
                    }
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )

                    // Password Field with Toggle Visibility
                    ZStack(alignment: .trailing) {
                        if isPasswordVisible {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white)
                                    .padding(.leading, 8)
                                TextField("Şifre", text: $password)
                                    .padding(.vertical, 12)
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 4)
                        } else {
                            HStack {
                                Image(systemName: "lock.fill")
                                    .foregroundColor(.white)
                                    .padding(.leading, 8)
                                SecureField("Şifre", text: $password)
                                    .padding(.vertical, 12)
                                    .foregroundColor(.white)
                            }
                            .padding(.leading, 4)
                        }

                        Button(action: {
                            isPasswordVisible.toggle()
                        }) {
                            Image(systemName: isPasswordVisible ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.white)
                                .padding(.trailing, 8)
                        }
                    }
                    .background(Color.white.opacity(0.2))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.5), lineWidth: 1)
                    )

                    // Login Button
                    GradientButton(
                        title: "Giriş Yap",
                        gradientColors: [Color.green, Color.blue],
                        action: handleLogin
                    )

                    if showError {
                        Text(errorMessage)
                            .foregroundColor(.red)
                            .multilineTextAlignment(.center)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.2))
                            )
                            .padding(.horizontal)
                    }

                    Divider()
                        .background(Color.white)

                    Text("Hesabınız yok mu? Aşağıdan kayıt olun!")
                        .foregroundColor(.white)

                    // Register Button
                    GradientButton(
                        title: "Kayıt Ol",
                        gradientColors: [Color.purple, Color.red],
                        action: registerUser
                    )

                    // NavigationLink to ProfileView
                    NavigationLink(
                        destination: ProfileView(userInfo: $userInfo, isLoggedIn: $isLoggedIn),
                        isActive: $navigateToProfile
                    ) {
                        EmptyView()
                    }
                }
                .padding()
                .frame(maxWidth: 400)
            }
        }
    }

    private func handleLogin() {
        guard !username.isEmpty, !password.isEmpty else {
            showError = true
            errorMessage = "Lütfen tüm alanları doldurun!"
            return
        }

        let db = Firestore.firestore()
        db.collection("users").document(username).getDocument { document, error in
            if let error = error {
                showError = true
                errorMessage = "Veritabanı hatası: \(error.localizedDescription)"
                return
            }

            if let document = document, document.exists, let data = document.data() {
                if let savedPassword = data["password"] as? String, savedPassword == password {
                    
                    // ✅ 1️⃣ Extract and Validate Birthdate
                    var birthDate: Date? = nil
                    if let timestamp = data["birthDate"] as? Timestamp {
                        birthDate = timestamp.dateValue()
                        print("✅ Correct Birthdate Loaded: \(birthDate!)")
                    } else {
                        print("❌ Birthdate missing in Firestore! Using default...")
                        birthDate = Date(timeIntervalSince1970: 0) // Avoid using Date()
                    }

                    // ✅ 2️⃣ Extract and Validate Tarot & Question History
                    let tarotHistory: [TarotReading] = (data["tarotHistory"] as? [[String: Any]])?.compactMap { dict in
                        guard let dateValue = dict["date"] as? Double,
                              let reading = dict["reading"] as? String,
                              let category = dict["category"] as? String,
                              let id = dict["id"] as? String else { return nil }
                        
                        return TarotReading(id: UUID(uuidString: id) ?? UUID(),
                                            date: Date(timeIntervalSince1970: dateValue),
                                            reading: reading,
                                            category: category)
                    } ?? []

                    let questionHistory: [QuestionHistoryEntry] = (data["questionHistory"] as? [[String: Any]])?.compactMap { dict in
                        guard let idString = dict["id"] as? String,
                              let question = dict["question"] as? String,
                              let reading = dict["reading"] as? String,
                              let dateValue = dict["date"] as? Double else { return nil }

                        return QuestionHistoryEntry(id: UUID(uuidString: idString) ?? UUID(),
                                                    question: question,
                                                    reading: reading,
                                                    date: Date(timeIntervalSince1970: dateValue))
                    } ?? []

                    // ✅ 3️⃣ Create UserInfo Object
                    let user = UserInfo(
                        username: username,
                        password: password,
                        name: data["name"] as? String ?? "Yeni Kullanıcı",
                        birthDate: birthDate!, // ✅ Ensure a valid date is set
                        favoriteCategory: data["favoriteCategory"] as? String ?? "Genel",
                        relationshipStatus: data["relationshipStatus"] as? String ?? "Belirtilmemiş",
                        workStatus: data["workStatus"] as? String ?? "Belirtilmemiş",
                        tarotHistory: tarotHistory,
                        questionHistory: questionHistory
                    )

                    DispatchQueue.main.async {
                        self.userInfo = user
                        print("✅ Final Birth Date after Login: \(user.birthDate)")
                        print("✅ Loaded Tarot History Count: \(user.tarotHistory.count)")
                        print("✅ Loaded Question History Count: \(user.questionHistory.count)")

                        if user.name == "Yeni Kullanıcı" {
                            navigateToProfile = true
                        } else {
                            isLoggedIn = true
                            onLogin(username)
                        }
                    }
                } else {
                    showError = true
                    errorMessage = "Hatalı kullanıcı adı veya şifre!"
                }
            } else {
                showError = true
                errorMessage = "Kullanıcı bulunamadı!"
            }
        }
    }







    private func registerUser() {
        guard !username.isEmpty, !password.isEmpty else {
            showError = true
            errorMessage = "Lütfen kullanıcı adı ve şifre girin!"
            return
        }

        let db = Firestore.firestore()
        let newUser = UserInfo(
            username: username,
            password: password,
            name: "Ad Soyad", // Varsayılan isim
            birthDate: Date(),
            favoriteCategory: "Genel",
            relationshipStatus: "Belirtilmemiş",
            workStatus: "Belirtilmemiş"
        )

        do {
            let data = try JSONEncoder().encode(newUser)
            if let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                db.collection("users").document(username).setData(json) { error in
                    if let error = error {
                        showError = true
                        errorMessage = "Kullanıcı kaydedilemedi: \(error.localizedDescription)"
                    } else {
                        self.userInfo = newUser
                        DispatchQueue.main.async {
                            navigateToProfile = true // ProfileView'e yönlendir
                        }
                    }
                }
            }
        } catch {
            showError = true
            errorMessage = "Kullanıcı verileri işlenemedi!"
        }
    }
}


struct GradientButton: View {
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
