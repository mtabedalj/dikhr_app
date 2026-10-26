import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Backup screen (نسخ احتياطي): export user data into one JSON file shared via
/// ShareLink, and import it back through the document picker.
struct BackupView: View {
    @EnvironmentObject private var settings: SettingsStore
    @State private var exportURL: URL?
    @State private var showImporter = false
    @State private var status: String?

    var body: some View {
        Form {
            Section {
            Text(settings.t("احفظ مفضلتك وعداداتك وسلسلة مداومتك وإعداداتك في ملف واحد، واستعدها على أي جهاز.",
                            "Save your favorites, counters, streaks and settings into one file and restore them on any device."))
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section(settings.t("تصدير", "Export")) {
                if let exportURL {
                    ShareLink(item: exportURL,
                              preview: SharePreview(settings.t("نسخة احتياطية — ذكر", "Backup — Dikhr"))) {
                        Label(settings.t("مشاركة ملف النسخة الاحتياطية", "Share Backup File"), systemImage: "square.and.arrow.up")
                            .foregroundStyle(.accent)
                    }
                } else {
                    HStack(spacing: 10) {
                        ProgressView()
                        Text(settings.t("جارٍ تجهيز الملف…", "Preparing file…"))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(settings.t("استيراد", "Import")) {
                Button {
                    showImporter = true
                } label: {
                    Label(settings.t("اختيار ملف النسخة الاحتياطية", "Choose Backup File"), systemImage: "square.and.arrow.down")
                        .foregroundStyle(.accent)
                }
            }

            if let status {
                Section {
                    Label(status, systemImage: "info.circle")
                        .font(.footnote)
                }
            }
        }
        .navigationTitle(settings.t("نسخ احتياطي", "Backup"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            exportURL = try? BackupService.exportURL()
        }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [.json, .data],
                      allowsMultipleSelection: false) { result in
            handleImport(result)
        }
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            do {
                try BackupService.importURL(url)
                // Regenerate the export file with the newly merged data.
                exportURL = try? BackupService.exportURL()
                status = settings.t("تم استيراد النسخة الاحتياطية بنجاح", "Backup imported successfully")
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            } catch {
                status = error.localizedDescription
                UINotificationFeedbackGenerator().notificationOccurred(.error)
            }
        case .failure:
            // User cancelled the picker — no message.
            break
        }
    }
}