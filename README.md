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

### 🔔 Reminders
Local notifications (no server, no push) for payments/top-ups you need to make. Quick templates for Luz, Agua, Gas, Teléfono, Nauta, and Transferencia — each can be created any number of times (e.g. one per house or per Nauta account) and linked to a saved bill/account so the notification shows the real data and an "Ejecutar" button copies it and dials. Fully custom reminders also supported. Recurrence: once, daily, weekly, monthly, or every N days. All start off — nothing fires until you create one.

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

> **Note:** `BancaRemota` manages its Xcode project natively via `BancaRemota.xcodeproj` without using XcodeGen or external project generators.

1. Configure your developer account in **Signing & Capabilities**
2. Build and run on a physical device with `Cmd+R`

---

## 🗂️ Project Structure

| File | Description |
|------|-------------|
| `codes.json` | Banks, categories, and USSD codes. Edit to add operations without touching code. |
| `Models.swift` | `Codable` models for `codes.json` and user data (`BankAccount`, `NautaAccount`, `Bill`, `UserKey`, `Reminder`, `ReminderTemplate`). |
| `Services.swift` | Config loading, USSD dialer, favorites management, data persistence, and reminder scheduling (`ReminderManager`, local notifications). |
| `Views.swift` | All screens: navigation, lists, edit forms, and info views. |
| `UIComponents.swift` | Reusable components: `TopNavBar`, `OperationCard`, `WalletCard`, `DataCard`, `MenuShortcutCard`, etc. |
| `BancaRemotaApp.swift` | App entry point, authentication management, and theme preferences. |

For a deeper technical breakdown (data flow, persistence, encryption, navigation model), see [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## 🚧 Known Limitations

- **Physical dual-SIM (two nano-SIM) devices.** iPhone models sold in mainland China, Hong Kong, and Macao support two physical nano-SIMs, instead of the nano-SIM + eSIM combo sold everywhere else. This app has no line-selection UI and no way to force a dial through one SIM specifically — iOS gives apps no public API to pick which line places a `tel://`/USSD call; it always goes out through whichever line the device's own Phone settings mark as default. Acknowledged, not implemented.

- **No iPad / iPadOS support for USSD.** Even though Cellular iPad models exist (with physical SIM or eSIM slots), Apple completely blocks USSD code execution on iPadOS. iPadOS lacks a full Phone dialer application, which means users cannot dial USSD codes (such as `*944#` or `*966#`), trigger `tel://*944%23` URLs from third-party apps, or receive USSD network responses.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

> ⚠️ **Issues, PR descriptions, and commit messages must be written in English.**
> The app UI is intentionally in Spanish — it targets Cuban users. All technical communication follows English conventions.

---

*Developed by [Alberto Licea](https://www.linkedin.com/in/albertolicea00) · Inspired by the original app by [Henry Cruz](https://www.linkedin.com/in/henrycruzmederos)*
