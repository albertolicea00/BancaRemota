# Security Policy

## Supported Versions

Banca Remota is a single, continuously updated iOS app distributed from source — there is no versioned API or multiple maintained release lines. Only the latest version on `main` receives security fixes.

| Version         | Supported          |
| --------------- | ------------------ |
| Latest (`main`) | ✅                  |
| Older releases  | ❌                  |

## Scope

Banca Remota has no backend, no servers, and no user accounts — all data (bank accounts, Nauta credentials, service bills, keys) is stored **locally on-device**. The relevant attack surface is local, not network-based. Security issues we care about include:

- Bypassing Face ID / Touch ID protection on the **Keys** section
- Sensitive data (card numbers, passwords, PINs) stored or logged in plaintext outside of secure storage (e.g. `UserDefaults` instead of Keychain, or written to logs/crash reports)
- Sensitive data exposed via clipboard, backups, or other apps (e.g. missing `UIPasteboard` expiration, insecure `NSUserActivity`/Handoff state, unprotected app screenshots in the app switcher)
- Authentication/session logic flaws (e.g. session expiration bypass, biometric fallback issues)
- Memory-safety or crash-inducing input in code that parses `codes.json` or user-provided data

**Out of scope:**
- Issues requiring a jailbroken device or physical access with the device already unlocked.
- Social engineering, phishing, or issues in third-party carrier USSD infrastructure.

## Reporting a Vulnerability

**Do not open a public Issue for security vulnerabilities.**

Please report vulnerabilities privately using [GitHub Security Advisories](https://github.com/albertolicea00/BancaRemota/security/advisories/new) for this repository ("Security" tab → "Report a vulnerability"). This creates a private channel visible only to the maintainer until a fix is ready.

When reporting, please include:
- A description of the issue and its potential impact
- Steps to reproduce (device model, iOS version, app version/commit)
- Any relevant logs, screenshots, or proof-of-concept

This project is maintained solo on a best-effort basis. You can expect an initial response within **7 days**. Confirmed vulnerabilities will be fixed and disclosed via a GitHub Security Advisory once a patch is available; credit is given unless you prefer to stay anonymous.

⚠️ Note: private vulnerability reporting must be enabled in the repository's Security settings for the link above to work. If it's unavailable, open a normal Issue asking for an alternative private contact method — do **not** post vulnerability details in it.
