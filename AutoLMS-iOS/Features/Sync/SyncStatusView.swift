import SwiftUI

struct SyncStatusView: View {
    @ObservedObject var syncManager: SyncManager
    @State private var showingDetailSheet = false
    
    var body: some View {
        HStack(spacing: 12) {
            // Sync indicator
            syncIndicator
            
            // Status text
            VStack(alignment: .leading, spacing: 2) {
                Text(syncManager.syncStatus)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if syncManager.isSyncing {
                    ProgressView(value: syncManager.syncProgress)
                        .progressViewStyle(LinearProgressViewStyle())
                        .frame(height: 2)
                } else if let lastSyncTime = syncManager.lastGlobalSyncTime {
                    Text("마지막 동기화: \(lastSyncTime.formatted(.relative(presentation: .named)))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Action buttons
            HStack(spacing: 8) {
                if syncManager.isSyncing {
                    // Progress percentage
                    Text("\(Int(syncManager.syncProgress * 100))%")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.blue)
                } else {
                    // Sync button
                    Button(action: {
                        Task {
                            await syncManager.syncAll()
                        }
                    }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 16, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                }
                
                // Detail button
                Button(action: {
                    showingDetailSheet = true
                }) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 16))
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.regularMaterial)
        .cornerRadius(12)
        .sheet(isPresented: $showingDetailSheet) {
            SyncDetailSheet(syncManager: syncManager)
        }
        .alert("동기화 오류", isPresented: .constant(syncManager.errorMessage != nil)) {
            Button("확인") {
                syncManager.clearError()
            }
        } message: {
            if let errorMessage = syncManager.errorMessage {
                Text(errorMessage)
            }
        }
    }
    
    @ViewBuilder
    private var syncIndicator: some View {
        ZStack {
            Circle()
                .fill(.blue.opacity(0.1))
                .frame(width: 32, height: 32)
            
            if syncManager.isSyncing {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                    .scaleEffect(0.8)
            } else if syncManager.errorMessage != nil {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.system(size: 16))
            } else if syncManager.lastGlobalSyncTime != nil {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.system(size: 16))
            } else {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.blue)
                    .font(.system(size: 16))
            }
        }
    }
}

// MARK: - Sync Detail Sheet

struct SyncDetailSheet: View {
    @ObservedObject var syncManager: SyncManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                // Global sync status
                Section("전체 동기화 상태") {
                    HStack {
                        Image(systemName: syncManager.isSyncing ? "arrow.clockwise" : "checkmark.circle")
                            .foregroundColor(syncManager.isSyncing ? .blue : .green)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(syncManager.syncStatus)
                                .font(.headline)
                            
                            if syncManager.isSyncing {
                                Text("진행률: \(Int(syncManager.syncProgress * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else if let lastSync = syncManager.lastGlobalSyncTime {
                                Text("마지막 동기화: \(lastSync.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                
                // Individual course sync states
                if !syncManager.courseSyncStates.isEmpty {
                    Section("강의별 동기화 상태") {
                        ForEach(Array(syncManager.courseSyncStates.values.sorted { $0.startTime > $1.startTime }), id: \.courseID) { courseSync in
                            CourseSyncRowView(courseSync: courseSync)
                        }
                    }
                }
                
                // Actions
                Section("동작") {
                    Button(action: {
                        dismiss()
                        Task {
                            await syncManager.syncAll()
                        }
                    }) {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .foregroundColor(.blue)
                            Text("전체 동기화 시작")
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(syncManager.isSyncing)
                    
                    Button(action: {
                        syncManager.clearError()
                    }) {
                        HStack {
                            Image(systemName: "trash")
                                .foregroundColor(.red)
                            Text("오류 메시지 지우기")
                                .foregroundColor(.primary)
                        }
                    }
                    .disabled(syncManager.errorMessage == nil)
                }
            }
            .navigationTitle("동기화 상태")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("완료") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Course Sync Row View

struct CourseSyncRowView: View {
    let courseSync: CourseSyncState
    
    var body: some View {
        HStack {
            statusIcon
            
            VStack(alignment: .leading, spacing: 4) {
                Text(courseSync.courseName)
                    .font(.headline)
                
                Text(courseSync.status.displayName)
                    .font(.caption)
                    .foregroundColor(statusColor)
                
                if let duration = courseSync.duration {
                    let minutes = Int(duration) / 60
                    let seconds = Int(duration) % 60
                    Text("소요 시간: \(minutes):\(String(format: "%02d", seconds))")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Text(courseSync.startTime.formatted(date: .omitted, time: .shortened))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch courseSync.status {
        case .pending:
            Image(systemName: "clock")
                .foregroundColor(.gray)
        case .syncing:
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .blue))
                .scaleEffect(0.8)
        case .completed:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        }
    }
    
    private var statusColor: Color {
        switch courseSync.status {
        case .pending:
            return .secondary
        case .syncing:
            return .blue
        case .completed:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        SyncStatusView(syncManager: SyncManager.shared)
            .padding()
        
        Spacer()
    }
    .background(Color(.systemGroupedBackground))
}