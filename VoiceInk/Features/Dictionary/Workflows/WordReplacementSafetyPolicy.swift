import Foundation

/// [custom] 置換ルールの歯止め（2026-11-11）。
///
/// 置換は「すべてのアプリの、すべての音声入力」にかかる。元の語が短すぎると、普通の文の一部まで
/// 書き換えてしまう（実例: 「音 → ウォン」で「音声入力」が「ウォン声入力」、「K → 計」）。
/// 逆に元の語が文まるごとだと、Auto Learn がボタンの文字などを「直した結果」と取り違えた候補になる
/// （実例: 「11月6日からの韓国 → ChatGPT に聞く」）。
///
/// この判定は次の 4 か所で使う。
/// - 置換をかける時（`WordReplacementService`）: 危ない元の語は、登録されていてもかけない（最後の砦）
/// - 手で追加・編集する時（`DictionaryService`）: エラーにして登録させない
/// - Auto Learn が辞書へ入れる時（`WordReplacementStore`）: 置換は入れない（語彙だけは入れてよい）
/// - Auto Learn の候補を貯める時（`AutoLearnPendingQueue`）: 文まるごとの候補は貯めない
enum WordReplacementSafetyPolicy {
    enum Rejection: Equatable {
        /// 1 文字。普通の語の一部に当たりやすい
        case tooShort
        /// 数字・記号だけ。金額や数量を書き換えてしまう
        case numbersOrSymbolsOnly
        /// 長すぎる（文まるごと）
        case tooLong
        /// 句読点・改行を含む（文まるごと）
        case sentence
    }

    static let minimumCharacters = 2
    static let maximumCharacters = 32
    private static let sentenceMarks: Set<Character> = ["。", "、", "！", "？", "!", "?", "．", "\n", "\r"]

    static func rejection(forSource rawSource: String) -> Rejection? {
        let source = rawSource.trimmingCharacters(in: .whitespacesAndNewlines)
            .precomposedStringWithCanonicalMapping
        let visible = source.filter { !$0.isWhitespace }
        if visible.count < minimumCharacters { return .tooShort }
        if visible.allSatisfy({ $0.isNumber || $0.isPunctuation || $0.isSymbol }) {
            return .numbersOrSymbolsOnly
        }
        if source.contains(where: { sentenceMarks.contains($0) }) { return .sentence }
        if source.count > maximumCharacters { return .tooLong }
        return nil
    }

    static func isSafe(source: String) -> Bool {
        rejection(forSource: source) == nil
    }

    /// 文まるごとの候補か（Auto Learn の候補を貯める段階で捨てる）。短い語は語彙として学べるので捨てない。
    static func looksLikeSentence(_ text: String) -> Bool {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.contains(where: { sentenceMarks.contains($0) })
            || value.count > maximumCharacters
    }

    static func message(for rejection: Rejection, source: String) -> String {
        switch rejection {
        case .tooShort:
            return "「\(source)」は1文字なので置換に登録できません（普通の文の一部まで書き換えてしまうため）。前後の語を含めて登録してください。"
        case .numbersOrSymbolsOnly:
            return "「\(source)」は数字・記号だけなので置換に登録できません（金額や数量を書き換えてしまうため）。"
        case .tooLong:
            return "「\(source)」は長すぎるので置換に登録できません（\(maximumCharacters)文字まで）。"
        case .sentence:
            return "「\(source)」は句読点を含む文なので置換に登録できません。語だけを登録してください。"
        }
    }

    /// 置換元（カンマ区切りの複数可）のうち、最初に引っかかったものの説明。問題なければ nil。
    static func firstProblem(inSources sources: [String]) -> String? {
        for source in sources {
            if let rejection = rejection(forSource: source) {
                return message(for: rejection, source: source)
            }
        }
        return nil
    }
}
