# 🐟 Salmon Stock Allocation (Flutter Web)

A Flutter Web project for salmon stock allocation/management.

---

## 📚 Table of Contents
- [🧰 Requirements](#-requirements)
- [🧩 Install FVM](#-install-fvm)
  - [macOS / Linux](#macos--linux)
  - [Windows](#windows)
- [⚙️ Project Setup](#️-project-setup)
- [▶️ Run on Web (Local)](#️-run-on-web-local)
- [🏗️ Build (Web)](#️-build-web)
- [🧯 Troubleshooting](#-troubleshooting)

---

## 🧰 Requirements
- Git
- Flutter SDK (installed globally on your machine)
- FVM (Flutter Version Management)

> Tip: Install Flutter first, then use FVM to pin the Flutter version per project.

---

## 🧩 Install FVM

### macOS / Linux

#### Option 1: Install Script (recommended)
```bash
curl -fsSL https://fvm.app/install.sh | bash
```

After installation, ensure FVM is on your `PATH`. Depending on the install method/version, use **one** of the following:

```bash
# Common (newer)
export PATH="$HOME/fvm/bin:$PATH"

# Alternative (older / some environments)
export PATH="$HOME/.fvm/bin:$PATH"
```

Reload your shell (pick the one you use):
```bash
source ~/.zshrc
# or
source ~/.bashrc
```

Verify:
```bash
fvm --version
```

#### Option 2: Homebrew
```bash
brew tap leoafarias/fvm
brew install fvm
fvm --version
```

---

### Windows

#### Chocolatey (recommended)
> Requires Chocolatey installed.

Open PowerShell/Terminal **as Administrator** and run:
```powershell
choco install fvm -y
```

Verify:
```powershell
fvm --version
```

> If `fvm` is not recognized, close and reopen your terminal to refresh PATH.

---

## ⚙️ Project Setup

From the project root:

```bash
fvm install 3.29.3
fvm use 3.29.3
fvm flutter --version
fvm flutter pub get
```

> If your project includes a version config (e.g. `.fvmrc`), you can simply run `fvm install` without specifying a version.

---

## ▶️ Run on Web (Local)

```bash
fvm flutter run -d chrome
```

---

## 🏗️ Build (Web)

```bash
fvm flutter build web --release
```

Output:
```text
build/web
```

---

## 🧯 Troubleshooting
- **`fvm: command not found`**
  - macOS/Linux: confirm you added FVM to `PATH` and reloaded your shell
  - Windows: restart your terminal and confirm Chocolatey installed FVM correctly
- **Chrome device not found / `No devices found`**
  - Install Google Chrome
  - Run `fvm flutter doctor` to check missing dependencies
