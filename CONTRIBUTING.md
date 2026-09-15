# Contributing to Banca Remota

Thank you for considering contributing! Any improvement is welcome — new banks, USSD code fixes, UI enhancements, or translations.

## Language

**All contributions must be written in English** — issues, PR descriptions, commit messages, code comments, and review discussions.

> The app UI is intentionally in Spanish because it targets Cuban users. However, all technical communication in this repository must be in English to keep the project accessible to a broader audience and maintain consistent standards. Please also pay close attention to spelling and grammar in your contributions.

---

## How to Contribute

### Reporting a Bug

Open an Issue and include:
- A clear, descriptive title.
- Steps to reproduce the bug.
- What you expected vs. what actually happened.
- Screenshots if applicable.
- iOS version and device model.

### Fixing or Adding USSD Codes

If a bank changes its codes or adds new operations:

1. Fork the repository.
2. Create a branch from `main`: `git checkout -b fix/bpa-codes`.
3. Edit `BancaRemota/codes.json` following the existing schema.
4. Open a Pull Request **targeting `main`**.

> [!IMPORTANT]
> `codes.json` is also consumed by the web version of the project. Modifying its schema or structure without coordination can break the web interface.

### Code Contributions

1. Fork the repository.
2. Create a branch from `main`:
   ```bash
   git checkout main
   git checkout -b feature/your-feature-name
   ```
3. Make your changes.
4. Commit with a clear message:
   ```bash
   git commit -m "feat: short description of what it does"
   ```
5. Push and open a Pull Request **targeting `main`**.

---

## Code Style

- Follow the [Swift API Design Guidelines](https://www.swift.org/documentation/api-design-guidelines/).
- Keep the SwiftUI patterns already used in the project.
- UI-facing strings must be in Spanish. Internal code (variable names, comments, commit messages) must be in English.

---

## Questions?

Open an Issue to discuss before starting work on something large.
