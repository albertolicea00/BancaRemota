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

## ⚠️ Disclaimer

> [!WARNING]
> This is an independent, community-made app. It is **not affiliated with, endorsed by, or sponsored by BPA (Banco Popular de Ahorro), BANDEC (Banco de Crédito y Comercio), or BM (Banco Metropolitano)**.  
> USSD codes and services may change at any time at the financial institutions' discretion.

---

## ✨ Features

- 📞 **Banking Operations** — USSD operations organized by category (login, balance, transfers, limits) for BPA, BANDEC, and BM. Tap to open system dialer.
- ⭐ **Favorites** — Pin frequent operations to home screen with drag-to-reorder and custom card colors.
- 💳 **Bank Accounts & Service Bills** — Store card numbers, contract numbers (electricity, water, gas, telephone), and Nauta accounts for fast copy-pasting.
- 🔑 **Secure Keys Vault** — Local PIN and password manager protected behind Face ID / Touch ID biometric authentication.
- 🔔 **Local Reminders** — Schedule configurable notifications for bill payments, card top-ups, and transfers with 1-tap dial action.
- 🎙️ **Siri & Voice Shortcuts** — Execute operations using native voice commands via Apple's `AppIntents` framework.
- 🌗 **Customization & Settings** — Light/Dark mode, accent color picker, biometric session timeout, and home screen shortcut toggles.

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
| `Services.swift` | Config loading, USSD dialer, favorites management, data persistence, reminder scheduling (`ReminderManager`, local notifications), and Siri/Shortcuts integration (`EjecutarOperacionIntent`, `BancaRemotaShortcuts`). |
| `Views.swift` | All screens: navigation, lists, edit forms, and info views. |
| `UIComponents.swift` | Reusable components: `TopNavBar`, `OperationCard`, `WalletCard`, `DataCard`, `MenuShortcutCard`, etc. |
| `BancaRemotaApp.swift` | App entry point, authentication management, and theme preferences. |

For a deeper technical breakdown (data flow, persistence, encryption, navigation model), see [`ARCHITECTURE.md`](ARCHITECTURE.md).

---

## 🚧 Known Limitations

- **iOS security sandbox and USSD limitations (vs. Android / Transfermóvil).** Unlike Android apps (such as Transfermóvil), iOS sandbox security strictness prevents third-party apps from intercepting, reading, or parsing USSD response popups, chaining multi-step USSD sessions automatically, or executing USSD codes silently in the background. Opening a USSD link (`tel://`) hands execution over to the system Phone app, requiring manual user interaction for any follow-up menus or responses.

- **No Home Screen widget.** Considered and deliberately not built. A WidgetKit extension cannot call `UIApplication.shared.open`/`tel://` at all — `APPLICATION_EXTENSION_API_ONLY` makes that API unavailable in any app extension, widgets included, so a widget can never dial a USSD code by itself. The only thing a widget *could* do is open the app via a deep link and let the app dial from there — but that adds a screen transition on top of what unlocking the phone and tapping the app icon already does, with no code actually reaching the dialer any faster. Not worth the extra target, App Group, and maintenance surface for zero real shortcut.

- **Physical dual-SIM (two nano-SIM) devices.** iPhone models sold in mainland China, Hong Kong, and Macao support two physical nano-SIMs, instead of the nano-SIM + eSIM combo sold everywhere else. This app has no line-selection UI and no way to force a dial through one SIM specifically — iOS gives apps no public API to pick which line places a `tel://`/USSD call; it always goes out through whichever line the device's own Phone settings mark as default. Acknowledged, not implemented.

- **No iPad / iPadOS support for USSD.** Even though Cellular iPad models exist (with physical SIM or eSIM slots), Apple completely blocks USSD code execution on iPadOS. iPadOS lacks a full Phone dialer application, which means users cannot dial USSD codes (such as `*944#` or `*966#`), trigger `tel://*944%23` URLs from third-party apps, or receive USSD network responses.

- **No Apple Watch / watchOS support for USSD.** Similarly, Cellular Apple Watch models do not support USSD code execution or third-party USSD dialing via watchOS.

---

## 🤝 Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). Please follow the [Code of Conduct](CODE_OF_CONDUCT.md).

> ⚠️ **Issues, PR descriptions, and commit messages must be written in English.**
> The app UI is intentionally in Spanish — it targets Cuban users. All technical communication follows English conventions.

---

*Developed by @albertolicea00 · Inspired by the original app by [Henry Cruz](https://www.linkedin.com/in/henrycruzmederos)*
