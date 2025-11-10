import SwiftUI
import FirebaseFirestore



struct ContentView: View {
    @AppStorage("isLoggedIn") private var isLoggedIn: Bool = false
    @StateObject private var viewModel = TarotViewModel()
    @State private var userInfo: UserInfo? = nil
    @State private var isFetchingUserInfo = false  // ✅ Prevent multiple fetches

    var body: some View {
        Group {
            if !isLoggedIn {
                LoginView(
                    isLoggedIn: $isLoggedIn,
                    userInfo: $userInfo,
                    onLogin: { username in
                        print("✅ Logged in as \(username)")
                        fetchUserInfo(username: username) // ✅ Fetch user info after login
                    }
                )
            } else if let user = userInfo {
                MainTarotView(viewModel: viewModel, userInfo: $userInfo, isLoggedIn: $isLoggedIn)
            } else {
                VStack {
                    ProgressView("Kullanıcı bilgileri yükleniyor...")
                        .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                }
            }
        }
        .onAppear {
            print("✅ ContentView appeared. isLoggedIn:", isLoggedIn)

            if isLoggedIn {
                if userInfo == nil {
                    print("🔄 Kullanıcı bilgileri geri yükleniyor...")
                    restoreUserInfo()
                } else {
                    print("✅ UserInfo zaten mevcut: \(userInfo!.birthDate)")
                }
            }
            if userInfo == nil {
                        print("🔄 Fetching user info on app launch...")
                viewModel.fetchUpdatedUserInfo()
                    }
        }
        
        
    }

    // ✅ Fetch user data from Firestore
    private func fetchUserInfo(username: String) {
        guard !isFetchingUserInfo else { return } // ✅ Prevent multiple calls
        isFetchingUserInfo = true

        let db = Firestore.firestore()
        db.collection("users").document(username).getDocument { document, error in
            self.isFetchingUserInfo = false  // ✅ Reset flag after fetching

            if let error = error {
                print("❌ Kullanıcı verisi alınamadı: \(error.localizedDescription)")
                return
            }

            if let document = document, document.exists, let data = document.data() {
                let user = parseUserData(username: username, data: data)
                DispatchQueue.main.async {
                    self.userInfo = user
                    self.viewModel.userInfo = user
                    saveUserToDefaults(user)
                    print("✅ Kullanıcı bilgileri başarıyla yüklendi.")
                }
            } else {
                print("❌ Kullanıcı bilgileri bulunamadı!")
            }
        }
    }



    // ✅ Parse user data from Firestore
    private func parseUserData(username: String, data: [String: Any]) -> UserInfo {
        let birthDate: Date = (data["birthDate"] as? Timestamp)?.dateValue() ?? Date()
        let tarotHistory = (data["tarotHistory"] as? [[String: Any]])?.compactMap(parseTarotReading) ?? []
        let questionHistory = (data["questionHistory"] as? [[String: Any]])?.compactMap(parseQuestionHistory) ?? []

        return UserInfo(
            username: username,
            password: data["password"] as? String ?? "",
            name: data["name"] as? String ?? "Yeni Kullanıcı",
            birthDate: birthDate,
            favoriteCategory: data["favoriteCategory"] as? String ?? "Genel",
            relationshipStatus: data["relationshipStatus"] as? String ?? "Belirtilmemiş",
            workStatus: data["workStatus"] as? String ?? "Belirtilmemiş",
            tarotHistory: tarotHistory,
            questionHistory: questionHistory
        )
    }

    // ✅ Parse Tarot Reading from Firestore
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

    // ✅ Parse Question History from Firestore
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

    // ✅ Save User Info Locally
    private func saveUserToDefaults(_ user: UserInfo) {
        let encoder = JSONEncoder()
        if let encoded = try? encoder.encode(user) {
            UserDefaults.standard.set(encoded, forKey: "savedUserInfo")
            print("✅ Kullanıcı bilgileri UserDefaults'a kaydedildi.")
        }
    }

    // ✅ Restore User Info from Local Storage
    private func restoreUserInfo() {
        if let savedUserData = UserDefaults.standard.data(forKey: "savedUserInfo") {
            let decoder = JSONDecoder()
            if let loadedUser = try? decoder.decode(UserInfo.self, from: savedUserData) {
                DispatchQueue.main.async {
                    self.userInfo = loadedUser
                    print("✅ Kullanıcı bilgileri geri yüklendi: \(loadedUser.birthDate)")
                }
            }
        } else {
            print("⚠️ UserDefaults'ta kullanıcı bilgisi bulunamadı.")
        }
    }

    // ✅ Properly handle logout
    private func logout() {
        print("✅ User logging out...")

        // ✅ Clear stored user data
        isLoggedIn = false
        userInfo = nil
        UserDefaults.standard.removeObject(forKey: "savedUserInfo")

        // ✅ Reset the ViewModel to clear tarot readings
        viewModel.selectedCards = []
        viewModel.overallReading = ""
        viewModel.tarotCards = []
        viewModel.isLoading = false
        viewModel.flippedCards = []
        viewModel.selectedCategory = "Genel"
        
        print("✅ All user data and tarot state reset!")
    }
}




struct MainTarotView: View {
    @ObservedObject var viewModel: TarotViewModel
    @Binding var userInfo: UserInfo?
    @Binding var isLoggedIn: Bool
    @State private var isSidebarVisible: Bool = false
    @State private var showAlert: Bool = false
    @State private var isSaved: Bool = false
    private let categories = ["Genel", "Aşk", "Kariyer", "Sağlık"]

    var body: some View {
        
        ZStack(alignment: .top) {
            
            // Background
            LinearGradient(
                gradient: Gradient(colors: [Color.black, Color.purple.opacity(0.9)]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .edgesIgnoringSafeArea(.all)

            VStack {
                // Header
                HStack {
                    // Sidebar Button
                    Button(action: {
                        if userInfo == nil {
                            showAlert = true
                        } else {
                            withAnimation { isSidebarVisible.toggle() }
                        }
                    }) {
                        Image(systemName: "line.horizontal.3")
                            .font(.title)
                            .foregroundColor(.white)
                            .padding(10)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.2))
                            )
                            .shadow(color: .purple.opacity(0.6), radius: 8)
                    }
                    .padding(.leading)

                    Spacer()

                    // Title
                    Text("✨ Tarot Falı ✨")
                        .font(Font.custom("Didot", size: 28)) // Professional font
                        .foregroundColor(.yellow)
                        .shadow(color: .purple.opacity(0.7), radius: 8)
                        .padding()
                        .background(
                            LinearGradient(
                                gradient: Gradient(colors: [Color.black.opacity(0.7), Color.purple.opacity(0.8)]),
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                            .clipShape(Capsule()) // Add rounded capsule shape
                        )

                    Spacer()

            
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.8), Color.purple]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .edgesIgnoringSafeArea(.top)
                )
                .cornerRadius(16) // Rounded edges for a modern look
                .shadow(color: .black.opacity(0.7), radius: 10, y: 5)

                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.purple.opacity(0.9))
                        .shadow(color: .black.opacity(0.8), radius: 10)
                )
                .padding(.horizontal, 10)

                // Category Picker
                VStack {
                    Text("Kategori Seçin:")
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding(.top, 10)

                    Picker("Kategori", selection: $viewModel.selectedCategory) {
                        ForEach(categories, id: \.self) { category in
                            Text(category).tag(category)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .padding(.horizontal)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.2))
                    )
                    .padding(.bottom, 10)
                }
                VStack {
                    // ✅ SEÇİLEN KARTLAR ÜSTTE GÖZÜKECEK
                    if viewModel.selectedCards.count > 0 {
                        VStack {
                        
                            
                            HStack(spacing: 10) {
                                VStack {
                                    if viewModel.selectedCards.count > 1 {
                                        TarotCardView(card: viewModel.selectedCards[1], isSelected: true, onTap: {})
                                            .transition(.move(edge: .top)) // 🔥 Animasyonlu geçiş
                                    }
                                    if viewModel.selectedCards.count > 2 {
                                        TarotCardView(card: viewModel.selectedCards[2], isSelected: true, onTap: {})
                                            .transition(.move(edge: .top))
                                    }
                                    if viewModel.selectedCards.count > 3 {
                                        TarotCardView(card: viewModel.selectedCards[3], isSelected: true, onTap: {})
                                            .transition(.move(edge: .top))
                                    }
                                }
                                
                                if viewModel.selectedCards.count > 0 {
                                    TarotCardView(card: viewModel.selectedCards[0], isSelected: true, onTap: {})
                                        .scaleEffect(0.8) // 🔥 Orta kart büyük görünecek
                                        .padding(.horizontal, 10)
                                        .transition(.move(edge: .top))
                                }
                                
                                VStack {
                                    if viewModel.selectedCards.count > 4 {
                                        TarotCardView(card: viewModel.selectedCards[4], isSelected: true, onTap: {})
                                            .transition(.move(edge: .top))
                                    }
                                    if viewModel.selectedCards.count > 5 {
                                        TarotCardView(card: viewModel.selectedCards[5], isSelected: true, onTap: {})
                                            .transition(.move(edge: .top))
                                    }
                                    if viewModel.selectedCards.count > 6 {
                                        TarotCardView(card: viewModel.selectedCards[6], isSelected: true, onTap: {})
                                            .transition(.move(edge: .top))
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .animation(.easeInOut(duration: 0.5), value: viewModel.selectedCards.map { $0.id })
                        
                    }
                    
                    Spacer()
                    if viewModel.selectedCards.count < 7 {
                        Text("Lütfen 7 kart seçiniz ✨")
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding(.bottom, 10)
                        // ✅ DESTE ALTTA GÖZÜKECEK (ÜST ÜSTE BİNDİRME)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: -40) { // 🔥 Kartları üst üste biraz bindiriyoruz
                                ForEach(viewModel.tarotCards) { card in
                                    TarotCardView(
                                        card: card,
                                        isSelected: false,
                                        onTap: {
                                            if userInfo == nil {
                                                showAlert = true
                                            } else {
                                                withAnimation {
                                                    viewModel.selectCard(card)
                                                }
                                            }
                                        }
                                    )
                                    .frame(width: 100, height: 170)
                                    .transition(.move(edge: .bottom)) // 🔥 Seçilen kart yukarı kayıyor
                                }
                            }
                            .padding(.bottom, 30) // ✅ Kart destesi ekranın altına alındı
                        }
                    }
                }
                // Card Selection
               

                if viewModel.isLoading {
                    VStack {
                        ProgressView("Fal Yükleniyor... 🔮")
                            .progressViewStyle(CircularProgressViewStyle(tint: .yellow))
                            .font(.headline)
                            .foregroundColor(.white)
                            .padding()
                            
                            .padding(.horizontal, 20)
                        
                        Text("Mistisizmin gücünü çağırıyoruz... 🪄✨")
                            .foregroundColor(.white)
                            .font(.subheadline)
                            .padding(.top, 5)
                    }
                    .padding()
                }
                // Tarot Reading Display
                else if !viewModel.overallReading.isEmpty {
                    ScrollView {
                        Text(viewModel.overallReading)
                            .font(.body)
                            .foregroundColor(.yellow)
                            .padding()
                            .multilineTextAlignment(.center)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.black.opacity(0.8))
                                    .shadow(color: .purple.opacity(0.5), radius: 10)
                            )
                            .padding(.horizontal, 20)
                    }
                    .frame(maxHeight: 500) // Increased height for readability

                    // Action Buttons
                    VStack(spacing: 10) { // Daha az boşluk bırakmak için spacing küçültüldü
                        // Save Button
                        Button(action: saveReading) {
                            HStack {
                                Image(systemName: "bookmark.circle.fill")
                                    .font(.headline) // 🔹 Daha küçük font
                                Text(isSaved ? "Kaydedildi ✅" : "Açılımı Kaydet")
                                    .font(.subheadline) // 🔹 Daha küçük font
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(8) // 🔹 Padding küçültüldü
                            .frame(width: 180, height: 40) // 🔹 Sabit boyut verildi
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.blue.opacity(0.8), Color.purple]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8) // 🔹 Köşe yuvarlatma küçültüldü
                            .shadow(color: .blue.opacity(0.5), radius: 5) // 🔹 Gölge küçültüldü
                        }
                        .disabled(isSaved)

                        // Reset Button
                        Button(action: {
                            viewModel.resetSelections()
                            isSaved = false
                        }) {
                            HStack {
                                Image(systemName: "arrow.clockwise.circle.fill")
                                    .font(.headline) // 🔹 Daha küçük font
                                Text("Yeniden Başlat")
                                    .font(.subheadline) // 🔹 Daha küçük font
                                    .fontWeight(.bold)
                            }
                            .foregroundColor(.white)
                            .padding(8) // 🔹 Padding küçültüldü
                            .frame(width: 180, height: 40) // 🔹 Sabit boyut verildi
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [Color.purple.opacity(0.8), Color.black]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .cornerRadius(8) // 🔹 Köşe yuvarlatma küçültüldü
                            .shadow(color: .purple.opacity(0.5), radius: 5) // 🔹 Gölge küçültüldü
                        }
                    }

                    .padding(.horizontal, 20)
                    .padding(.top, 20)
                }

                Spacer()
            }
            .padding()

            // Sidebar
            if isSidebarVisible {
                SidebarView(isVisible: $isSidebarVisible, userInfo: $userInfo, isLoggedIn: $isLoggedIn)
            }
        }
        .onAppear {
            if viewModel.tarotCards.isEmpty {
                print("🔄 Reloading tarot cards after app reopened")
                viewModel.loadTarotData()
            }
            
            viewModel.isLoading = false // Reset loading state after app reopens
            
            if viewModel.selectedCards.count == 7 {
                print("🔄 Re-triggering tarot reading after app reopens")
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    viewModel.generateOverallReading(userInfo: userInfo)
                }
            }
        }

        .onAppear {
            if !viewModel.isFetchingUserInfo && viewModel.userInfo == nil {
                viewModel.fetchUpdatedUserInfo()  // ✅ Call from ViewModel
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("UserProfileUpdated"))) { _ in
            if !viewModel.isFetchingUserInfo {
                viewModel.fetchUpdatedUserInfo()
            }
        }

        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("Bilgi Eksik!"),
                message: Text("Devam etmek için önce profil bilgilerinizi girmelisiniz."),
                dismissButton: .default(Text("Tamam"))
            )
        }
    }
  
    



    private func logout() {
        print("✅ User logging out...")

        // ✅ Clear stored user data
        isLoggedIn = false
        userInfo = nil
        UserDefaults.standard.removeObject(forKey: "savedUserInfo")

        // ✅ Reset the ViewModel to clear tarot readings
        viewModel.selectedCards = []
        viewModel.overallReading = ""
        viewModel.tarotCards = []
        viewModel.isLoading = false
        viewModel.flippedCards = []
        viewModel.selectedCategory = "Genel"
        
        print("✅ All user data and tarot state reset!")
    }



    private func saveReading() {
        guard let user = userInfo else { return }
        let newReading = TarotReading(
            date: Date(),
            reading: viewModel.overallReading,
            category: viewModel.selectedCategory
        )

        var updatedUserInfo = user
        updatedUserInfo.tarotHistory.append(newReading)

        let db = Firestore.firestore()
        do {
            let tarotHistoryData = try updatedUserInfo.tarotHistory.map { tarot -> [String: Any] in
                var dict = try JSONSerialization.jsonObject(with: JSONEncoder().encode(tarot)) as! [String: Any]
                return dict
            }

            let userData: [String: Any] = [
                "username": updatedUserInfo.username,
                "tarotHistory": tarotHistoryData
            ]

            db.collection("users").document(updatedUserInfo.username).updateData(userData) { error in
                if let error = error {
                    print("❌ Fal kaydedilemedi: \(error.localizedDescription)")
                } else {
                    print("✅ Fal başarıyla kaydedildi.")
                    DispatchQueue.main.async {
                        userInfo = updatedUserInfo
                        isSaved = true // Mark as saved
                    }
                }
            }
        } catch {
            print("❌ JSON dönüşüm hatası: \(error.localizedDescription)")
        }
    }
}

struct SidebarView: View {
    @Binding var isVisible: Bool
    @Binding var userInfo: UserInfo? // Opsiyonel olarak tanımlı
    @Binding var isLoggedIn: Bool
    @State private var showingProfile = false
    @State private var showingAskTarot = false
    @State private var showingHistory = false
    @State private var showingDailyTarot = false
    @StateObject private var viewModel = TarotViewModel()
    var body: some View {
        ZStack(alignment: .leading) {
            // Background dim effect
            Color.black.opacity(isVisible ? 0.4 : 0)
                .edgesIgnoringSafeArea(.all)
                .onTapGesture {
                    withAnimation { isVisible = false }
                }

            // Sidebar
            VStack(alignment: .leading, spacing: 25) {
                // Header
                Text("🔮Menu")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .shadow(color: .purple.opacity(0.8), radius: 5, x: 0, y: 5)
                    .padding(.top, 50)

                // Profil Butonu
                CustomSidebarButton(
                    title: "👤 Profil",
                    gradientColors: [Color.purple, Color.blue],
                    action: { showingProfile = true }
                )
                .sheet(isPresented: $showingProfile) {
                    if let userInfo = userInfo {
                        ProfileView(
                            userInfo: Binding(
                                get: { userInfo },
                                set: { newValue in self.userInfo = newValue }
                            ),
                            isLoggedIn: $isLoggedIn
                        )
                    } else {
                        Text("Kullanıcı bilgisi mevcut değil!")
                            .foregroundColor(.red)
                    }
                }

                // Eğer kullanıcı bilgileri varsa diğer seçenekler gösterilir
                if let userInfo = userInfo {
                    CustomSidebarButton(
                        title: "❓ Sorunu Sor",
                        gradientColors: [Color.purple, Color.orange],
                        action: { showingAskTarot = true }
                    )
                    .sheet(isPresented: $showingAskTarot) {
                        AskTarotView(
                            questionHistory: Binding(
                                get: { userInfo.questionHistory },
                                set: { newValue in self.userInfo?.questionHistory = newValue }
                            ),
                            userInfo: Binding(
                                get: { userInfo },
                                set: { newValue in self.userInfo = newValue }
                            )
                        )
                    }

                    CustomSidebarButton(
                        title: "📜 Geçmiş Açılımlar",
                        gradientColors: [Color.pink, Color.purple],
                        action: { showingHistory = true }
                    )
                    .sheet(isPresented: $showingHistory) {
                        HistoryView(viewModel: viewModel)
                    }

                    CustomSidebarButton(
                        title: "🎴 Günlük Tarot",
                        gradientColors: [Color.red, Color.purple],
                        action: { showingDailyTarot = true }
                    )
                    .sheet(isPresented: $showingDailyTarot) {
                        DailyTarotView(
                            userInfo: Binding(
                                get: { self.userInfo! }, // Kullanıcı bilgisi her zaman var olmalıdır
                                set: { newValue in self.userInfo = newValue }
                            )
                        )
                    }

                }

                // Çıkış Butonu
                CustomSidebarButton(
                    title: "🚪 Cikis",
                    gradientColors: [Color.red, Color.black],
                    action: {
                        isLoggedIn = false
                        userInfo = nil
                    }
                )

                Spacer()
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .frame(width: UIScreen.main.bounds.width * 0.6, height: UIScreen.main.bounds.height) // Full height
            .background(
                LinearGradient(
                    gradient: Gradient(colors: [Color.black, Color.purple]),
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .edgesIgnoringSafeArea(.all)
            .shadow(color: .black, radius: 10, x: 5, y: 5)
            .offset(x: isVisible ? 0 : -UIScreen.main.bounds.width * 0.8) // Slide animation
            .animation(.easeInOut(duration: 0.3))
        }
    }
}




struct TarotHeaderView: View {
    var body: some View {
        VStack {
            Text("🔮 Tarot Falı")
                .font(Font.custom("Papyrus", size: 30))
                .foregroundColor(.yellow)
                .shadow(color: .purple.opacity(0.8), radius: 10, x: 0, y: 5)
                .padding(.top, 20)
            Text("Geleceğinizi keşfetmek için 7 kart seçin")
                .font(.headline)
                .foregroundColor(.white)
                .padding(.bottom, 20)
        }
    }
}


struct CustomSidebarButton: View {
    var title: String
    var gradientColors: [Color]
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .padding(.leading)
                Spacer()
            }
            .padding()
            .background(
                LinearGradient(
                    gradient: Gradient(colors: gradientColors),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(10)
            .shadow(color: .black.opacity(0.6), radius: 5, x: 2, y: 2)
        }
    }
}



struct TarotCardView: View {
    let card: TarotCard
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isFlipped = false
    @State private var isMovingToTop = false // ✅ State to track movement

    var body: some View {
        ZStack {
            if isSelected || isFlipped {
                Image(card.img)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
                    .shadow(color: .purple.opacity(0.7), radius: isSelected ? 10 : 5)
                    .scaleEffect(isSelected ? 1.1 : 1.0)
            } else {
                Image("card-back")
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(12)
            }
        }
        
        .offset(y: isMovingToTop ? -300 : 0) // ✅ Moves up smoothly
        .animation(.easeInOut(duration: 0.5), value: isMovingToTop)
        .onTapGesture {
            if !isSelected {
                withAnimation {
                    isFlipped.toggle()
                    isMovingToTop = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    onTap()
                }
            }
        }
    }
}



struct CustomTextField: View {
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
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

struct CustomSecureField: View {
    var title: String
    @Binding var text: String
    var icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.white)
            SecureField(title, text: $text)
                .foregroundColor(.white)
                .padding()
        }
        .background(Color.white.opacity(0.2))
        .cornerRadius(12)
        .padding(.horizontal)
    }
}

    
    // 🔹 **Özel Picker (Kategori, İlişki Durumu, İş Durumu Seçimi için)**
    struct CustomPicker: View {
        var title: String
        @Binding var selection: String
        var options: [String]
        
        var body: some View {
            VStack(alignment: .leading) {
                Text(title)
                    .foregroundColor(.white)
                    .font(.headline)
                Picker(title, selection: $selection) {
                    ForEach(options, id: \.self) { option in
                        Text(option).tag(option)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .padding()
                .background(Color.white.opacity(0.2))
                .cornerRadius(12)
            }
        }
    }
    

