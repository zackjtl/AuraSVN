# AuraSVN

**English** · [README.en.md](README.en.md)

以 Flutter 打造的桌面應用程式，為 SVN 倉庫視覺化與分析帶來智慧化體驗。

## 功能特色

### *** 離線 SVN 歷史快取 ***
在本機擷取並快取 SVN 歷史紀錄，即可即時查詢版本；隨時重新整理以同步最新變更。

<img width="2028" height="1390" alt="image" src="https://github.com/user-attachments/assets/2169800e-dcbd-4319-8a88-870dda99daef" />

### *** 無界分支地圖 ***
在可平移的無限畫布上探索整個倉庫拓撲，支援流暢縮放與聚焦操作。

<img width="2028" height="1348" alt="image" src="https://github.com/user-attachments/assets/3605eb25-876d-4321-a203-30ec1b3a4f90" />


### *** LLM 智慧分析 ***
透過 LLM API 在分支檢視器中進行自然語言查詢與自動摘要產生。可自行設定 API Key 與 Base URL，連接偏好的 LLM 服務。

<img width="2028" height="1385" alt="image" src="https://github.com/user-attachments/assets/458a2a93-beb6-48b9-be44-33b57e530748" />


<img width="2028" height="1390" alt="image" src="https://github.com/user-attachments/assets/f092f87c-c2a0-4409-9127-4bba5155d4be" />

### *** Markdown 分支筆記 ***
自動為各分支產生 Markdown 筆記，記錄拓撲與 log 資料。可儲存於本機，或指向雲端同步資料夾以便團隊協作。
<img width="2028" height="1348" alt="image" src="https://github.com/user-attachments/assets/265369c2-b9e9-4579-b6ea-10199286767b" />

## 環境需求

### Flutter SDK（桌面版）

1. 從 [flutter.dev](https://flutter.dev) 安裝 Flutter SDK
2. 啟用桌面支援：
   ```bash
   flutter config --enable-windows   # Windows
   flutter config --enable-macos     # macOS
   flutter config --enable-linux     # Linux
   ```
3. 執行 `flutter doctor` 確認環境設定

### Python 3

後端腳本需要 Python 3。請從 [python.org](https://www.python.org/downloads/) 下載，或透過系統套件管理員安裝。

確認 Python 可用：
```bash
python3 --version   # macOS/Linux
python --version    # Windows
```

### SVN 命令列用戶端

AuraSVN 使用 SVN 命令列工具（`svn`）與倉庫互動。

**Windows：**
- 下載 [VisualSVN Server](https://www.visualsvn.com/server/) 或 [Slik SVN](https://sliksvn.com/download/)
- 確認 `svn.exe` 已加入 PATH

**macOS：**
```bash
brew install subversion
```

**Linux（Ubuntu/Debian）：**
```bash
sudo apt install subversion
```

## 安裝

```bash
# 複製儲存庫
git clone https://github.com/zackjtl/AuraSVN.git
cd AuraSVN

# 安裝 Flutter 相依套件
flutter pub get
```

## 執行

```bash
flutter run
```

首次啟動時，AuraSVN 會嘗試自動啟動本機 Python 後端。若啟動失敗，可手動執行：

```bash
python scripts/local_backend.py
```

## 設定教學

### 新增 SVN Profile

1. 開啟 AuraSVN，前往 **設定**
2. 點選 **Add SVN Profile**
3. 輸入 SVN 倉庫 URL，並設定標題與副標題

<img width="2028" height="816" alt="image" src="https://github.com/user-attachments/assets/987f0ee4-5a60-43be-8ab5-861485d32b5d" />


### 設定 LLM API

1. 開啟 AuraSVN，前往 **設定**
2. 點選 **LLM Settings**
3. 輸入 **API Key** 與 **API Base URL**

<img width="2002" height="1250" alt="image" src="https://github.com/user-attachments/assets/4a91a0cb-b994-4fe4-83c9-ccf8a4c9c637" />


## 專案結構

```
AuraSVN/
├── lib/              # Flutter UI 程式碼
├── scripts/          # Python 後端腳本
│   ├── local_backend.py       # HTTP 伺服器後端
│   ├── svn_to_ai_loader.py    # SVN 處理與 AI 分析
│   └── test_svn_to_ai_loader.py
├── assets/           # 圖片與品牌素材
├── windows/          # Windows 平台程式碼
├── macos/            # macOS 平台程式碼
└── linux/            # Linux 平台程式碼
```

## 技術堆疊

- Flutter（桌面版）
- Python 3 後端
- SVN CLI 整合
- 圖形視覺化引擎
- LLM API 支援（可於 UI 設定）
