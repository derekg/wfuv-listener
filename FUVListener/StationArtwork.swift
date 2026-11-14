import UIKit

enum StationArtwork {
    static let image: UIImage = {
        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        return UIGraphicsImageRenderer(size: CGSize(width: 800, height: 800), format: format).image { _ in
            let black = UIColor(red: 0.075, green: 0.075, blue: 0.08, alpha: 1)
            let red = UIColor(red: 0.81, green: 0.12, blue: 0.22, alpha: 1)
            black.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 800, height: 800))
            red.setFill()
            UIRectFill(CGRect(x: 0, y: 0, width: 800, height: 170))
            UIRectFill(CGRect(x: 56, y: 618, width: 118, height: 14))

            draw("90.7 FM", at: CGPoint(x: 56, y: 38), size: 80, color: .white, weight: .bold)
            draw("WFUV", at: CGPoint(x: 48, y: 270), size: 172, color: .white, weight: .black)
            draw("NEW YORK'S MUSIC DISCOVERY", at: CGPoint(x: 56, y: 666), size: 30, color: .white, weight: .medium)
        }
    }()

    private static func draw(_ text: String, at origin: CGPoint, size: CGFloat, color: UIColor, weight: UIFont.Weight) {
        let font = UIFont(name: weight == .black ? "Heebo-Black" : weight == .bold ? "Heebo-Bold" : "Heebo-Medium", size: size)
            ?? .systemFont(ofSize: size, weight: weight)
        (text as NSString).draw(at: origin, withAttributes: [.font: font, .foregroundColor: color])
    }
}

/// A song-specific cover for recordings without reliable release artwork.
enum SongArtwork {
    private static let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 120
        cache.totalCostLimit = 24_000_000
        return cache
    }()

    static func image(title: String, artist: String, size: CGFloat = 800) -> UIImage {
        let key = "\(title)|\(artist)|\(Int(size))" as NSString
        if let image = cache.object(forKey: key) { return image }

        let format = UIGraphicsImageRendererFormat()
        format.opaque = true
        format.scale = 1
        let image = UIGraphicsImageRenderer(size: CGSize(width: size, height: size), format: format).image { renderer in
            let context = renderer.cgContext
            context.scaleBy(x: size / 800, y: size / 800)
            let variant = (title + artist).unicodeScalars.reduce(0) { ($0 * 31 + Int($1.value)) % 3 }
            let palettes: [[UIColor]] = [
                [UIColor(red: 0.42, green: 0.07, blue: 0.17, alpha: 1), UIColor(red: 0.16, green: 0.09, blue: 0.15, alpha: 1), UIColor(red: 0.06, green: 0.06, blue: 0.09, alpha: 1)],
                [UIColor(red: 0.13, green: 0.28, blue: 0.37, alpha: 1), UIColor(red: 0.09, green: 0.14, blue: 0.24, alpha: 1), UIColor(red: 0.05, green: 0.07, blue: 0.12, alpha: 1)],
                [UIColor(red: 0.48, green: 0.25, blue: 0.13, alpha: 1), UIColor(red: 0.24, green: 0.13, blue: 0.13, alpha: 1), UIColor(red: 0.08, green: 0.07, blue: 0.09, alpha: 1)]
            ]
            let colors = palettes[variant].map(\.cgColor) as CFArray
            if let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: colors, locations: [0, 0.5, 1]) {
                context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: 0), end: CGPoint(x: 800, y: 800), options: [])
            }

            context.setStrokeColor(UIColor.white.withAlphaComponent(0.12).cgColor)
            context.setLineWidth(2)
            for radius in [340.0, 455.0, 570.0] {
                context.strokeEllipse(in: CGRect(x: 540 - radius, y: -190 - radius, width: radius * 2, height: radius * 2))
            }
            UIColor(red: 0.82, green: 0.12, blue: 0.22, alpha: 1).setFill()
            UIRectFill(CGRect(x: 56, y: 126, width: 112, height: 11))

            draw("90.7  /  WFUV", in: CGRect(x: 56, y: 51, width: 680, height: 58), size: 36,
                 fontName: "Heebo-Bold", color: .white)
            drawFitted(title, in: CGRect(x: 54, y: 208, width: 690, height: 316),
                       startingSize: 88, minimumSize: 48, fontName: "Bitter-Bold", color: .white)
            drawFitted(artist, in: CGRect(x: 58, y: 566, width: 680, height: 122),
                       startingSize: 49, minimumSize: 32, fontName: "Heebo-Regular",
                       color: UIColor.white.withAlphaComponent(0.83))
            draw("ON WFUV", in: CGRect(x: 58, y: 729, width: 680, height: 38),
                 size: 25, fontName: "Heebo-Bold", color: UIColor.white.withAlphaComponent(0.65))
        }
        cache.setObject(image, forKey: key, cost: Int(size * size * 4))
        return image
    }

    private static func drawFitted(_ string: String, in rect: CGRect, startingSize: CGFloat,
                                   minimumSize: CGFloat, fontName: String, color: UIColor) {
        var size = startingSize
        while size > minimumSize {
            let font = UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size, weight: .bold)
            let bounds = (string as NSString).boundingRect(with: rect.size,
                options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: [.font: font], context: nil)
            if bounds.height <= rect.height { break }
            size -= 4
        }
        draw(string, in: rect, size: size, fontName: fontName, color: color)
    }

    private static func draw(_ string: String, in rect: CGRect, size: CGFloat,
                             fontName: String, color: UIColor) {
        let font = UIFont(name: fontName, size: size) ?? .systemFont(ofSize: size, weight: .bold)
        let style = NSMutableParagraphStyle()
        style.lineBreakMode = .byWordWrapping
        style.minimumLineHeight = size * 1.12
        (string as NSString).draw(in: rect, withAttributes: [
            .font: font, .foregroundColor: color, .paragraphStyle: style
        ])
    }
}
