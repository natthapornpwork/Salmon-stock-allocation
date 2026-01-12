# Salmon Stock Allocation (Flutter Web)

## Requirements
- Git
- FVM (Flutter Version Management)

## Install FVM
### macOS / Linux
```bash
curl -fsSL https://fvm.app/install.sh | bash
export PATH="$HOME/.fvm/bin:$PATH"

# Windows
choco install fvm

fvm install 3.29.3
fvm use 3.29.3
fvm flutter --version
fvm flutter pub get

# Run on Web (local)
fvm flutter run -d chrome
