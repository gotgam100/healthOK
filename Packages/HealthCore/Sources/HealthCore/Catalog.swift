import Foundation

/// 앱에 내장된 검사 항목 사전과 기준치 규칙
public final class Catalog: Sendable {
    public static let shared: Catalog = {
        do { return try Catalog.loadBundled() } catch {
            fatalError("내장 검사 항목/기준치 파일을 읽지 못했습니다: \(error)")
        }
    }()

    public let items: [TestItem]
    public let rules: [ReferenceRule]
    private let itemsByCode: [String: TestItem]
    private let rulesByItem: [String: [ReferenceRule]]

    public init(items: [TestItem], rules: [ReferenceRule]) {
        self.items = items
        self.rules = rules
        self.itemsByCode = Dictionary(items.map { ($0.code, $0) }, uniquingKeysWith: { a, _ in a })
        self.rulesByItem = Dictionary(grouping: rules, by: \.item)
    }

    public static func loadBundled() throws -> Catalog {
        let decoder = JSONDecoder()
        func load<T: Decodable>(_ name: String, as: T.Type) throws -> T {
            guard let url = Bundle.module.url(forResource: name, withExtension: "json") else {
                throw CocoaError(.fileNoSuchFile, userInfo: [NSFilePathErrorKey: "\(name).json"])
            }
            return try decoder.decode(T.self, from: Data(contentsOf: url))
        }
        return Catalog(items: try load("items", as: [TestItem].self),
                       rules: try load("rules", as: [ReferenceRule].self))
    }

    public func item(_ code: String) -> TestItem? { itemsByCode[code] }

    /// 해당 성별에 맞는 항목만
    public func items(for sex: Sex) -> [TestItem] { items.filter { $0.appliesTo(sex) } }

    public func items(in category: ItemCategory, sex: Sex) -> [TestItem] {
        items.filter { $0.category == category && $0.appliesTo(sex) }
    }

    /// 사람에게 맞는 규칙 (가장 구체적인 것 우선)
    public func rule(for code: String, sex: Sex, age: Int) -> ReferenceRule? {
        (rulesByItem[code] ?? [])
            .filter { $0.applies(sex: sex, age: age) }
            .max { $0.specificity < $1.specificity }
    }
}
