import os

/// Technical logging (§63). Interpolated values default to `.private` in the
/// unified log; document text, mail content, clipboard data and secrets must
/// never be logged, not even as private values.
public enum MosaicLog {
    public static let subsystem = "it.mosaic.app"

    public static func logger(category: String) -> Logger {
        Logger(subsystem: subsystem, category: category)
    }
}
