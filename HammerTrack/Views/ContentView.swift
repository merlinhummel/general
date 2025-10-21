//
//  ContentView.swift
//  HammerTrack
//
//  Created by Claude on 2025-10-21.
//

import SwiftUI
import PhotosUI

/// Main navigation view for HammerTrack app
struct ContentView: View {

    @StateObject private var processingVM = VideoProcessingViewModel()

    @State private var selectedMode: AnalysisMode = .single
    @State private var showingVideoPicker = false
    @State private var selectedVideoURL: URL?

    @State private var analysis1: ThrowAnalysis?
    @State private var analysis2: ThrowAnalysis?

    enum AnalysisMode {
        case single
        case comparison
    }

    var body: some View {
        NavigationStack {
            ZStack {
                // Background with gradient
                LinearGradient(
                    colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 30) {
                    // App Title
                    VStack(spacing: 8) {
                        Text("HammerTrack")
                            .font(.system(size: 42, weight: .bold, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [.blue, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )

                        Text("Hammerwurf-Analyse")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 60)

                    Spacer()

                    // Mode Selection
                    VStack(spacing: 20) {
                        // Single Analysis Button
                        NavigationLink(destination: videoPickerDestination(for: .single)) {
                            ModeCard(
                                icon: "play.rectangle.fill",
                                title: "Einzelanalyse",
                                description: "Analysiere einen einzelnen Wurf"
                            )
                        }

                        // Comparison Analysis Button
                        NavigationLink(destination: videoPickerDestination(for: .comparison)) {
                            ModeCard(
                                icon: "rectangle.split.2x1.fill",
                                title: "Vergleichsanalyse",
                                description: "Vergleiche zwei Würfe"
                            )
                        }
                    }
                    .padding(.horizontal)

                    Spacer()

                    // Footer
                    Text("iOS 18 · Liquid Glass Design")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.bottom, 20)
                }
            }
            .navigationBarHidden(true)
        }
    }

    // MARK: - Video Picker Destination

    @ViewBuilder
    private func videoPickerDestination(for mode: AnalysisMode) -> some View {
        VideoPickerView { url in
            selectedVideoURL = url
            selectedMode = mode
        }
    }
}

// MARK: - Mode Card Component
struct ModeCard: View {

    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 20) {
            Image(systemName: icon)
                .font(.system(size: 32))
                .foregroundColor(.blue)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(.thinMaterial)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text(description)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .shadow(color: .black.opacity(0.1), radius: 10)
        )
    }
}

// MARK: - Video Picker View
struct VideoPickerView: View {

    let onVideoSelected: (URL) -> Void

    @State private var selectedItem: PhotosPickerItem?
    @State private var videoURL: URL?
    @StateObject private var processingVM = VideoProcessingViewModel()

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            Color(uiColor: .systemGroupedBackground)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                if processingVM.isProcessing {
                    // Processing state
                    VStack(spacing: 20) {
                        ProgressView(value: processingVM.processingProgress)
                            .progressViewStyle(.linear)
                            .tint(.blue)

                        Text(processingVM.processingPhaseDescription)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 15)
                            .fill(.ultraThinMaterial)
                    )
                    .padding()

                } else if let analysis = processingVM.currentAnalysis {
                    // Analysis ready - navigate to single analysis view
                    NavigationLink(
                        destination: SingleAnalysisView(analysis: analysis),
                        label: {
                            Text("Analyse anzeigen")
                        }
                    )
                } else {
                    // Video picker
                    VStack(spacing: 30) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)

                        Text("Wähle ein Video")
                            .font(.system(size: 24, weight: .semibold))

                        PhotosPicker(
                            selection: $selectedItem,
                            matching: .videos
                        ) {
                            LiquidGlassButton("Video auswählen", icon: "photo.on.rectangle") {
                                // Action handled by PhotosPicker
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Video auswählen")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: selectedItem) { _, newItem in
            Task {
                if let url = try? await loadVideo(from: newItem) {
                    await processingVM.processVideo(at: url)
                }
            }
        }
    }

    private func loadVideo(from item: PhotosPickerItem?) async throws -> URL? {
        guard let item = item else { return nil }

        guard let movie = try await item.loadTransferable(type: VideoTransferable.self) else {
            return nil
        }

        return movie.url
    }
}

// MARK: - Video Transferable
struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let copy = URL.documentsDirectory.appending(path: "imported_video.mov")
            if FileManager.default.fileExists(atPath: copy.path()) {
                try FileManager.default.removeItem(at: copy)
            }
            try FileManager.default.copyItem(at: received.file, to: copy)
            return Self(url: copy)
        }
    }
}

// MARK: - Preview
#Preview {
    ContentView()
}
