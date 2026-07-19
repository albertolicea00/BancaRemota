# 🏦 Banca Remota — Cuba - iPhone

**Native iPhone app for Cuban banking via USSD codes. No internet required.**

![Platform](https://img.shields.io/badge/Platform-iOS%2016%2B-blue?logo=apple&logoColor=white)
![Swift](https://img.shields.io/badge/Swift-5.9-orange?logo=swift&logoColor=white)
![Xcode](https://img.shields.io/badge/Xcode-15%2B-blue?logo=xcode&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-green)
![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen)

> Created to revive the original BancaRemota app after it disappeared.
> Special credit to **Henry Cruz**, creator of the original version.

---

## 🏛️ Compatible Banks

| Bank | Full Name |
|------|-----------|
| 🔵 **BPA** | Banco Popular de Ahorro |
| 🟢 **BANDEC** | Banco de Crédito y Comercio |
| 🔴 **BM** | Banco Metropolitano |

---

## ✨ Features

### 📞 Banking Operations
Access any USSD operation organized by category — login, balance, transfers, limits, and more. Tap an operation and the dialer opens with the code ready to call.

### ⭐ Favorites
Pin frequent operations to the home screen. Drag to reorder. Custom color from Settings.

### 💳 Bank Accounts
Store card data: number (masked by default), cardholder name, associated mobile, and custom color. Copy to clipboard in one tap.

### 🌐 Nauta Accounts
Store Nacional and Internacional Nauta usernames, organized by groups.

### 🧾 Service Bills
Store contract numbers for electricity, water, gas, and telephone — copy quickly when making USSD payments.

### 🔑 Keys *(Biometric required)*
Local PIN and password manager by category. Only accessible when Face ID / Touch ID is enabled.

### ⚙️ Settings

- 🌓 Light / Dark / System theme
- 🔐 Face ID / Touch ID with configurable session expiration
- 🏠 Toggle menu shortcuts on home screen
- 🎨 Custom color for favorite cards
- 🔄 Reset favorites to defaults

---

## 🔒 Privacy

- 📵 No internet connection required
- 🚫 No servers, no user accounts, no analytics
- 📱 All data stored locally on-device (UserDefaults)
- 🔐 Keys section locked behind biometric authentication
- 🛡️ Data **never** leaves the device

---

## 🚀 Getting Started

**Requirements:** iOS 16.0+ · Xcode 15.0+

```bash
git clone https://github.com/albertolicea00/BancaRemota_app.git
open BancaRemota.xcodeproj
```

1. Configure your developer account in **Signing & Capabilities**
2. Build and run on a physical device with `Cmd+R`

---

## 🗂️ Project Structure

| File | Description |
|------|-------------|
| `codes.json` | Banks, categories, and USSD codes. Edit to add operations without touching code. |
| `Models.swift` | `Codable` models for `codes.json` and user data (`BankAccount`, `NautaAccount`, `Bill`, `UserKey`). |
| `Services.swift` | Config loading, USSD dialer, favorites management, and data persistence. |
| `Views.swift` | All screens: navigation, lists, edit forms, and info views. |
| `UIComponents.swift` | Reusable components: `TopNavBar`, `OperationCard`, `WalletCard`, `DataCard`, `MenuShortcutCard`, etc. |
| `BancaRemotaApp.swift` | App entry point, authentication management, and theme preferences. |

---

## 🔄 Code source of truth

The USSD operations in [`BancaRemota/codes.json`](BancaRemota/codes.json) mirror the canonical [`cuba-banks`](https://github.com/albertolicea00/MyUSSDCodes-collection/blob/main/codes/cuba-banks.json) collection in **[MyUSSDCodes-collection](https://github.com/albertolicea00/MyUSSDCodes-collection)** — the single source of truth for USSD codes across all my apps.

A weekly GitHub Action ([`ussd-sync-check`](.github/workflows/ussd-sync-check.yml)) compares the dial strings shipped here against that collection. It matches by **dial-string set**, so this app's bank grouping, favorites and Spanish labels stay exactly as they are — only the codes themselves are policed. On drift the run fails and opens a `ussd-sync` issue. **Fix codes upstream in MyUSSDCodes-collection first, then sync this file to match.**

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

> ⚠️ **Issues, PR descriptions, and commit messages must be written in English.**
> The app UI is intentionally in Spanish — it targets Cuban users. All technical communication follows English conventions.

---

*Developed by [Alberto Licea](https://www.linkedin.com/in/albertolicea00) · Inspired by the original app by [Henry Cruz](https://www.linkedin.com/in/henrycruzmederos)*
