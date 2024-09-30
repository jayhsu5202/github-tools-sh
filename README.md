# 簡易 GitHub 專案管理工具

## 專案簡介

這是一個簡單易用的命令列工具，旨在簡化 GitHub 專案的管理流程。它提供了一系列功能，包括初始化 Git 儲存庫、設置 GitHub 憑證、創建和管理遠端儲存庫、提交和推送變更，以及管理 README.md 和 .gitignore 檔案等。

## 安裝步驟

1. 確保您的系統已安裝 Git。如果尚未安裝，腳本會嘗試自動安裝。

2. 下載 `gi.sh` 腳本到您的本地機器。

3. 給予腳本執行權限：
   ```
   chmod +x gi.sh
   ```

4. 將腳本放置在方便存取的位置，或考慮將其路徑添加到系統的 PATH 中。

## 使用說明

1. 在終端機中執行腳本：
   ```
   ./gi.sh
   ```

2. 依照提示選擇所需的操作：
   - 初次設置專案並上傳到 GitHub
   - 更新專案並上傳變更
   - 管理 GitHub 帳戶
   - 退出

3. 根據選擇的操作，按照腳本的指示進行操作。

## 主要功能

- 自動檢查並安裝 Git
- 設置 Git 全局配置
- 初始化 Git 儲存庫
- 管理 GitHub 憑證
- 創建和管理 GitHub 遠端儲存庫
- 提交和推送變更
- 管理 README.md 檔案
- 管理 .gitignore 檔案
- 分支管理
- 簡易檔案瀏覽器

## 注意事項

- 首次使用時，您需要提供 GitHub 用戶名和個人訪問令牌（Personal Access Token）。
- 請確保您的 GitHub 個人訪問令牌具有足夠的權限來執行所需的操作。
- 腳本會將 GitHub 憑證儲存在本地配置檔案中（`$HOME/.gi_config`），請妥善保管。

## 變更記錄

- 2024/10/01: 初始版本發布

## 貢獻指南

歡迎提交問題報告、功能請求或直接提交程式碼來改進這個工具。請遵循以下步驟：

1. Fork 本專案
2. 創建您的特性分支 (`git checkout -b feature/AmazingFeature`)
3. 提交您的變更 (`git commit -m '添加一些特性'`)
4. 推送到分支 (`git push origin feature/AmazingFeature`)
5. 開啟一個 Pull Request
