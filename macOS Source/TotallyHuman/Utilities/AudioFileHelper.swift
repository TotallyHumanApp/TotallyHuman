import Foundation
import CryptoKit

/// Hilfsfunktionen rund um Audiodateien: unterstützte Formate, Datei-Signatur
/// (für Deduplizierung) und rekursives Auffinden von Audiodateien in Ordnern.
enum AudioFileHelper {

    static let unterstuetzteEndungen: Set<String> = AnalysisConfig.supportedExtensions

    static func istAudioDatei(_ url: URL) -> Bool {
        unterstuetzteEndungen.contains(url.pathExtension.lowercased())
    }

    /// MD5-Signatur des Dateiinhalts (streaming, speicherschonend).
    static func md5Signatur(url: URL) -> String {
        guard let stream = InputStream(url: url) else {
            // Fallback: Pfad + Größe
            return md5(of: Data(url.path.utf8))
        }
        stream.open()
        defer { stream.close() }
        var hasher = Insecure.MD5()
        let puffer = UnsafeMutablePointer<UInt8>.allocate(capacity: 65536)
        defer { puffer.deallocate() }
        while stream.hasBytesAvailable {
            let gelesen = stream.read(puffer, maxLength: 65536)
            if gelesen <= 0 { break }
            hasher.update(data: Data(bytes: puffer, count: gelesen))
        }
        return hasher.finalize().map { String(format: "%02x", $0) }.joined()
    }

    private static func md5(of data: Data) -> String {
        Insecure.MD5.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// Findet alle unterstützten Audiodateien in einem Ordner (rekursiv). Ist die
    /// URL selbst eine Datei, wird sie – falls unterstützt – zurückgegeben.
    static func findeAudioDateien(in url: URL) -> [URL] {
        let fm = FileManager.default
        var istOrdner: ObjCBool = false
        guard fm.fileExists(atPath: url.path, isDirectory: &istOrdner) else { return [] }
        if !istOrdner.boolValue {
            return istAudioDatei(url) ? [url] : []
        }
        var ergebnis: [URL] = []
        if let e = fm.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let f as URL in e where istAudioDatei(f) {
                ergebnis.append(f)
            }
        }
        return ergebnis.sorted { $0.lastPathComponent.localizedCompare($1.lastPathComponent) == .orderedAscending }
    }
}
