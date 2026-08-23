import CryptoKit
import SwiftUI
import Network
import CoreTelephony
import UniformTypeIdentifiers

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
    /// Not wired yet: a BankAccount card number picker before dialing.
    case cardNumber
    /// Not wired yet: a NautaAccount picker before dialing.
    case nautaAccount

    /// Parses the `prefill` field of codes.json. Unknown identifiers resolve to nil (treated as `.none`).
    init?(identifier: String) {
        switch identifier {
        case "authKey": self = .authKey
        case "cardNumber": self = .cardNumber
        case "nautaAccount": self = .nautaAccount
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
        case .cardNumber:
            // TODO: present the corresponding picker sheet and copy the chosen value before dialing.
            break
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
    private func requestSelection(title: String, options: [PrefillOption], operation: BankOperation, modeKey: String) -> Bool {
        guard mode(forKey: modeKey) != .disabled else { return false }
        guard !options.isEmpty else { return false }

        pendingSelection = PrefillSelectionRequest(title: title, options: options, operation: operation, modeKey: modeKey)
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
