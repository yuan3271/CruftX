import Foundation

/// Central search / retrieval logic for the junk lists.
///
/// Matching is token-based: the query is split on whitespace and every term
/// must appear in the item's search text (AND semantics), which lets users
/// combine keywords in any order (e.g. "微信 图片" matches a WeChat image
/// cache) instead of requiring one contiguous substring. Search keys are
/// pre-computed once per item so typing doesn't rebuild them on every key.
enum JunkSearch {

    /// Splits a query into lower-cased terms. Returns the terms, or an empty
    /// array when the query is empty / whitespace only.
    static func terms(for query: String) -> [String] {
        query.lowercased()
            .split(whereSeparator: { $0.isWhitespace })
            .map(String.init)
    }

    /// Builds the normalized, lower-cased search key for an item. Only stable
    /// fields are baked in; localized labels are appended at query time so the
    /// key stays valid after a language switch.
    static func makeKey(
        name: String,
        path: URL,
        appName: String?,
        kind: JunkKind?,
        residueKind: ResidueKind?,
        officeKind: OfficeKind?
    ) -> String {
        let fields = [
            name,
            path.path,
            appName ?? "",
            kind?.rawValue ?? "",
            residueKind?.rawValue ?? "",
            officeKind?.rawValue ?? ""
        ]
        return fields.joined(separator: " ").lowercased()
    }

    /// True when every term in `query` appears in the item's search text.
    static func matches(_ item: JunkItem, query: String) -> Bool {
        let terms = terms(for: query)
        guard !terms.isEmpty else { return true }

        // Start from the cached key, then append the current localized labels
        // (titles / risk) so searching by what the user sees still works.
        var haystack = item.searchKey
        haystack += " " + item.risk.title.lowercased()
        if let kind = item.kind { haystack += " " + kind.title.lowercased() }
        if let residueKind = item.residueKind { haystack += " " + residueKind.title.lowercased() }
        if let officeKind = item.officeKind { haystack += " " + officeKind.title.lowercased() }

        return terms.allSatisfy { haystack.contains($0) }
    }

    /// Generic token-based matcher for non-`JunkItem` searchable lists
    /// (Recycle Bin entries, installed apps).
    static func matches(_ haystack: String, query: String) -> Bool {
        let terms = terms(for: query)
        guard !terms.isEmpty else { return true }
        let haystackLowered = haystack.lowercased()
        return terms.allSatisfy { haystackLowered.contains($0) }
    }
}
