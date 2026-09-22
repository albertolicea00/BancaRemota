import Foundation
import SwiftUI

// MARK: - Application Configuration Models
struct BankConfig: Codable {
    let banks: [Bank]
}

struct Bank: Codable, Identifiable {
    let id: String
    let name: String
    let shortName: String // E.g., "bpa", "bandec", "bm"
    let logoImg: String
    let iconImg: String
    let themeColorHex: String
    let textColorHex: String
    let categories: [OperationCategory]
    
    var themeColor: Color {
        Color(hex: themeColorHex)
    }
    
    var textColor: Color {
        Color(hex: textColorHex)
    }
}

// MARK: - Localized Text for Multilingual Support
struct LocalizedText: Codable, Equatable {
    var es: String
    var en: String

    var localized: String {
        let pref = Locale.preferredLanguages.first ?? Locale.current.identifier
        if pref.hasPrefix("en") {
            return en.isEmpty ? es : en
        }
        return es
    }

    init(es: String, en: String = "") {
        self.es = es
        self.en = en.isEmpty ? es : en
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.container(keyedBy: CodingKeys.self) {
            let esVal = try? container.decode(String.self, forKey: .es)
            let enVal = try? container.decode(String.self, forKey: .en)
            self.es = esVal ?? ""
            self.en = enVal ?? esVal ?? ""
        } else if let singleVal = try? decoder.singleValueContainer().decode(String.self) {
            self.es = singleVal
            self.en = singleVal
        } else {
            self.es = ""
            self.en = ""
        }
    }

    private enum CodingKeys: String, CodingKey {
        case es, en
    }
}

struct OperationCategory: Codable, Identifiable {
    var id: String { title.es }
    let title: LocalizedText
    let operations: [BankOperation]

    var name: String { title.localized }

    enum CodingKeys: String, CodingKey {
        case title, name, operations
    }

    init(title: LocalizedText, operations: [BankOperation]) {
        self.title = title
        self.operations = operations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        operations = try container.decode([BankOperation].self, forKey: .operations)
        if let t = try? container.decode(LocalizedText.self, forKey: .title) {
            title = t
        } else if let n = try? container.decode(LocalizedText.self, forKey: .name) {
            title = n
        } else {
            title = LocalizedText(es: "", en: "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(title, forKey: .title)
        try container.encode(operations, forKey: .operations)
    }
}

struct BankOperation: Codable, Identifiable, Equatable {
    let id: String
    let title: LocalizedText
    let details: LocalizedText
    let iconName: String
    let ussdCode: String
    var isLogin: Bool?
    var isDefaultFavorite: Bool?
    var prefill: String?

    var name: String { title.localized }
    var description: String { details.localized }

    enum CodingKeys: String, CodingKey {
        case id, title, details, name, description, iconName, ussdCode, isLogin, isDefaultFavorite, prefill
    }

    init(id: String, title: LocalizedText, details: LocalizedText, iconName: String, ussdCode: String, isLogin: Bool? = nil, isDefaultFavorite: Bool? = nil, prefill: String? = nil) {
        self.id = id
        self.title = title
        self.details = details
        self.iconName = iconName
        self.ussdCode = ussdCode
        self.isLogin = isLogin
        self.isDefaultFavorite = isDefaultFavorite
        self.prefill = prefill
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        iconName = try container.decode(String.self, forKey: .iconName)
        ussdCode = try container.decode(String.self, forKey: .ussdCode)
        isLogin = try container.decodeIfPresent(Bool.self, forKey: .isLogin)
        isDefaultFavorite = try container.decodeIfPresent(Bool.self, forKey: .isDefaultFavorite)
        prefill = try container.decodeIfPresent(String.self, forKey: .prefill)

        if let t = try? container.decode(LocalizedText.self, forKey: .title) {
            title = t
        } else if let n = try? container.decode(LocalizedText.self, forKey: .name) {
            title = n
        } else {
            title = LocalizedText(es: "", en: "")
        }

        if let d = try? container.decode(LocalizedText.self, forKey: .details) {
            details = d
        } else if let desc = try? container.decode(LocalizedText.self, forKey: .description) {
            details = desc
        } else {
            details = LocalizedText(es: "", en: "")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(details, forKey: .details)
        try container.encode(iconName, forKey: .iconName)
        try container.encode(ussdCode, forKey: .ussdCode)
        try container.encodeIfPresent(isLogin, forKey: .isLogin)
        try container.encodeIfPresent(isDefaultFavorite, forKey: .isDefaultFavorite)
        try container.encodeIfPresent(prefill, forKey: .prefill)
    }
}

// MARK: - Reactive Theme Manager
final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()
    @Published var accentColor: Color

    private init() {
        accentColor = ThemeManager.computeColor()
    }

    static func computeColor() -> Color {
        let useCustom = UserDefaults.standard.bool(forKey: "useCustomFavoriteColor")
        let hex = UserDefaults.standard.string(forKey: "favoriteCustomColorHex") ?? "B38B4D"
        return useCustom ? Color(hex: hex) : Color(hex: "B38B4D")
    }

    func refresh() {
        accentColor = ThemeManager.computeColor()
    }
}

// MARK: - Color Hex Initialization Extension
extension Color {
    static var appPrimary: Color {
        let useCustom = UserDefaults.standard.bool(forKey: "useCustomFavoriteColor")
        let hex = UserDefaults.standard.string(forKey: "favoriteCustomColorHex") ?? "B38B4D"
        return useCustom ? Color(hex: hex) : Color(hex: "B38B4D")
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }

        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
    
    func toHex() -> String? {
        let uic = UIColor(self)
        guard let components = uic.cgColor.components, components.count >= 3 else {
            return nil
        }
        let r = Float(components[0])
        let g = Float(components[1])
        let b = Float(components[2])
        var a = Float(1.0)
        
        if components.count >= 4 {
            a = Float(components[3])
        }
        
        if a != Float(1.0) {
            return String(format: "%02lX%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255), lroundf(a * 255))
        } else {
            return String(format: "%02lX%02lX%02lX", lroundf(r * 255), lroundf(g * 255), lroundf(b * 255))
        }
    }
}

// MARK: - Favorites Management
struct FavoriteOperation: Codable, Identifiable, Equatable {
    var id: String { "\(bankId)_\(operation.id)" }
    let bankId: String
    /// Snapshot encoded when the favorite was added — may be stale (old wording, old
    /// USSD code, or predate multi-language support). Display and dialing should use
    /// `liveOperation` instead, which re-resolves against the current codes.json.
    let operation: BankOperation

    /// Current definition of this operation, falling back to the stored snapshot if it
    /// was removed from codes.json since being favorited.
    var liveOperation: BankOperation {
        DataService.shared.operation(id: operation.id, bankId: bankId) ?? operation
    }

    static func == (lhs: FavoriteOperation, rhs: FavoriteOperation) -> Bool {
        lhs.id == rhs.id
    }
}

class FavoritesManager: ObservableObject {
    static let shared = FavoritesManager()
    
    @Published var favoriteOperations: [FavoriteOperation] = [] {
        didSet {
            save()
        }
    }
    
    init() {
        load()
    }
    
    private func save() {
        if let encoded = try? JSONEncoder().encode(favoriteOperations) {
            UserDefaults.standard.set(encoded, forKey: "favoriteOperations")
        }
    }
    
    private func load() {
        if let data = UserDefaults.standard.data(forKey: "favoriteOperations"),
           let decoded = try? JSONDecoder().decode([FavoriteOperation].self, from: data) {
            favoriteOperations = decoded
        }
    }
    
    func loadDefaults(from banks: [Bank]) {
        var defaults: [FavoriteOperation] = []
        for bank in banks {
            for category in bank.categories {
                for operation in category.operations {
                    if operation.isDefaultFavorite == true {
                        defaults.append(FavoriteOperation(bankId: bank.id, operation: operation))
                    }
                }
            }
        }
        favoriteOperations = defaults
    }
}

// MARK: - Nauta Account
struct NautaAccount: Codable, Identifiable, Equatable {
    var id = UUID()
    var type: String // "Nacional" or "Internacional"
    var account: String
    var label: String
    var group: String = ""
}

// MARK: - Bank Account
struct BankAccount: Codable, Identifiable, Equatable {
    var id = UUID()
    var name: String
    var cardNumber: String
    var mobile: String
    var label: String
    var group: String = ""
    var colorHex: String = "1A1A1A" // Default dark color
}

// MARK: - Bill
struct Bill: Codable, Identifiable, Equatable {
    var id = UUID()
    var label: String
    var billNumber: String
    var type: BillType
    var group: String = ""
}

enum BillType: String, Codable, CaseIterable {
    case electricity = "Electricidad"
    case water = "Agua"
    case gas = "Gas"
    case telephone = "Teléfono"
    
    var iconName: String {
        switch self {
        case .electricity: return "bolt"
        case .water: return "drop"
        case .gas: return "flame"
        case .telephone: return "phone"
        }
    }

    var localizedName: String {
        NSLocalizedString(rawValue, comment: "")
    }
}

// MARK: - User Key (Passwords/PINs)
struct UserKey: Codable, Identifiable, Equatable {
    var id = UUID()
    var label: String
    var value: String
    var category: KeyCategory
    var customCategory: String? = nil
    var group: String = ""
}

enum KeyCategory: String, Codable, CaseIterable {
    case bank = "Banco"
    case nauta = "Nauta"
    case other = "Otros"
    // Special categories: only ONE key may exist per category.
    // These are the ones the app auto-copies when running the bank's authentication operation.
    case appBPA = "BancaRemota (BPA)"
    case appBANDEC = "BancaRemota (BANDEC)"
    case appBM = "BancaRemota (BM)"

    var iconName: String {
        switch self {
        case .bank: return "creditcard.and.123"
        case .nauta: return "wifi"
        case .other: return "key.fill"
        case .appBPA, .appBANDEC, .appBM: return "checkmark.seal.fill"
        }
    }

    /// codes.json bank id this special category is bound to. nil for regular categories.
    var bankId: String? {
        switch self {
        case .appBPA: return "bpa"
        case .appBANDEC: return "bandec"
        case .appBM: return "bm"
        case .bank, .nauta, .other: return nil
        }
    }

    /// Special category => unique per bank, tied to one specific bank.
    var isSpecial: Bool { bankId != nil }

    /// Name shown to the user in pickers and lists. rawValue stays as the persisted identity.
    var displayName: String {
        switch self {
        case .appBPA: return "PIN BPA"
        case .appBANDEC: return "PIN BANDEC"
        case .appBM: return "PIN BM"
        case .bank, .nauta, .other: return rawValue
        }
    }

    /// Label pre-filled into the key when a special category is picked.
    var defaultLabel: String? { isSpecial ? rawValue : nil }

    /// Max digits accepted for this category's PIN. nil = no length rule.
    var maxPinLength: Int? {
        switch self {
        case .appBANDEC: return 5
        case .appBPA, .appBM: return 4
        case .bank, .nauta, .other: return nil
        }
    }

    /// Non-blocking warning about a key value. nil = nothing to warn about.
    /// Never prevents saving; it only tells the user the PIN looks wrong for this bank.
    func warning(forValue value: String) -> String? {
        guard let maxPinLength = maxPinLength, !value.isEmpty else { return nil }
        let bankName = bankId?.uppercased() ?? rawValue

        if !value.allSatisfy({ $0.isASCII && $0.isNumber }) {
            return String(format: NSLocalizedString("El PIN de %@ normalmente es solo numérico.", comment: ""), bankName)
        }
        if value.count > maxPinLength {
            return String(format: NSLocalizedString("El PIN de %@ normalmente tiene %lld dígitos como máximo.", comment: ""), bankName, maxPinLength)
        }
        return nil
    }

    static func special(forBankId bankId: String) -> KeyCategory? {
        allCases.first { $0.bankId == bankId }
    }
}

// MARK: - Reminders
enum ReminderRecurrenceKind: String, Codable, CaseIterable, Identifiable {
    case none, daily, weekly, monthly, custom

    var id: String { rawValue }

    var label: String {
        let key: String
        switch self {
        case .none: key = "Una vez"
        case .daily: key = "Cada día"
        case .weekly: key = "Cada semana"
        case .monthly: key = "Cada mes"
        case .custom: key = "Cada N días"
        }
        return NSLocalizedString(key, comment: "")
    }
}

/// What saved data (if any) a reminder is tied to, so its detail screen can show the real
/// bill/account value and copy it to the clipboard before dialing — the whole point of "ya con
/// la factura y todo guardado" instead of a bare text reminder.
enum ReminderLinkType: String, Codable, CaseIterable {
    case none, bill, nautaAccount, bankAccount
}

struct Reminder: Codable, Identifiable, Equatable {
    var id = UUID()
    var title: String
    var message: String
    var iconName: String
    /// Fixed USSD dial string snapshotted from the template at creation time (e.g. "*444*41#").
    /// Nil for a fully custom reminder with no direct action — same code across bpa/bandec/bm for
    /// every templated operation, so no bankId needs to be carried alongside it.
    var ussdCode: String?
    var linkType: ReminderLinkType = .none
    var linkedID: UUID? = nil
    var date: Date
    var recurrence: ReminderRecurrenceKind = .monthly
    /// Only meaningful when `recurrence == .custom`.
    var customIntervalDays: Int = 30
    var isEnabled: Bool = true
    /// Which `ReminderTemplate.id` this came from, so the quick-toggle list in Recordatorios can
    /// tell which template row it belongs to. Nil for a custom (from-scratch) reminder.
    var templateKey: String? = nil
}

/// A starting point offered in the Recordatorios "+" flow: prefills title/message/icon/USSD code
/// and, when `linkType != .none`, lets the user pick which saved bill/Nauta/card it's about.
struct ReminderTemplate: Identifiable {
    let id: String
    private let rawTitle: String
    private let rawMessage: String
    let iconName: String
    let ussdCode: String?
    let linkType: ReminderLinkType
    /// Narrows the bill picker to this type when `linkType == .bill`. Nil otherwise.
    let billType: BillType?
    let defaultRecurrence: ReminderRecurrenceKind

    /// Localized at access time so every consumer (Label, navigationTitle, string
    /// interpolation) gets translated text without needing a LocalizedStringKey wrapper.
    var title: String { NSLocalizedString(rawTitle, comment: "") }
    var message: String { rawMessage.isEmpty ? "" : NSLocalizedString(rawMessage, comment: "") }

    init(id: String, title: String, message: String, iconName: String, ussdCode: String?, linkType: ReminderLinkType, billType: BillType?, defaultRecurrence: ReminderRecurrenceKind) {
        self.id = id
        self.rawTitle = title
        self.rawMessage = message
        self.iconName = iconName
        self.ussdCode = ussdCode
        self.linkType = linkType
        self.billType = billType
        self.defaultRecurrence = defaultRecurrence
    }

    static let quickTemplates: [ReminderTemplate] = [
        ReminderTemplate(id: "luz", title: "Pagar Luz", message: "Recuerda pagar la factura de electricidad.", iconName: "bolt.fill", ussdCode: "*444*41#", linkType: .bill, billType: .electricity, defaultRecurrence: .monthly),
        ReminderTemplate(id: "agua", title: "Pagar Agua", message: "Recuerda pagar la factura de agua.", iconName: "drop.fill", ussdCode: "*444*51#", linkType: .bill, billType: .water, defaultRecurrence: .monthly),
        ReminderTemplate(id: "gas", title: "Pagar Gas", message: "Recuerda pagar la factura de gas.", iconName: "flame.fill", ussdCode: "*444*67#", linkType: .bill, billType: .gas, defaultRecurrence: .monthly),
        ReminderTemplate(id: "telefono", title: "Pagar Teléfono", message: "Recuerda pagar la factura de teléfono.", iconName: "phone.fill", ussdCode: "*444*42#", linkType: .bill, billType: .telephone, defaultRecurrence: .monthly),
        ReminderTemplate(id: "nauta", title: "Recargar Nauta", message: "Recuerda recargar tu cuenta Nauta.", iconName: "wifi", ussdCode: "*444*59#", linkType: .nautaAccount, billType: nil, defaultRecurrence: .monthly),
        ReminderTemplate(id: "transferencia", title: "Hacer Transferencia", message: "Recuerda hacer tu transferencia.", iconName: "arrow.left.arrow.right", ussdCode: "*444*45#", linkType: .bankAccount, billType: nil, defaultRecurrence: .none),
    ]

    /// The "start from scratch" option: no fixed code, no linked data — just title/message/date.
    static let custom = ReminderTemplate(id: "personalizado", title: "Recordatorio Personalizado", message: "", iconName: "bell.fill", ussdCode: nil, linkType: .none, billType: nil, defaultRecurrence: .none)
}

// MARK: - Auto-copy Behaviour (Settings)
/// What the app does when an operation needs a stored value. Shared by every prefill flow;
/// only the wording differs between flows that copy straight away and flows that ask first.
enum PrefillCopyMode: Int, CaseIterable, Identifiable {
    case copyAndNotify = 0
    case copyOnly = 1
    case disabled = 2

    var id: Int { rawValue }

    /// Flows that copy a single stored value with no picker (the bank PIN).
    var directLabel: String {
        switch self {
        case .copyAndNotify: return "Copiar y avisar"
        case .copyOnly: return "Copiar sin aviso"
        case .disabled: return "No copiar"
        }
    }

    /// Flows that first list the saved values to choose from (service bills).
    var pickerLabel: String {
        switch self {
        case .copyAndNotify: return "Mostrar listado y avisar"
        case .copyOnly: return "Mostrar listado sin aviso"
        case .disabled: return "No mostrar listado"
        }
    }
}

