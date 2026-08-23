# BancaRemota :: Architecture

**Last updated:** 2026-08-23 · **Doc version:** 1.0 · **Last commit documented:** `7ffe4e8`

---

This document describes the technical architecture of BancaRemota, a native iOS app that lets users trigger Cuban bank USSD operations (`*444*...#` style dial strings) without an internet connection, and locally manage banking-related personal data (cards, Nauta accounts, service bills, PINs/passwords).

It is a single-target SwiftUI app with no backend, no network calls, and no third-party dependencies. All persistence is local (`UserDefaults`) with an optional, user-controlled, end-to-end encrypted iCloud Key-Value sync layer.

---

## 1. High-Level Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                         BancaRemotaApp                          │
│  (App entry point · lock screen overlay · theme/scene lifecycle)│
└───────────────────────────────┬─────────────────────────────────┘
                                 │
                                 ▼
                            MainView
               (single-window navigation state machine)
                                 │
        ┌────────────┬──────────┼───────────┬───────────────┐
        ▼            ▼          ▼           ▼               ▼
  BankSelection  Operations  SideMenu   Config/Info/    Data list views
      View        ListView     View      Tutorial      (Nauta/Bank/Bills/Keys)
  (Home/Fav.)    (per bank)             (settings)           │
        │            │                                       │
        ▼            ▼                                       ▼
FavoritesManager   CallService              UserDataManager (CRUD + persistence)
   (favorites)     (opens tel:// USSD URL)           │
                                                     ├─ UserDefaults (local)
                                                     ├─ Keychain (sync password)
                                                     └─ NSUbiquitousKeyValueStore
                                                        (optional, AES-GCM encrypted)


  DataService ── loads BancaRemota/codes.json (bundled, read-only) ──▶ BankConfig
```

There is no MVVM view-model layer in the classic sense; screens are SwiftUI `View`s that read/write a handful of singleton `ObservableObject`s directly (`FavoritesManager`, `UserDataManager`, `AuthManager`, `CellularMonitor`) plus `@AppStorage` for simple flags. This keeps the codebase small (≈3,150 lines of Swift across 5 files) at the cost of view/service coupling — acceptable for an app of this scope, but worth knowing if it grows.

---

## 2. Source Layout

| File | Lines | Responsibility |
|---|---|---|
| `BancaRemota/BancaRemotaApp.swift` | 53 | `@main` entry point. Hosts `MainView`, overlays the biometric lock screen, applies the dark/light/system theme, and forwards `ScenePhase` changes to `AuthManager`. |
| `BancaRemota/Models.swift` | 218 | All `Codable` data models: static config models (`Bank`, `OperationCategory`, `BankOperation`), user-data models (`NautaAccount`, `BankAccount`, `Bill`, `UserKey`), `FavoritesManager`, and the `Color(hex:)` / `toHex()` extension. |
| `BancaRemota/Services.swift` | 414 | All singleton services: `DataService` (loads `codes.json`), `AuthManager` (biometric gate + session expiry), `CellularMonitor` (radio signal banner), `CallService` (USSD dialer), `KeychainHelper`, `UserDataManager` (CRUD + local/iCloud persistence + AES-GCM encryption). |
| `BancaRemota/UIComponents.swift` | 564 | Reusable, presentation-only views: `TopNavBar`, `ConnectionBannerView`, `OperationCard`, `BankSelectionCard`, `MenuShortcutCard`, `DataCard` (swipeable data row — swipe gesture currently commented out, tap-to-copy is the active interaction), `WalletCard` (virtual card visual), `ActivityView` (share sheet), `DocumentPicker` (file importer). |
| `BancaRemota/Views.swift` | 1,906 | All screens: navigation shell (`MainView`, `SideMenuView`), bank browsing (`BankSelectionView`, `OperationsListView`), info/help (`HelpView`, `TutorialView`), settings (`ConfigView`), the four personal-data CRUD sections (Nauta, Bank Accounts, Bills, Keys) and their add/edit forms, plus small shared helpers (`EmptyStateView`, `DetailRow`). |
| `BancaRemota/codes.json` | 209 | Static, bundled dataset: 3 banks × 4 categories each, ~37 operations per bank (112 total), each with a name, description, SF Symbol icon name, USSD dial string, and optional `isLogin` / `isDefaultFavorite` flags. |
| `BancaRemota.xcassets/banks/` | — | Per-bank image assets (`icon`, `logo`, `card`, `background`, `banner`) for `bpa`, `bandec`, `bm`, plus unused/reserved `bc` and `red` asset groups. |

No separate persistence layer, networking layer, or dependency-injection container exists — `Services.swift` *is* the service layer, addressed via `.shared` singletons.

---

## 3. Configuration Data: `codes.json`

`codes.json` is the single source of truth for **what USSD operations exist** and is treated as read-only, bundled data (not user data). It decodes into:

```
BankConfig
 └─ banks: [Bank]
     ├─ id, name, shortName, logoImg, iconImg
     ├─ themeColorHex, textColorHex   → Color(hex:)
     └─ categories: [OperationCategory]
         └─ operations: [BankOperation]
             ├─ id, name, description, iconName, ussdCode
             ├─ isLogin: Bool?             (marks the "authenticate" op used by Home's bank cards)
             └─ isDefaultFavorite: Bool?   (seeds FavoritesManager on first launch)
```

Currently ships 3 banks — BPA (`1E5F52`), BANDEC (`5B2A1F`), BM (`81D717`) — each with 4 categories (Sesión, Consultas, Transferencias, etc.) and ~37 operations.

`DataService.loadConfiguration()` reads and decodes this once, synchronously, on `MainView`'s first appearance (shown as a `ProgressView` until it resolves). There is **no schema versioning and no remote fetch** — updating USSD codes requires shipping a new app build.

**External sync guard**: a GitHub Actions workflow (`.github/workflows/ussd-sync-check.yml`, script `.github/scripts/check-ussd-sync.mjs`) runs weekly and on PRs touching `codes.json`. It diffs this file's *dial-string set* against the canonical `MyUSSDCodes-collection` repo (`cuba-banks.json`) — matching only on USSD codes, not labels/grouping/language — and opens a tracking issue on drift. This is a CI-side consistency check, not a runtime mechanism; the app itself never talks to that repo.

---

## 4. Navigation Model

`MainView` is a hand-rolled, single-screen state machine — there is no `NavigationStack`/`NavigationView` push hierarchy for the main flow. Navigation state is two `@AppStorage`-backed enums/strings:

- `activeScreen: ActiveScreen` — `.home | .bank | .info | .tutorial | .config | .cuentasBanco | .cuentasNauta | .misClaves | .tasaCambio | .cuentasServicios`
- `selectedBankID: String` — which bank is active when `activeScreen == .bank`

Because both are `@AppStorage`, **navigation state survives app relaunch** (the user reopens the app on the same screen they left, subject to the biometric lock re-triggering per §6).

A custom side drawer (`SideMenuView`) is overlaid via a `ZStack` + `isMenuOpen` boolean, with a dimmed backdrop (tap to dismiss) and a `DragGesture` (swipe left to return home). It is not a system component — no `UISplitViewController`, no third-party drawer library.

Per-screen "Add/Edit" and detail flows (`AddNautaAccountView`, `AddBankAccountView`, `AddBillView`, `AddKeyView`, `BankAccountDetailView`, `AddFavoriteOperationView`) are presented as SwiftUI `.sheet`s with their own internal `NavigationView`, independent of the outer state machine — standard modal-form pattern.

---

## 5. USSD Execution Path

This is the app's core function. `CallService.executeUSSD(code:)`:

1. Percent-encodes `#` in the dial string (`addingPercentEncoding` over `CharacterSet(charactersIn: "#").inverted`).
2. Builds a `tel://<code>` URL.
3. Calls `UIApplication.shared.open(url)`, which hands off to the system Phone dialer with the code pre-filled — the user still has to confirm the call manually. The app itself never places a call or parses USSD responses; from iOS's perspective this is indistinguishable from tapping a phone number link.

Entry points that call this: `OperationCard` taps in `OperationsListView` and in the Home "Favoritos" list, plus the bank-card tap on `BankSelectionView` when `useBanksAsLogin` is enabled (dials the bank's `isLogin`-flagged operation directly instead of navigating).

`ConnectionBannerView` (optional, toggled via `showNetworkStatus`) reads `CellularMonitor` to warn the user when cellular signal is absent/weak, since USSD requires voice-network reachability — a real UX affordance given the offline nature of the app, not just decoration.

---

## 6. Authentication & App Lock

`AuthManager` (singleton `ObservableObject`) implements a lightweight "lock screen" gate, entirely local, using `LocalAuthentication` (`LAContext`, policy `.deviceOwnerAuthentication` — Face ID/Touch ID **or passcode fallback**, not biometric-only):

- `authEnabled` (`@AppStorage`) toggles the feature on/off from `ConfigView`; toggling it itself requires a fresh biometric/passcode confirmation (`ConfigView.onChange(of: pendingAuthEnabled)`), so a stolen unlocked phone can't have the lock silently disabled.
- `authExpiration` (minutes, `@AppStorage`, values 0/0.5/1/5/15) — how long the app stays "trusted" after being backgrounded.
- `lastLeaveTime` (`@AppStorage`, epoch seconds) is stamped when `scenePhase` transitions to `.background`.
- On returning to `.active` from background, `checkExpiration()` compares `now - lastLeaveTime` against `authExpiration * 60`; if expired, `isAuthenticated` flips to `false` and `BancaRemotaApp` renders a full-screen lock overlay (`lock.shield` icon + "Desbloquear" button) over `MainView` until `authenticate()` succeeds.

Important nuance: `authEnabled` gates **app-wide unlock**, but it is also reused as a coarser guard elsewhere:
- The "Mis Claves" (PINs/passwords) screen refuses to render its list at all when `authEnabled == false` (independent of whether the *session* is currently authenticated) — i.e., the passwords feature requires the *feature* to be turned on, not just an active session.
- The Backup/iCloud section in `ConfigView` is entirely disabled (grayed out, non-interactive) unless `authEnabled == true`.

This means a user who never enables biometric lock cannot use the Keys manager or backup/iCloud sync at all — a deliberate friction to discourage storing sensitive PINs/passwords without a device lock in place.

---

## 7. Local Persistence

Everything user-generated is `Codable` and stored as JSON blobs in `UserDefaults.standard`, keyed by feature:

| Data | Key | Managed by |
|---|---|---|
| Favorite operations | `favoriteOperations` | `FavoritesManager` |
| Nauta accounts | `nautaAccounts` | `UserDataManager` |
| Bank/card accounts | `bankAccounts` | `UserDataManager` |
| Service bills | `bills` | `UserDataManager` |
| PINs/passwords | `userKeys` | `UserDataManager` |
| ~20 UI/behavior flags | various (`darkModePreference`, `authEnabled`, `useCustomFavoriteColor`, `showNetworkStatus`, etc.) | `@AppStorage` directly in views |

Both managers are `ObservableObject`s whose `@Published` arrays trigger `save()` on every mutation via `didSet` — there is no explicit "Save" action anywhere in the CRUD forms; every add/edit/delete is persisted immediately and synchronously observable by any other view holding the same singleton.

**This is a flat, non-relational, no-migration persistence model.** There is no schema version field on `UserBackup` or on any stored array — a future field rename/type change would need manual backward-compatible `Codable` handling (e.g. custom `init(from:)`), since `JSONDecoder` will currently just fail silently (`try?`) and leave the in-memory array empty/unchanged.

### Backup / Restore
`UserDataManager.createBackup(...)` lets the user opt into which categories to include, encodes a `UserBackup` struct (unencrypted JSON) to a temp file, and hands it to the system share sheet. `importBackup(from:)` does the reverse and **fully overwrites** each included category (no merge). This backup file is explicitly *not* encrypted — export happens over `.foregroundColor(authEnabled ? .appPrimary : .secondary)`-gated UI but the JSON on disk is plaintext, relying entirely on the user's own file handling for confidentiality once exported. Worth flagging if "military-grade encryption" (as advertised in the in-app Help copy) is expected to extend to exported backups — currently it only applies to iCloud sync.

### iCloud Sync (optional, end-to-end encrypted)
When `iCloudSyncEnabled` is on, `UserDataManager.save()` additionally:
1. Derives a symmetric key via `SHA256(password.utf8)` from a user-chosen sync password.
2. Encrypts each category's JSON independently with `AES.GCM.seal` (CryptoKit).
3. Writes the combined ciphertext to `NSUbiquitousKeyValueStore.default` under the same keys as local storage.

The sync password itself is stored in the **Keychain** (`KeychainHelper`, service `"BancaRemota"`, account `"SyncPassword"`) — never in `UserDefaults` or iCloud. Remote changes trigger `NSUbiquitousKeyValueStore.didChangeExternallyNotification`, which calls `loadFromICloud()` to decrypt and overwrite local state on the main thread. There is **no conflict resolution** — last write observed wins per category; two devices editing offline and syncing later can silently clobber each other.

Threat model as implemented: Apple/iCloud stores only ciphertext; only devices with the matching password can decrypt. `SHA256(password)` as a KDF has no salt or iteration count (not PBKDF2/Argon2/scrypt) — adequate against a passive cloud-storage observer, weak against a targeted offline brute-force if the ciphertext is ever exfiltrated. Given `NSUbiquitousKeyValueStore`'s ~1MB total quota, this is fine for its actual payload (a handful of small structs) but is a real weakness relative to the "military-grade encryption" claim in `HelpView` if that's read as a rigorous security guarantee rather than marketing language.

---

## 8. Theming

- **Color scheme**: `darkModePreference` (`@AppStorage`, 0/1/2) maps to `.preferredColorScheme(nil/.light/.dark)` — note the inverted-looking ternary in `BancaRemotaApp` (`darkModePreference == 1 ? .light : (== 2 ? .dark : nil)`) is intentional given the picker's own tag mapping (1 = "Modo Claro", 2 = "Modo Oscuro"), just worth double-checking if this file is ever refactored, since the naming reads backwards at a glance.
- **Accent color**: `Color.appPrimary` (`Models.swift`) is a computed static property, not a fixed asset-catalog color — it reads `useCustomFavoriteColor` and `favoriteCustomColorHex` from `UserDefaults` on every access and defaults to gold (`#B38B4D`). `ConfigView` exposes a `ColorPicker` that writes back through `Color.toHex()`. `MainView`'s root view uses `.id("\(useCustomFavoriteColor)_\(favoriteCustomColorHex)")` to force a full view-identity reset (and thus a redraw with the new color) whenever the accent changes — a pragmatic workaround for `Color.appPrimary` not being a `@Published`/reactive value.
- **Per-bank theming**: each `Bank` carries its own `themeColorHex`/`textColorHex`, applied to that bank's `TopNavBar` and `OperationCard` icon circles — so the chrome recolors per bank while `.appPrimary` (gold) remains constant for all bank-agnostic screens (Home, Settings, Info, Nauta/Bills/Keys lists).
- **Known inconsistency**: `HelpView` uses plain system `.blue` for its three external/action links (LinkedIn, GitHub, "Export codes database") instead of `.appPrimary`, breaking from the gold accent used everywhere else in the app. Low-severity cosmetic drift, not a functional issue.

---

## 9. Cellular/Network Awareness

`CellularMonitor` wraps `CoreTelephony`'s `CTTelephonyNetworkInfo`, observing `CTServiceRadioAccessTechnologyDidChange` to classify the active radio access technology into a coarse `signalQuality` (0–3) and human-readable `networkType` (5G/4G-LTE/3G/2G-EDGE/no service). This does **not** measure signal bar strength (iOS does not expose that publicly) — it only reports which generation of network the modem is currently registered on, used as a proxy for "USSD is likely to work." `ConnectionBannerView` surfaces this as an optional banner under `TopNavBar` when `showNetworkStatus` is enabled.

---

## 10. Recent/Notable Changes (from git history)

- Cellular signal monitor + `ConnectionBannerView` banner is a recent addition (feature commits `88ada12`, `b521f8d`).
- USSD sync-check CI workflow (`096b00f`) formalizes `codes.json` as a downstream mirror of an external canonical source rather than an independently maintained list.

---

## 11. Notable Constraints & Trade-offs (for future contributors)

- **No dependency injection / testability seams**: every service is a `static let shared` singleton accessed directly from views. Unit-testing a view in isolation currently means dealing with real `UserDefaults`/`Keychain`/`CryptoKit` state, not mocks.
- **Silent failure on decode errors**: nearly every `JSONDecoder`/`JSONEncoder` call site uses `try?`, so a corrupted `UserDefaults` blob or a malformed imported backup fails silently (empty result) rather than surfacing an error to the user, except where `importBackup` explicitly returns `false`.
- **No data migrations**: adding/renaming/retyping a field on any `Codable` model (`BankAccount`, `UserKey`, etc.) will silently drop previously stored data for existing users unless a custom decoder is written before shipping the change.
- **`codes.json` is compiled-in**: adding a new bank or operation requires a new app build and App Store review — there is no remote-config or in-app update path for USSD codes.
- **State restoration bypasses normal iOS state restoration**: screen position persists via `@AppStorage`, not `NSUserActivity`/scene restoration — fine for a single-window app, but means "activeScreen" can point at a bank the user no longer has selected in edge cases (e.g., if bank list composition ever became dynamic).

