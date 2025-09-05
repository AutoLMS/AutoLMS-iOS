import SwiftUI

struct LoginView: View {
    @EnvironmentObject private var authManager: AuthenticationManager
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    
    @State private var studentID = ""
    @State private var password = ""
    @State private var showPassword = false
    @FocusState private var focusedField: Field?
    
    enum Field: Hashable {
        case studentID, password
    }
    
    var body: some View {
        GeometryReader { geometry in
            if horizontalSizeClass == .regular {
                // iPad Layout
                iPadLayout(geometry: geometry)
            } else {
                // iPhone Layout
                iPhoneLayout(geometry: geometry)
            }
        }
        .background(
            LinearGradient(
                colors: [Color.blue.opacity(0.1), Color.purple.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
        )
    }
    
    // MARK: - iPad Layout
    
    @ViewBuilder
    private func iPadLayout(geometry: GeometryProxy) -> some View {
        HStack(spacing: 0) {
            // Left side - Branding
            VStack {
                brandingSection
                Spacer()
            }
            .frame(maxWidth: geometry.size.width * 0.5)
            .padding()
            
            // Right side - Login form
            VStack {
                Spacer()
                loginForm
                    .frame(maxWidth: 400)
                Spacer()
            }
            .frame(maxWidth: geometry.size.width * 0.5)
            .padding()
        }
    }
    
    // MARK: - iPhone Layout
    
    @ViewBuilder
    private func iPhoneLayout(geometry: GeometryProxy) -> some View {
        ScrollView {
            VStack(spacing: 40) {
                Spacer(minLength: 60)
                
                brandingSection
                
                loginForm
                    .padding(.horizontal, 24)
                
                Spacer(minLength: 40)
            }
        }
    }
    
    // MARK: - Branding Section
    
    @ViewBuilder
    private var brandingSection: some View {
        VStack(spacing: 20) {
            // App Icon/Logo
            Image(systemName: "graduationcap.fill")
                .font(.system(size: horizontalSizeClass == .regular ? 80 : 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            
            VStack(spacing: 8) {
                Text("AutoLMS")
                    .font(horizontalSizeClass == .regular ? .largeTitle : .title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                
                Text("서울과기대 강의자료 자동 동기화")
                    .font(horizontalSizeClass == .regular ? .title2 : .headline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
    
    // MARK: - Login Form
    
    @ViewBuilder
    private var loginForm: some View {
        VStack(spacing: 24) {
            VStack(spacing: 16) {
                // Student ID Field
                VStack(alignment: .leading, spacing: 8) {
                    Label("학번", systemImage: "person.fill")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("학번을 입력하세요", text: $studentID)
                        .textFieldStyle(CustomTextFieldStyle())
                        .keyboardType(.numberPad)
                        .focused($focusedField, equals: .studentID)
                        .submitLabel(.next)
                        .onSubmit {
                            focusedField = .password
                        }
                }
                
                // Password Field
                VStack(alignment: .leading, spacing: 8) {
                    Label("e-Class 비밀번호", systemImage: "lock.fill")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    HStack {
                        Group {
                            if showPassword {
                                TextField("비밀번호를 입력하세요", text: $password)
                            } else {
                                SecureField("비밀번호를 입력하세요", text: $password)
                            }
                        }
                        .focused($focusedField, equals: .password)
                        .submitLabel(.done)
                        .onSubmit {
                            Task {
                                await handleLogin()
                            }
                        }
                        
                        Button(action: { showPassword.toggle() }) {
                            Image(systemName: showPassword ? "eye.slash.fill" : "eye.fill")
                                .foregroundColor(.secondary)
                        }
                    }
                    .textFieldStyle(CustomTextFieldStyle())
                }
            }
            
            // Error Message
            if let errorMessage = authManager.errorMessage {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            // Login Button
            Button(action: {
                Task {
                    await handleLogin()
                }
            }) {
                HStack {
                    if authManager.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    }
                    
                    Text(authManager.isLoading ? "로그인 중..." : "로그인")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(authManager.isLoading || studentID.isEmpty || password.isEmpty)
            .opacity((authManager.isLoading || studentID.isEmpty || password.isEmpty) ? 0.6 : 1.0)
            
            // Development Skip Button
            #if DEBUG
            Button("개발용: 로그인 건너뛰기") {
                // Skip authentication for development
                authManager.currentUser = User(
                    id: "dev_user",
                    email: "dev@seoultech.ac.kr",
                    eclassUsername: "20240000",
                    token: "dev_token"
                )
                authManager.isAuthenticated = true
            }
            .font(.caption)
            .foregroundColor(.orange)
            .padding(.top, 8)
            #endif
            
            // Info Section
            VStack(spacing: 8) {
                Text("AutoLMS는 e-Class 계정 정보를 사용합니다")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                
                Text("비밀번호는 안전하게 암호화되어 저장됩니다")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(horizontalSizeClass == .regular ? 32 : 24)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.regularMaterial)
                .shadow(radius: 10)
        )
    }
    
    // MARK: - Actions
    
    private func handleLogin() async {
        focusedField = nil
        await authManager.login(studentID: studentID, password: password)
    }
}

// MARK: - Custom Text Field Style

struct CustomTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
    }
}

// MARK: - Preview

#Preview("iPhone") {
    LoginView()
        .environmentObject(AuthenticationManager())
}

#Preview("iPad") {
    LoginView()
        .environmentObject(AuthenticationManager())
        .previewDevice("iPad Pro (12.9-inch)")
}