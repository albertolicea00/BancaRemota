import CryptoKit
import SwiftUI
import Network
import CoreTelephony
import UniformTypeIdentifiers
import Contacts
import UserNotifications
import AppIntents

let AppVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
let AppBuild = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"

// MARK: - Data Management Service
class DataService {
    static let shared = DataService()

    private var cachedConfig: BankConfig?

    private init() {}

    /// Loads the bank configuration from the bundled codes.json file
    func loadConfiguration() -> BankConfig? {
        if let cachedConfig = cachedConfig { return cachedConfig }

        guard let url = Bundle.main.url(forResource: "codes", withExtension: "json") else {
            print("Error: Could not locate codes.json in bundle.")
            return nil
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            let config = try decoder.decode(BankConfig.self, from: data)
            cachedConfig = config
            return config
        } catch {
            print("Error: Failed to parse codes.json: \(error)")
            return nil
        }
    }

    /// Bank lookup by id, for the services that only carry a bankId (favorites, operation runner).
    func bank(id: String) -> Bank? {
        loadConfiguration()?.banks.first { $0.id == id }
    }

    /// Current definition of an operation. Favorites hold a snapshot encoded when they were added,
    /// so anything acting on an operation should re-resolve it through here.
    func operation(id: String, bankId: String) -> BankOperation? {
        bank(id: bankId)?.categories.flatMap { $0.operations }.first { $0.id == id }
    }

    /// USSD codes that dial to the exact same operation on every bank in `banks` — same code,
    /// so it does the same thing over the network regardless of which bank's menu it came from.
    func commonUssdCodes(in banks: [Bank]) -> Set<String> {
        guard banks.count > 1 else { return [] }
        var banksByCode: [String: Set<String>] = [:]
        for bank in banks {
            for category in bank.categories {
                for operation in category.operations {
                    banksByCode[operation.ussdCode, default: []].insert(bank.id)
                }
            }
        }
        return Set(banksByCode.filter { $0.value.count == banks.count }.keys)
    }
}

import LocalAuthentication
import SwiftUI

// MARK: - Authentication Service
class AuthManager: ObservableObject {
    static let shared = AuthManager()
    
    @AppStorage("authEnabled") private var authEnabled: Bool = false
    @AppStorage("authExpiration") private var authExpiration: Double = 1.0
    // Use lastLeaveTime to measure how long the app was closed or in the background
    @AppStorage("lastLeaveTime") private var lastLeaveTime: Double = 0
    
    @Published var isAuthenticated: Bool = false
    @Published var isAuthenticating: Bool = false
    
    private var wasInBackground: Bool = true
    
    private init() {
        checkExpiration()
    }
    
    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if wasInBackground {
                checkExpiration()
                if !isAuthenticated && !isAuthenticating {
                    authenticate()
                }
                wasInBackground = false
            }
        case .background:
            wasInBackground = true
            lastLeaveTime = Date().timeIntervalSince1970
        case .inactive:
            break
        @unknown default:
            break
        }
    }
    
    func checkExpiration() {
        if !authEnabled {
            isAuthenticated = true
            return
        }
        
        if lastLeaveTime == 0 {
            isAuthenticated = false
            return
        }
        
        let now = Date().timeIntervalSince1970
        let expirationSeconds = authExpiration * 60.0
        
        if (now - lastLeaveTime) >= expirationSeconds {
            isAuthenticated = false
        } else {
            isAuthenticated = true
        }
    }
    
    func authenticate() {
        if !authEnabled {
            isAuthenticated = true
            return
        }
        
        let context = LAContext()
        var error: NSError?
        let reason = "Autentícate para acceder a Banca Remota"
        
        let policy: LAPolicy = .deviceOwnerAuthentication
        
        if context.canEvaluatePolicy(policy, error: &error) {
            isAuthenticating = true
            context.evaluatePolicy(policy, localizedReason: reason) { success, _ in
                DispatchQueue.main.async {
                    self.isAuthenticating = false
                    if success {
                        self.isAuthenticated = true
                    }
                }
            }
        } else {
            self.isAuthenticated = true
        }
    }
}

// MARK: - Cellular Signal Monitor
class CellularMonitor: ObservableObject {
    static let shared = CellularMonitor()
    let telephonyInfo = CTTelephonyNetworkInfo()
    
    @Published var hasService: Bool = false
    @Published var networkType: String = "Buscando..."
    @Published var signalQuality: Int = 0 // 0 to 3
    
    private init() {
        updateCellularStatus()
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateCellularStatus), name: .CTServiceRadioAccessTechnologyDidChange, object: nil)
    }
    
    @objc private func updateCellularStatus() {
        DispatchQueue.main.async {
            // Check whether any cellular radio technology is currently active
            guard let techDict = self.telephonyInfo.serviceCurrentRadioAccessTechnology,
                  let tech = techDict.values.first, !tech.isEmpty else {
                self.hasService = false
                self.networkType = "Sin Servicio Celular"
                self.signalQuality = 0
                return
            }
            
            self.hasService = true
            
            switch tech {
            case CTRadioAccessTechnologyNR, CTRadioAccessTechnologyNRNSA:
                self.networkType = "5G"
                self.signalQuality = 3
            case CTRadioAccessTechnologyLTE:
                self.networkType = "4G / LTE"
                self.signalQuality = 3
            case CTRadioAccessTechnologyWCDMA, CTRadioAccessTechnologyHSDPA, CTRadioAccessTechnologyHSUPA, CTRadioAccessTechnologyCDMA1x, CTRadioAccessTechnologyCDMAEVDORev0, CTRadioAccessTechnologyCDMAEVDORevA, CTRadioAccessTechnologyCDMAEVDORevB, CTRadioAccessTechnologyeHRPD:
                self.networkType = "3G"
                self.signalQuality = 2
            case CTRadioAccessTechnologyEdge, CTRadioAccessTechnologyGPRS:
                self.networkType = "2G / EDGE"
                self.signalQuality = 1
            default:
                self.networkType = "Red Celular"
                self.signalQuality = 2
            }
        }
    }
}

// MARK: - Telephony/USSD Service
class CallService {
    static let shared = CallService()
    
    private init() {}
    
    /// Executes a USSD code by opening the system dialer
    func executeUSSD(code: String) {
        // Encodings like # need to be %23 in URL scheme
        let encodedCode = code.addingPercentEncoding(withAllowedCharacters: CharacterSet(charactersIn: "#").inverted) ?? code
        
        guard let url = URL(string: "tel://\(encodedCode)") else {
            print("Error: Invalid URL format for code: \(code)")
            return
        }
        
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:]) { success in
                if success {
                    print("Service: Successfully opened USSD code: \(code)")
                } else {
                    print("Service: Failed to open USSD code: \(code)")
                }
            }
        } else {
            print("Error: Cannot open tel:// URL on this device (Simulator or restricted).")
        }
    }
}

// MARK: - Clipboard Service
class ClipboardService {
    static let shared = ClipboardService()

    private init() {}

    /// Copies a secret (PIN, password, card number). Never leaves the device via Universal Clipboard
    /// and the system drops it after `expiresIn` so it does not sit in the pasteboard forever.
    func copySensitive(_ value: String, expiresIn: TimeInterval = 120) {
        UIPasteboard.general.setItems(
            [[UTType.utf8PlainText.identifier: value]],
            options: [
                .localOnly: true,
                .expirationDate: Date().addingTimeInterval(expiresIn)
            ]
        )
    }
}

// MARK: - Contacts Service
/// Reads the address book so the app can render its own contact list instead of the system picker.
/// This needs full read access (NSContactsUsageDescription); nothing is stored or sent anywhere.
class ContactsService {
    static let shared = ContactsService()

    private let store = CNContactStore()

    private init() {}

    var authorizationStatus: CNAuthorizationStatus {
        CNContactStore.authorizationStatus(for: .contacts)
    }

    /// Requests access if needed, then loads every phone number as a selectable option.
    /// Calls back on the main queue with an empty array when access is refused or nothing is stored.
    func loadPhoneOptions(completion: @escaping ([PrefillOption]) -> Void) {
        switch authorizationStatus {
        case .authorized:
            fetch(completion: completion)
        case .notDetermined:
            store.requestAccess(for: .contacts) { granted, _ in
                if granted {
                    self.fetch(completion: completion)
                } else {
                    DispatchQueue.main.async { completion([]) }
                }
            }
        default:
            DispatchQueue.main.async { completion([]) }
        }
    }

    private func fetch(completion: @escaping ([PrefillOption]) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let keys: [CNKeyDescriptor] = [
                CNContactFormatter.descriptorForRequiredKeys(for: .fullName),
                CNContactPhoneNumbersKey as CNKeyDescriptor
            ]
            let request = CNContactFetchRequest(keysToFetch: keys)
            request.sortOrder = .givenName

            var options: [PrefillOption] = []

            do {
                try self.store.enumerateContacts(with: request) { contact, _ in
                    let name = CNContactFormatter.string(from: contact, style: .fullName) ?? ""

                    for phone in contact.phoneNumbers {
                        let number = Self.normalize(phone.value.stringValue)
                        guard !number.isEmpty else { continue }

                        let phoneLabel = phone.label.map { CNLabeledValue<NSString>.localizedString(forLabel: $0) } ?? ""
                        options.append(PrefillOption(
                            id: UUID(),
                            label: name.isEmpty ? number : name,
                            value: number,
                            detail: phoneLabel,
                            iconName: "person.crop.circle"
                        ))
                    }
                }
            } catch {
                print("Contacts: failed to enumerate contacts: \(error)")
            }

            DispatchQueue.main.async { completion(options) }
        }
    }

    /// USSD prompts take bare digits. Strips formatting and the Cuban country code so a stored
    /// "+53 5 123 4567" is copied as the 8-digit "51234567" the recharge menu expects.
    static func normalize(_ rawNumber: String) -> String {
        let digits = rawNumber.filter { $0.isASCII && $0.isNumber }

        if digits.count == 10, digits.hasPrefix("53") {
            return String(digits.dropFirst(2))
        }
        return digits
    }
}

// MARK: - In-App Toast Notifications
class ToastCenter: ObservableObject {
    static let shared = ToastCenter()

    struct Toast: Equatable, Identifiable {
        let id = UUID()
        let message: String
        let iconName: String
        let isWarning: Bool
    }

    @Published var current: Toast?

    private var dismissWorkItem: DispatchWorkItem?

    private init() {}

    func show(_ message: String, iconName: String = "doc.on.clipboard.fill", isWarning: Bool = false, duration: TimeInterval = 2.5) {
        DispatchQueue.main.async {
            self.dismissWorkItem?.cancel()
            self.current = Toast(message: message, iconName: iconName, isWarning: isWarning)

            let work = DispatchWorkItem { [weak self] in
                self?.current = nil
            }
            self.dismissWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + duration, execute: work)
        }
    }
}

// MARK: - Operation Prefill + Runner
/// The piece of saved user data a USSD session will ask for once the dialer is open.
/// Single extension point for the upcoming flows (transfer -> card, utility bills -> bill number, nauta -> account).
enum OperationPrefill: Equatable {
    case none
    /// The bank's special key (KeyCategory.appBPA / .appBANDEC / .appBM).
    case authKey
    /// A saved service bill of this type, chosen from a picker before dialing.
    case bill(BillType)
    /// A saved Nauta account, chosen from a picker before dialing.
    case nautaAccount
    /// A phone number from the device address book, chosen from a searchable picker before dialing.
    case contactPhone
    /// A saved card number, chosen from a picker before dialing.
    case cardNumber

    /// Parses the `prefill` field of codes.json. Unknown identifiers resolve to nil (treated as `.none`).
    init?(identifier: String) {
        switch identifier {
        case "authKey": self = .authKey
        case "cardNumber": self = .cardNumber
        case "nautaAccount": self = .nautaAccount
        case "contactPhone": self = .contactPhone
        default:
            guard identifier.hasPrefix("bill."),
                  let type = BillType.fromPrefillIdentifier(String(identifier.dropFirst("bill.".count))) else {
                return nil
            }
            self = .bill(type)
        }
    }
}

extension BillType {
    /// Stable, language-independent identifiers used in codes.json (rawValue is user-facing Spanish).
    static func fromPrefillIdentifier(_ identifier: String) -> BillType? {
        switch identifier {
        case "electricity": return .electricity
        case "water": return .water
        case "gas": return .gas
        case "telephone": return .telephone
        default: return nil
        }
    }
}

/// One row of the prefill picker: a saved value the user can copy before dialing.
struct PrefillOption: Identifiable {
    let id: UUID
    let label: String
    let value: String
    let detail: String
    let iconName: String
}

/// A pending "pick one of your saved values, then dial" step. Presented by MainView as a sheet.
struct PrefillSelectionRequest: Identifiable {
    let id = UUID()
    let title: String
    let options: [PrefillOption]
    let operation: BankOperation
    /// UserDefaults key of the PrefillCopyMode governing this flow.
    let modeKey: String
    /// Shows a search field. Worth it for the address book, noise for a handful of saved records.
    var isSearchable: Bool = false
}

/// Every USSD launch in the app goes through here instead of calling CallService directly,
/// so the "prepare the data the USSD will ask for, then dial" step has one owner.
class OperationRunner: ObservableObject {
    static let shared = OperationRunner()

    /// Non-nil while a prefill picker is on screen. Dialing is deferred until it resolves.
    @Published var pendingSelection: PrefillSelectionRequest?

    private init() {}

    func run(_ storedOperation: BankOperation, bankId: String) {
        // Favorites persist a snapshot of the operation taken when it was added, so a snapshot from
        // an older build carries no `prefill` tag and a stale `ussdCode`. Re-resolve against codes.json.
        let operation = DataService.shared.operation(id: storedOperation.id, bankId: bankId) ?? storedOperation

        switch prefill(for: operation) {
        case .authKey:
            prepareAuthKey(bankId: bankId)
        case .bill(let type):
            // The picker dials once the user chooses, so stop here when it is shown.
            if requestBillSelection(type: type, operation: operation) { return }
        case .nautaAccount:
            if requestNautaSelection(operation: operation) { return }
        case .contactPhone:
            if requestContactSelection(operation: operation) { return }
        case .cardNumber:
            if requestCardSelection(operation: operation) { return }
        case .none:
            break
        }

        CallService.shared.executeUSSD(code: operation.ussdCode)
    }

    /// Central resolver: decides what a given operation needs.
    func prefill(for operation: BankOperation) -> OperationPrefill {
        if operation.isLogin == true { return .authKey }
        if let identifier = operation.prefill, let parsed = OperationPrefill(identifier: identifier) {
            return parsed
        }
        return .none
    }

    private func mode(forKey key: String) -> PrefillCopyMode {
        PrefillCopyMode(rawValue: UserDefaults.standard.integer(forKey: key)) ?? .copyAndNotify
    }

    // MARK: Auth key
    private func prepareAuthKey(bankId: String) {
        let mode = mode(forKey: "authKeyCopyMode")
        guard mode != .disabled else { return }
        guard let category = KeyCategory.special(forBankId: bankId) else { return }

        let bankName = DataService.shared.bank(id: bankId)?.shortName ?? bankId.uppercased()

        // No key stored for this bank: dial silently, no error and no notification.
        guard let key = UserDataManager.shared.userKeys.first(where: { $0.category == category }) else { return }

        ClipboardService.shared.copySensitive(key.value)

        if mode == .copyAndNotify {
            ToastCenter.shared.show("Clave de \(bankName) copiada al portapapeles")
        }
    }

    // MARK: Picker flows
    /// Returns true when the picker was shown, meaning the caller must not dial yet.
    private func requestSelection(title: String, options: [PrefillOption], operation: BankOperation, modeKey: String, isSearchable: Bool = false) -> Bool {
        guard mode(forKey: modeKey) != .disabled else { return false }
        guard !options.isEmpty else { return false }

        pendingSelection = PrefillSelectionRequest(title: title, options: options, operation: operation, modeKey: modeKey, isSearchable: isSearchable)
        return true
    }

    private func requestBillSelection(type: BillType, operation: BankOperation) -> Bool {
        let options = UserDataManager.shared.bills
            .filter { $0.type == type }
            .map { PrefillOption(id: $0.id, label: $0.label, value: $0.billNumber, detail: $0.group, iconName: type.iconName) }

        return requestSelection(title: "Pagar \(type.rawValue)", options: options, operation: operation, modeKey: "billCopyMode")
    }

    private func requestNautaSelection(operation: BankOperation) -> Bool {
        let options = UserDataManager.shared.nautaAccounts.map { account in
            PrefillOption(
                id: account.id,
                label: account.label,
                value: account.account,
                detail: [account.type, account.group].filter { !$0.isEmpty }.joined(separator: " · "),
                iconName: "wifi"
            )
        }

        return requestSelection(title: operation.name, options: options, operation: operation, modeKey: "nautaCopyMode")
    }

    private func requestCardSelection(operation: BankOperation) -> Bool {
        let options = UserDataManager.shared.bankAccounts.map { account in
            PrefillOption(
                id: account.id,
                label: account.label.isEmpty ? account.name : account.label,
                value: account.cardNumber,
                detail: [account.name, account.group].filter { !$0.isEmpty }.joined(separator: " · "),
                iconName: "creditcard.fill"
            )
        }

        return requestSelection(title: operation.name, options: options, operation: operation, modeKey: "cardCopyMode")
    }

    /// Contacts cannot be read synchronously, so this always takes ownership of the dialing:
    /// it returns true and either presents the picker or dials once the address book resolves.
    private func requestContactSelection(operation: BankOperation) -> Bool {
        let mode = self.mode(forKey: "contactCopyMode")
        guard mode != .disabled else { return false }

        let wasDenied = ContactsService.shared.authorizationStatus == .denied

        ContactsService.shared.loadPhoneOptions { options in
            if options.isEmpty {
                // Access refused or address book empty: the user gets no picker, so say why
                // when it is something they can act on, then dial anyway.
                if wasDenied && mode == .copyAndNotify {
                    ToastCenter.shared.show(
                        "Sin acceso a Contactos. Actívalo en Ajustes › Banca Remota.",
                        iconName: "exclamationmark.triangle.fill",
                        isWarning: true
                    )
                }
                CallService.shared.executeUSSD(code: operation.ussdCode)
                return
            }

            self.pendingSelection = PrefillSelectionRequest(
                title: operation.name,
                options: options,
                operation: operation,
                modeKey: "contactCopyMode",
                isSearchable: true
            )
        }

        return true
    }

    /// Resolves the picker. `option == nil` is the "Ninguna" row: dial without copying anything.
    func completeSelection(_ option: PrefillOption?) {
        guard let request = pendingSelection else { return }
        pendingSelection = nil

        if let option = option {
            ClipboardService.shared.copySensitive(option.value)
            if mode(forKey: request.modeKey) == .copyAndNotify {
                ToastCenter.shared.show("Copiado al portapapeles: \(option.label)")
            }
        }

        // Let the sheet finish dismissing before the system dialer prompt takes over.
        let code = request.operation.ussdCode
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            CallService.shared.executeUSSD(code: code)
        }
    }
}

// MARK: - Keychain Helper
class KeychainHelper {
    static let shared = KeychainHelper()
    
    func save(_ string: String, service: String, account: String) {
        guard let data = string.data(using: .utf8) else { return }
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data
        ] as [String: Any]
        
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }
    
    func read(service: String, account: String) -> String? {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: kCFBooleanTrue!,
            kSecMatchLimit as String: kSecMatchLimitOne
        ] as [String: Any]
        
        var dataTypeRef: AnyObject?
        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        
        if status == noErr, let data = dataTypeRef as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
    
    func delete(service: String, account: String) {
        let query = [
            kSecClass as String: kSecClassGenericPassword as String,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ] as [String: Any]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - User Backup Structure
struct UserBackup: Codable {
    var nautaAccounts: [NautaAccount]?
    var bankAccounts: [BankAccount]?
    var bills: [Bill]?
    var userKeys: [UserKey]?
    var timestamp: Date = Date()
}

// MARK: - User Data Service (CRUD)
class UserDataManager: ObservableObject {
    static let shared = UserDataManager()
    
    @AppStorage("iCloudSyncEnabled") var iCloudSyncEnabled = false
    @Published var iCloudEncryptionPassword = "" {
        didSet {
            KeychainHelper.shared.save(iCloudEncryptionPassword, service: "BancaRemota", account: "SyncPassword")
        }
    }
    
    @Published var nautaAccounts: [NautaAccount] = [] { didSet { save() } }
    @Published var bankAccounts: [BankAccount] = [] { didSet { save() } }
    @Published var bills: [Bill] = [] { didSet { save() } }
    @Published var userKeys: [UserKey] = [] { didSet { save() } }
    @Published var activeSwipeID: UUID? = nil
    
    private init() {
        iCloudEncryptionPassword = KeychainHelper.shared.read(service: "BancaRemota", account: "SyncPassword") ?? ""
        load()
        setupICloudNotifications()
    }
    
    private func setupICloudNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudDataDidChange),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default
        )
        NSUbiquitousKeyValueStore.default.synchronize()
    }
    
    @objc private func iCloudDataDidChange(notification: Notification) {
        if iCloudSyncEnabled {
            DispatchQueue.main.async {
                self.loadFromICloud()
            }
        }
    }
    
    // MARK: - Special Keys (one per bank)
    /// The single key stored under the special category of that bank, if any.
    func specialKey(forBankId bankId: String) -> UserKey? {
        guard let category = KeyCategory.special(forBankId: bankId) else { return nil }
        return userKeys.first { $0.category == category }
    }

    /// False when another key already occupies that special category.
    func canUseSpecialCategory(_ category: KeyCategory, excluding id: UUID?) -> Bool {
        guard category.isSpecial else { return true }
        return !userKeys.contains { $0.category == category && $0.id != id }
    }

    func createBackup(includeNauta: Bool, includeBanks: Bool, includeBills: Bool, includeKeys: Bool) -> URL? {
        let backup = UserBackup(
            nautaAccounts: includeNauta ? nautaAccounts : nil,
            bankAccounts: includeBanks ? bankAccounts : nil,
            bills: includeBills ? bills : nil,
            userKeys: includeKeys ? userKeys : nil
        )
        
        guard let data = try? JSONEncoder().encode(backup) else { return nil }
        
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HHmm"
        let dateString = formatter.string(from: Date())
        let fileName = "BancaRemota_Backup_\(dateString).json"
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try? data.write(to: tempURL)
        return tempURL
    }
    
    func importBackup(from url: URL) -> Bool {
        guard let data = try? Data(contentsOf: url),
              let backup = try? JSONDecoder().decode(UserBackup.self, from: data) else {
            return false
        }
        
        if let nauta = backup.nautaAccounts { self.nautaAccounts = nauta }
        if let banks = backup.bankAccounts { self.bankAccounts = banks }
        if let bills = backup.bills { self.bills = bills }
        if let keys = backup.userKeys { self.userKeys = keys }
        
        return true
    }
    
    private func save() {
        let nauta = self.nautaAccounts
        let banks = self.bankAccounts
        let bills = self.bills
        let keys = self.userKeys
        let syncEnabled = self.iCloudSyncEnabled
        let password = self.iCloudEncryptionPassword
        
        // Execute heavy encoding and encryption in a background thread to keep UI smooth
        DispatchQueue.global(qos: .background).async {
            let encoder = JSONEncoder()
            
            // Local save (UserDefaults is thread-safe)
            if let encoded = try? encoder.encode(nauta) { UserDefaults.standard.set(encoded, forKey: "nautaAccounts") }
            if let encoded = try? encoder.encode(banks) { UserDefaults.standard.set(encoded, forKey: "bankAccounts") }
            if let encoded = try? encoder.encode(bills) { UserDefaults.standard.set(encoded, forKey: "bills") }
            if let encoded = try? encoder.encode(keys) { UserDefaults.standard.set(encoded, forKey: "userKeys") }
            
            // iCloud save
            if syncEnabled {
                let store = NSUbiquitousKeyValueStore.default
                
                if let encoded = try? encoder.encode(nauta), let encrypted = self.encryptData(encoded, with: password) { store.set(encrypted, forKey: "nautaAccounts") }
                if let encoded = try? encoder.encode(banks), let encrypted = self.encryptData(encoded, with: password) { store.set(encrypted, forKey: "bankAccounts") }
                if let encoded = try? encoder.encode(bills), let encrypted = self.encryptData(encoded, with: password) { store.set(encrypted, forKey: "bills") }
                if let encoded = try? encoder.encode(keys), let encrypted = self.encryptData(encoded, with: password) { store.set(encrypted, forKey: "userKeys") }
                
                store.synchronize()
            }
        }
    }
    
    private func load() {
        // First try local
        if let data = UserDefaults.standard.data(forKey: "nautaAccounts"), let decoded = try? JSONDecoder().decode([NautaAccount].self, from: data) { nautaAccounts = decoded }
        if let data = UserDefaults.standard.data(forKey: "bankAccounts"), let decoded = try? JSONDecoder().decode([BankAccount].self, from: data) { bankAccounts = decoded }
        if let data = UserDefaults.standard.data(forKey: "bills"), let decoded = try? JSONDecoder().decode([Bill].self, from: data) { bills = decoded }
        if let data = UserDefaults.standard.data(forKey: "userKeys"), let decoded = try? JSONDecoder().decode([UserKey].self, from: data) { userKeys = decoded }
        
        // If iCloud enabled, try to merge/update from iCloud
        if iCloudSyncEnabled {
            loadFromICloud()
        }
    }
    
    private func loadFromICloud() {
        let store = NSUbiquitousKeyValueStore.default
        let password = self.iCloudEncryptionPassword
        
        if let data = store.data(forKey: "nautaAccounts"), let decrypted = decryptData(data, with: password), let decoded = try? JSONDecoder().decode([NautaAccount].self, from: decrypted) { nautaAccounts = decoded }
        if let data = store.data(forKey: "bankAccounts"), let decrypted = decryptData(data, with: password), let decoded = try? JSONDecoder().decode([BankAccount].self, from: decrypted) { bankAccounts = decoded }
        if let data = store.data(forKey: "bills"), let decrypted = decryptData(data, with: password), let decoded = try? JSONDecoder().decode([Bill].self, from: decrypted) { bills = decoded }
        if let data = store.data(forKey: "userKeys"), let decrypted = decryptData(data, with: password), let decoded = try? JSONDecoder().decode([UserKey].self, from: decrypted) { userKeys = decoded }
    }
    
    // MARK: - Encryption Helpers
    private func encryptData(_ data: Data, with password: String) -> Data? {
        guard !password.isEmpty else { return data }
        let key = SHA256.hash(data: Data(password.utf8))
        let symmetricKey = SymmetricKey(data: key)
        do {
            let sealedBox = try AES.GCM.seal(data, using: symmetricKey)
            return sealedBox.combined
        } catch {
            print("Encryption Error: \(error)")
            return nil
        }
    }
    
    private func decryptData(_ data: Data, with password: String) -> Data? {
        guard !password.isEmpty else { return data }
        let key = SHA256.hash(data: Data(password.utf8))
        let symmetricKey = SymmetricKey(data: key)
        do {
            let sealedBox = try AES.GCM.SealedBox(combined: data)
            let decryptedData = try AES.GCM.open(sealedBox, using: symmetricKey)
            return decryptedData
        } catch {
            print("Decryption Error: \(error)")
            return nil
        }
    }
}

// MARK: - Reminders
/// Local notifications only — no server, no push, consistent with the app's "no internet
/// required" model. Persists to UserDefaults like `UserDataManager` and mirrors every stored
/// `Reminder` to a scheduled `UNNotificationRequest` (or several, chained, for `.custom`).
class ReminderManager: NSObject, ObservableObject, UNUserNotificationCenterDelegate {
    static let shared = ReminderManager()

    static let categoryId = "REMINDER_CATEGORY"
    static let markDoneAction = "REMINDER_MARK_DONE"
    static let snoozeAction = "REMINDER_SNOOZE_1_DAY"

    @Published var reminders: [Reminder] = [] { didSet { save(); rescheduleAll() } }
    /// Set by the notification-tap handler; MainView presents this as a sheet so the user lands
    /// on the reminder's own detail (with its linked data and an "Ejecutar" button) instead of a
    /// bare banner.
    @Published var deepLinkReminder: Reminder?

    private override init() {
        super.init()
        load()
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().setNotificationCategories([
            UNNotificationCategory(
                identifier: Self.categoryId,
                actions: [
                    UNNotificationAction(identifier: Self.markDoneAction, title: "Marcar como hecho", options: []),
                    UNNotificationAction(identifier: Self.snoozeAction, title: "Posponer 1 día", options: []),
                ],
                intentIdentifiers: [],
                options: []
            )
        ])
    }

    func requestAuthorizationIfNeeded(completion: ((Bool) -> Void)? = nil) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion?(granted) }
        }
    }

    func add(_ reminder: Reminder) {
        reminders.append(reminder)
    }

    func update(_ reminder: Reminder) {
        guard let index = reminders.firstIndex(where: { $0.id == reminder.id }) else { return }
        reminders[index] = reminder
    }

    func delete(_ reminder: Reminder) {
        reminders.removeAll { $0.id == reminder.id }
    }

    func setEnabled(_ isEnabled: Bool, for reminder: Reminder) {
        guard var updated = reminders.first(where: { $0.id == reminder.id }) else { return }
        updated.isEnabled = isEnabled
        update(updated)
    }

    /// Every reminder created from `templateId` — plural because the same template can be reused
    /// any number of times (e.g. "Pagar Luz" for two houses, or several Nauta accounts).
    func reminders(forTemplate templateId: String) -> [Reminder] {
        reminders.filter { $0.templateKey == templateId }
    }

    var customReminders: [Reminder] {
        reminders.filter { $0.templateKey == nil }
    }

    // MARK: Linked data
    /// Display label + copyable value for whatever this reminder is linked to, resolved live
    /// against `UserDataManager` (never a stale snapshot) — nil when unlinked or the linked item
    /// was since deleted.
    func linkedInfo(for reminder: Reminder) -> (label: String, value: String)? {
        guard let linkedID = reminder.linkedID else { return nil }
        let userData = UserDataManager.shared
        switch reminder.linkType {
        case .bill:
            guard let bill = userData.bills.first(where: { $0.id == linkedID }) else { return nil }
            return (bill.label, bill.billNumber)
        case .nautaAccount:
            guard let account = userData.nautaAccounts.first(where: { $0.id == linkedID }) else { return nil }
            return (account.label, account.account)
        case .bankAccount:
            guard let account = userData.bankAccounts.first(where: { $0.id == linkedID }) else { return nil }
            return (account.label.isEmpty ? account.name : account.label, account.cardNumber)
        case .none:
            return nil
        }
    }

    /// Copies the linked value (if any) to the clipboard, then dials the reminder's USSD code —
    /// same "copy then dial" sequence `OperationRunner` already does for a picked bill/account.
    func execute(_ reminder: Reminder) {
        if let info = linkedInfo(for: reminder) {
            ClipboardService.shared.copySensitive(info.value)
            ToastCenter.shared.show("Copiado al portapapeles: \(info.label)")
        }
        guard let code = reminder.ussdCode else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            CallService.shared.executeUSSD(code: code)
        }
    }

    // MARK: Scheduling
    private func rescheduleAll() {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        for reminder in reminders where reminder.isEnabled {
            schedule(reminder)
        }
    }

    private func schedule(_ reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = reminder.title
        content.body = linkedInfo(for: reminder).map { "\(reminder.message) (\($0.label): \($0.value))" } ?? reminder.message
        content.sound = .default
        content.categoryIdentifier = Self.categoryId
        content.userInfo = ["reminderID": reminder.id.uuidString]

        let calendar = Calendar.current
        let request: UNNotificationRequest

        switch reminder.recurrence {
        case .none:
            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: reminder.date), repeats: false)
            request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        case .daily:
            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.hour, .minute], from: reminder.date), repeats: true)
            request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        case .weekly:
            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.weekday, .hour, .minute], from: reminder.date), repeats: true)
            request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        case .monthly:
            // iOS simply skips a month that doesn't have this day (e.g. day 31 in February) —
            // acceptable for a bill reminder, which is what this recurrence is meant for.
            let trigger = UNCalendarNotificationTrigger(dateMatching: calendar.dateComponents([.day, .hour, .minute], from: reminder.date), repeats: true)
            request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        case .custom:
            // A repeating time-interval trigger fires `interval` seconds after it's *scheduled*,
            // not at `reminder.date` — iOS has no "start on this date, then repeat every N days"
            // trigger. The chosen date/time only seeds the first schedule() call; after that it
            // drifts to whenever the app last rescheduled it.
            let interval = max(60, TimeInterval(reminder.customIntervalDays) * 86400)
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: true)
            request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: trigger)
        }

        UNUserNotificationCenter.current().add(request)
    }

    // MARK: Persistence
    private func save() {
        if let encoded = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(encoded, forKey: "reminders")
        }
    }

    private func load() {
        if let data = UserDefaults.standard.data(forKey: "reminders"),
           let decoded = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = decoded
        }
    }

    // MARK: UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        defer { completionHandler() }
        guard let idString = response.notification.request.content.userInfo["reminderID"] as? String,
              let id = UUID(uuidString: idString),
              let reminder = reminders.first(where: { $0.id == id }) else { return }

        switch response.actionIdentifier {
        case Self.markDoneAction:
            setEnabled(false, for: reminder)
        case Self.snoozeAction:
            let content = UNMutableNotificationContent()
            content.title = reminder.title
            content.body = reminder.message
            content.sound = .default
            content.categoryIdentifier = Self.categoryId
            content.userInfo = ["reminderID": reminder.id.uuidString]
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 86400, repeats: false)
            let request = UNNotificationRequest(identifier: "\(reminder.id.uuidString)_snooze_\(UUID().uuidString)", content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request)
        default:
            DispatchQueue.main.async {
                self.deepLinkReminder = reminder
            }
        }
    }
}

// MARK: - Siri / App Intents
/// Lets Siri, Spotlight, and the Shortcuts app run a bank operation directly — "Hey Siri, marca
/// Consultar Saldo en Banca Remota". Built on `AppIntents` (not the legacy SiriKit
/// `Intents.framework`), so it needs no separate extension target or Siri entitlement: the system
/// discovers `BancaRemotaShortcuts` by reflection at install time.
///
/// Every intent here re-enters the exact same pipeline a tap would (`OperationRunner.run`), so it
/// respects the user's copy-mode settings (§5.3/§5.4 in ARCHITECTURE.md) and can still present the
/// in-app bill/Nauta/card picker — `openAppWhenRun` brings the app to the foreground first so that
/// picker (and the system's own dial confirmation) has somewhere to appear. Nothing dials silently
/// in the background.
@available(iOS 16.0, *)
enum BankOption: String, AppEnum {
    case bpa, bandec, bm

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Banco"

    static var caseDisplayRepresentations: [BankOption: DisplayRepresentation] = [
        .bpa: "BPA",
        .bandec: "BANDEC",
        .bm: "BM",
    ]
}

/// A curated set of operations whose `codes.json` id is identical across `bpa`/`bandec`/`bm`
/// (verified against the catalog), so one `operationId` per case covers all three banks — Siri
/// only needs to ask which bank, never which operation id.
@available(iOS 16.0, *)
enum QuickBankOperation: String, AppEnum {
    case consultarSaldo, pagarLuz, pagarAgua, pagarGas, pagarTelefono, recargarNauta, transferencia, autenticarse

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Operación"

    static var caseDisplayRepresentations: [QuickBankOperation: DisplayRepresentation] = [
        .consultarSaldo: "Consultar Saldo",
        .pagarLuz: "Pagar Luz",
        .pagarAgua: "Pagar Agua",
        .pagarGas: "Pagar Gas",
        .pagarTelefono: "Pagar Teléfono",
        .recargarNauta: "Recargar Nauta",
        .transferencia: "Transferencia",
        .autenticarse: "Autenticarse",
    ]

    var operationId: String {
        switch self {
        case .consultarSaldo: return "op_2"
        case .pagarLuz: return "op_6"
        case .pagarAgua: return "op_9"
        case .pagarGas: return "op_23"
        case .pagarTelefono: return "op_7"
        case .recargarNauta: return "op_21"
        case .transferencia: return "op_4"
        case .autenticarse: return "op_0"
        }
    }
}

@available(iOS 16.0, *)
struct EjecutarOperacionIntent: AppIntent {
    static var title: LocalizedStringResource = "Ejecutar Operación Bancaria"
    static var description = IntentDescription("Marca una operación de Banca Remota (saldo, pagos, transferencia, autenticación) en el banco que elijas.")
    static var openAppWhenRun: Bool = true

    @Parameter(title: "Operación")
    var operacion: QuickBankOperation

    @Parameter(title: "Banco", default: .bpa)
    var banco: BankOption

    init() {}

    /// Lets `BancaRemotaShortcuts` pre-fill this intent for a fixed-phrase shortcut (e.g.
    /// "Consulta mi saldo en Banca Remota" always means `.consultarSaldo`) — the App Intents
    /// build-time tooling that extracts Siri suggestions only recognizes a direct initializer
    /// call like this, not a property assigned after `Self()`.
    init(operacion: QuickBankOperation, banco: BankOption = .bpa) {
        self.operacion = operacion
        self.banco = banco
    }

    static var parameterSummary: some ParameterSummary {
        Summary("\(\.$operacion) en \(\.$banco)")
    }

    @MainActor
    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard let operation = DataService.shared.operation(id: operacion.operationId, bankId: banco.rawValue) else {
            return .result(dialog: "No se encontró esa operación para ese banco.")
        }
        OperationRunner.shared.run(operation, bankId: banco.rawValue)
        return .result(dialog: "Ejecutando \(operation.name)...")
    }
}

@available(iOS 16.0, *)
struct BancaRemotaShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: EjecutarOperacionIntent(),
            phrases: [
                "Ejecuta \(\.$operacion) en \(.applicationName)",
                "Marca \(\.$operacion) en \(.applicationName)",
            ],
            shortTitle: "Ejecutar Operación",
            systemImageName: "building.columns"
        )

        AppShortcut(
            intent: EjecutarOperacionIntent(operacion: .consultarSaldo),
            phrases: [
                "Consulta mi saldo en \(.applicationName)",
                "Cuánto saldo tengo en \(.applicationName)",
            ],
            shortTitle: "Consultar Saldo",
            systemImageName: "banknote"
        )
    }
}
