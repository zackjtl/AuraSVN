# AuraSVN

**繁體中文** · [README.md](README.md)

A Flutter-based desktop application that brings intelligence to SVN repository visualization and analysis.

## Features

### *** Offline SVN History Cache ***
Fetches and caches SVN history locally, enabling instant version lookups. Refresh anytime to sync with the latest changes.

<img width="2028" height="1390" alt="image" src="https://github.com/user-attachments/assets/2169800e-dcbd-4319-8a88-870dda99daef" />

### *** Boundless Branch Map ***
Navigate an infinite, pannable canvas to explore your entire repository topology with smooth zoom and focus controls.

<img width="2028" height="1348" alt="image" src="https://github.com/user-attachments/assets/3605eb25-876d-4321-a203-30ec1b3a4f90" />


### *** LLM-Powered Intelligence ***
Leverage LLM APIs for natural language queries and automatic summary generation directly within the branch viewer. Configure your own API Key and Base URL to connect to your preferred LLM provider.

<img width="2028" height="1385" alt="image" src="https://github.com/user-attachments/assets/458a2a93-beb6-48b9-be44-33b57e530748" />


<img width="2028" height="1390" alt="image" src="https://github.com/user-attachments/assets/f092f87c-c2a0-4409-9127-4bba5155d4be" />

### *** Markdown Branch Notes ***
Automatically generates Markdown notes for each branch, capturing topology and log data. Store notes locally or point to a cloud-synced folder for team collaboration.
<img width="2028" height="1348" alt="image" src="https://github.com/user-attachments/assets/265369c2-b9e9-4579-b6ea-10199286767b" />

## Prerequisites

### Flutter SDK (Desktop)

1. Install Flutter SDK from [flutter.dev](https://flutter.dev)
2. Enable desktop support:
   ```bash
   flutter config --enable-windows   # Windows
   flutter config --enable-macos     # macOS
   flutter config --enable-linux     # Linux
   ```
3. Run `flutter doctor` to verify setup

### Python 3

The backend scripts require Python 3. Download from [python.org](https://www.python.org/downloads/) or install via your system package manager.

Verify Python is available:
```bash
python3 --version   # macOS/Linux
python --version    # Windows
```

### SVN CLI Client

AuraSVN uses the SVN command-line client (`svn`) to interact with repositories.

**Windows:**
- Download [VisualSVN Server](https://www.visualsvn.com/server/) or [Slik SVN](https://sliksvn.com/download/)
- Ensure `svn.exe` is in your PATH

**macOS:**
```bash
brew install subversion
```

**Linux (Ubuntu/Debian):**
```bash
sudo apt install subversion
```

## Installation

```bash
# Clone the repository
git clone https://github.com/zackjtl/AuraSVN.git
cd AuraSVN

# Install Flutter dependencies
flutter pub get
```

## Running

```bash
flutter run
```

On first launch, AuraSVN will attempt to start a local Python backend automatically. If the backend fails to start, you can run it manually:

```bash
python scripts/local_backend.py
```

## Settings Tutorial

### Adding an SVN Profile

1. Open AuraSVN and navigate to **Settings**
2. Click **Add SVN Profile**
3. Enter the SVN repository URL and assign a title and subtitle

<img width="2028" height="816" alt="image" src="https://github.com/user-attachments/assets/987f0ee4-5a60-43be-8ab5-861485d32b5d" />


### Configuring LLM API

1. Open AuraSVN and navigate to **Settings**
2. Click **LLM Settings**
3. Enter your **API Key** and **API Base URL**

<img width="2002" height="1250" alt="image" src="https://github.com/user-attachments/assets/4a91a0cb-b994-4fe4-83c9-ccf8a4c9c637" />


## Project Structure

```
AuraSVN/
├── lib/              # Flutter UI code
├── scripts/          # Python backend scripts
│   ├── local_backend.py       # HTTP server backend
│   ├── svn_to_ai_loader.py    # SVN processing and AI analysis
│   └── test_svn_to_ai_loader.py
├── assets/           # Images and branding
├── windows/          # Windows platform code
├── macos/            # macOS platform code
└── linux/            # Linux platform code
```

## Tech Stack

- Flutter (Desktop)
- Python 3 backend
- SVN CLI integration
- Graph visualization engine
- LLM API support (configurable via UI settings)
