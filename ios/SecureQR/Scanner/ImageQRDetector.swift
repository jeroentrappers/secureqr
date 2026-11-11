import Foundation
import Vision

/// Finds a QR code in a still image (a photo the user picked).
enum ImageQRDetector {
    /// The text of the first QR code in the image, or nil.
    static func detect(in imageData: Data) async -> String? {
        return await withCheckedContinuation { (continuation: CheckedContinuation<String?, Never>) in
            DispatchQueue.global(qos: .userInitiated).async {
                continuation.resume(returning: detectSynchronously(in: imageData))
            }
        }
    }

    static func detectSynchronously(in imageData: Data) -> String? {
        let request = VNDetectBarcodesRequest()
        request.symbologies = [.qr]
        let handler = VNImageRequestHandler(data: imageData, options: [:])
        do {
            try handler.perform([request])
        } catch {
            return nil
        }
        let observations = request.results ?? []
        return observations.compactMap({ $0.payloadStringValue }).first(where: { !$0.isEmpty })
    }
}
