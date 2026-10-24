import Foundation

/// [custom] 長い書き起こしは Direct Typing をやめて、クリップボード貼り付け（⌘V）で入れる（2026-10-24）。
///
/// Direct Typing は 20 UTF-16 単位ずつのキーイベントを続けて送る。VS Code のターミナル（Claude Code）などでは
/// 2 つ目以降のイベントが捨てられ、241 文字の書き起こしが先頭 20 文字だけ入った（305 文字は 120 文字だけ）。
/// 途切れた位置はどちらも 20 の倍数で、History には全文が残っていた。1 イベントに収まる短い文は従来どおり
/// Direct Typing（クリップボードを使わない）、それを超える文だけ貼り付けにする。貼り付けたあとはクリップボードを
/// 元に戻す（設定に関係なく。Direct Typing を選んだ人は書き起こし文をクリップボードに残したくないため）。
enum PasteRoutePolicy {
    /// DirectTextTyper の 1 イベントの大きさ。これ以下なら 1 イベントで届く
    static let directTypingMaxUTF16 = 20

    static func effectiveMethod(configured: PasteMethod, text: String, limit: Int = directTypingMaxUTF16) -> PasteMethod {
        guard configured == .directTyping else { return configured }
        return text.utf16.count > limit ? .standard : .directTyping
    }

    /// 貼り付けに切り替えたとき（configured が Direct Typing）は、設定に関係なくクリップボードを元に戻す
    static func shouldRestoreClipboard(configured: PasteMethod, effective: PasteMethod, userSetting: Bool) -> Bool {
        guard effective.usesClipboard else { return false }
        return userSetting || configured == .directTyping
    }
}
