import UIKit

/// Renders the visit summary as a one-or-more page US Letter PDF.
enum ReportPDF {
    static let page = CGRect(x: 0, y: 0, width: 612, height: 792)
    static let margin: CGFloat = 54

    static func render(_ summary: VisitSummary) -> Data {
        let text = NSMutableAttributedString()
        let title: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 20, weight: .heavy), .foregroundColor: UIColor.black]
        let body: [NSAttributedString.Key: Any] = [.font: UIFont.systemFont(ofSize: 12), .foregroundColor: UIColor.black]
        let lines = summary.text.components(separatedBy: "\n")
        text.append(NSAttributedString(string: (lines.first ?? "") + "\n\n", attributes: title))
        text.append(NSAttributedString(string: lines.dropFirst().joined(separator: "\n"), attributes: body))

        let renderer = UIGraphicsPDFRenderer(bounds: page, format: {
            let f = UIGraphicsPDFRendererFormat()
            f.documentInfo = [kCGPDFContextTitle as String: "Dawnwell visit summary", kCGPDFContextCreator as String: "Dawnwell"]
            return f
        }())
        let frame = page.insetBy(dx: margin, dy: margin)
        let setter = CTFramesetterCreateWithAttributedString(text)
        return renderer.pdfData { ctx in
            var start = 0
            repeat {
                ctx.beginPage()
                let cg = ctx.cgContext
                cg.saveGState()
                cg.textMatrix = .identity
                cg.translateBy(x: 0, y: page.height)
                cg.scaleBy(x: 1, y: -1)
                let path = CGPath(rect: CGRect(x: frame.minX, y: page.height - frame.maxY, width: frame.width, height: frame.height), transform: nil)
                let ctFrame = CTFramesetterCreateFrame(setter, CFRange(location: start, length: 0), path, nil)
                CTFrameDraw(ctFrame, cg)
                cg.restoreGState()
                let shown = CTFrameGetVisibleStringRange(ctFrame).length
                if shown == 0 { break }
                start += shown
            } while start < text.length
        }
    }

    /// Write to a temporary file for the share sheet.
    static func file(_ summary: VisitSummary, now: Date = Date()) throws -> URL {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("Reports", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let url = dir.appendingPathComponent("Dawnwell-visit-summary-\(DayKey.of(now)).pdf")
        try render(summary).write(to: url, options: [.atomic, .completeFileProtection])
        return url
    }
}
