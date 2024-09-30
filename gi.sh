#!/bin/bash

# 設定顏色輸出
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 日誌文件
LOG_FILE="gi_log.txt"

# 配置文件路徑
CONFIG_FILE="$HOME/.gi_config"

# 函數：記錄日誌
log_action() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $1" >> $LOG_FILE
}

# 函數：顯示錯誤訊息
show_error() {
    echo -e "${RED}錯誤：$1${NC}"
    log_action "錯誤：$1"
}

# 函數：顯示成功訊息
show_success() {
    echo -e "${GREEN}成功：$1${NC}"
    log_action "成功：$1"
}

# 函數：顯示資訊訊息
show_info() {
    echo -e "${BLUE}資訊：$1${NC}"
    log_action "資訊：$1"
}

# 函數：檢查並安裝 Git
check_and_install_git() {
    if ! command -v git &> /dev/null; then
        show_info "Git 尚未安裝。正在嘗試安裝 Git..."
        if [[ "$OSTYPE" == "darwin"* ]]; then
            # macOS
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
            brew install git
        elif [[ "$OSTYPE" == "linux-gnu"* ]]; then
            # Linux
            sudo apt-get update
            sudo apt-get install git -y
        else
            show_error "無法自動安裝 Git。請手動安裝後再運行此腳本。"
            exit 1
        fi
        show_success "Git 已成功安裝。"
    fi
}

# 函數：檢查 Git 配置
check_git_config() {
    if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
        show_info "Git 尚未配置用戶名稱和電子郵件。"
        echo -e "${YELLOW}請輸入您的名稱：${NC}"
        read git_name
        echo -e "${YELLOW}請輸入您的電子郵件：${NC}"
        read git_email
        git config --global user.name "$git_name"
        git config --global user.email "$git_email"
        show_success "Git 配置已更新。"
    fi
}

# 函數：初始化 Git 儲存庫
init_git_repo() {
    if [ ! -d .git ]; then
        show_info "初始化 Git 儲存庫..."
        git init
        show_success "Git 儲存庫已初始化。"
    fi
}

# 函數：設定 GitHub 憑證
set_github_credentials() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE"
        echo -e "${BLUE}已從配置文件讀取 GitHub 憑證。${NC}"
        echo -e "${YELLOW}當前 GitHub 用戶名：${NC}${GREEN}$github_username${NC}"
        echo -e "${YELLOW}是否要使用儲存的憑證？(y/n)${NC}"
        read use_saved_credentials
        if [[ $use_saved_credentials == "y" ]]; then
            return
        fi
    fi

    echo -e "${YELLOW}請輸入您的 GitHub 用戶名（不是電子郵件地址）：${NC}"
    read github_username
    echo -e "${YELLOW}請輸入您的 GitHub 個人訪問令牌（Personal Access Token）：${NC}"
    echo -e "${BLUE}如需創建或管理令牌，請訪問：${NC}${YELLOW}https://github.com/settings/tokens${NC}"
    echo -e "${BLUE}確保令牌具有 'repo' 範圍的權限。${NC}"
    read -p "Token: " github_token
    echo

    # 驗證憑證
    response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $github_token" https://api.github.com/user)
    http_status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')

    if [ "$http_status" -eq 200 ]; then
        show_success "GitHub 憑證驗證成功。"
        # 儲存憑證到配置文件
        echo "github_username=\"$github_username\"" > "$CONFIG_FILE"
        echo "github_token=\"$github_token\"" >> "$CONFIG_FILE"
        chmod 600 "$CONFIG_FILE"  # 設置文件權限為只有擁有者可讀寫
        show_success "GitHub 憑證已儲存到配置文件。"
    else
        error_message=$(echo "$body" | grep -o '"message": "[^"]*' | cut -d'"' -f4)
        show_error "GitHub 憑證驗證失敗。錯誤訊息：$error_message"
        show_error "HTTP 狀態碼：$http_status"
        show_error "請檢查您的用戶名和訪問令牌。"
        exit 1
    fi
}

# 函數：創建 GitHub 儲存庫
create_github_repo() {
    echo -e "${YELLOW}請輸入新儲存庫的名稱：${NC}"
    echo -e "${BLUE}注意：建議使用英文、數字、連字符(-)或下劃線(_)，避免使用中文或其他特殊字符${NC}"
    read repo_name
    
    # 移除開頭和結尾的空白字符
    repo_name=$(echo "$repo_name" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
    
    # 將連續的空格或特殊字符替換為單個連字符
    repo_name=$(echo "$repo_name" | tr -s '[:space:]' '-' | tr -s '[:punct:]' '-')
    
    # 移除開頭和結尾的連字符
    repo_name=$(echo "$repo_name" | sed -e 's/^-*//' -e 's/-*$//')
    
    if [ -z "$repo_name" ]; then
        show_error "儲存庫名稱不能為空。請重新輸入。"
        create_github_repo
        return
    fi
    
    echo -e "${YELLOW}處理後的儲存庫名稱：${GREEN}$repo_name${NC}"
    echo -e "${YELLOW}是否接受這個名稱？(y/n)${NC}"
    read accept_name
    
    if [[ $accept_name != "y" ]]; then
        create_github_repo
        return
    fi
    
    echo -e "${YELLOW}請輸入儲存庫描述（可選）：${NC}"
    read repo_description
    echo -e "${YELLOW}是否要將儲存庫設為公開？(y/n)${NC}"
    read is_public
    
    if [[ $is_public == "y" ]]; then
        visibility="public"
    else
        visibility="private"
    fi
    
    show_info "正在創建 GitHub 儲存庫..."
    response=$(curl -s -w "\n%{http_code}" -H "Authorization: token $github_token" \
               -d "{\"name\":\"$repo_name\",\"description\":\"$repo_description\",\"private\":$([[ $visibility == "private" ]] && echo "true" || echo "false")}" \
               https://api.github.com/user/repos)
    
    http_status=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_status" -eq 201 ]; then
        repo_url=$(echo "$body" | grep -o '"clone_url": "[^"]*' | cut -d'"' -f4)
        show_success "GitHub 儲存庫已創建：$repo_url"
        
        # 檢查是否已存在遠端儲存庫
        if git remote | grep -q origin; then
            git remote remove origin
            show_info "已移除舊的遠端儲存庫。"
        fi
        git remote add origin $repo_url
        show_success "已更新遠端儲存庫 URL。"
    else
        error_message=$(echo "$body" | grep -o '"message": "[^"]*' | cut -d'"' -f4)
        show_error "創建 GitHub 儲存庫失敗。錯誤訊息：$error_message"
        show_error "HTTP 狀態碼：$http_status"
        show_error "請檢查您的憑證和網絡連接。"
        exit 1
    fi
}

# 函數：提交變更
commit_changes() {
    git add .
    echo -e "${YELLOW}請輸入提交訊息：${NC}"
    read commit_message
    git commit -m "$commit_message"
}

# 函數：推送到 GitHub
push_to_github() {
    remote_url=$(git remote get-url origin)
    show_info "正在推送到遠端儲存庫 $remote_url ..."
    if git push -u origin $(git rev-parse --abbrev-ref HEAD); then
        show_success "成功推送到遠端儲存庫。"
        return 0
    else
        show_error "推送到遠端儲存庫失敗。請檢查您的網絡連接和 GitHub 憑證。"
        return 1
    fi
}

# 函數：更新 README.md
update_readme() {
    if [ ! -f README.md ]; then
        echo -e "${YELLOW}README.md 不存在。是否要創建新的 README.md 檔案？(y/n)${NC}"
        read create_readme
        if [[ $create_readme == "y" ]]; then
            echo -e "${YELLOW}請選擇 README.md 模板：${NC}"
            echo "1) 基本模板"
            echo "2) 詳細模板"
            echo "3) 自定義"
            read template_choice

            case $template_choice in
                1)
                    echo "# $(basename "$PWD")" > README.md
                    echo -e "\n## 專簡介\n簡短描述您的專案目的和功能。" >> README.md
                    echo -e "\n## 安步驟\n描述如何安裝和設置您的專案" >> README.md
                    echo -e "\n## 使用說明\n提供基本的使用指南。" >> README.md
                    ;;
                2)
                    echo "# $(basename "$PWD")" > README.md
                    echo -e "\n## 專案簡介\n詳細描述您的專案目的、功能和特點。" >> README.md
                    echo -e "\n## 安裝步驟\n1. 克隆儲存庫：\n   \`\`\`\n   git clone $(git config --get remote.origin.url)\n   \`\`\`" >> README.md
                    echo -e "2. 進入專案目錄：\n   \`\`\`\n   cd $(basename "$PWD")\n   \`\`\`" >> README.md
                    echo -e "3. 安裝依賴：\n   \`\`\`\n   npm install\n   \`\`\`" >> README.md
                    echo -e "\n## 使用說明\n詳細描述如何使用您的專案，包括配置步驟和常見用例。" >> README.md
                    echo -e "\n## 貢獻指南\n說明其他開發者如何貢獻到您的專案。" >> README.md
                    echo -e "\n## 授權資訊\n說明您的專案使的授權類型。" >> README.md
                    ;;
                3)
                    echo -e "${YELLOW}請輸入自定義的 README.md 內容（輸入 'EOF' 結束）：${NC}"
                    README_CONTENT=""
                    while IFS= read -r line; do
                        [[ $line == "EOF" ]] && break
                        README_CONTENT+="$line"$'\n'
                    done
                    echo "$README_CONTENT" > README.md
                    ;;
                *)
                    show_error "無的選擇。不創建 README.md。"
                    return
                    ;;
            esac
            
            git add README.md
            git commit -m "新增 README.md"
            git push
            show_success "已創建並推送 README.md 檔案。"
        fi
    else
        echo -e "${YELLOW}README.md 已存在。請選擇操作：${NC}"
        echo "1) 更新變更記錄"
        echo "2) 添加新章節"
        echo "3) 不修改"
        read readme_action

        case $readme_action in
            1)
                echo -e "${YELLOW}請輸入要添加到變更記錄的新條目：${NC}"
                read new_changelog_entry
                if grep -q "## 變更記錄" README.md; then
                    sed -i "" "/## 變更記錄/a\\
- $(date +%Y/%m/%d): $new_changelog_entry" README.md
                else
                    echo -e "\n## 變更記錄\n- $(date +%Y/%m/%d): $new_changelog_entry" >> README.md
                fi
                git add README.md
                git commit -m "更新 README.md：$new_changelog_entry"
                git push
                show_success "已更新並推送 README.md 檔案。"
                ;;
            2)
                echo -e "${YELLOW}請輸入新章節的標題：${NC}"
                read new_section_title
                echo -e "${YELLOW}請輸入新章節的內容（輸入 'EOF' 結束）：${NC}"
                NEW_SECTION_CONTENT=""
                while IFS= read -r line; do
                    [[ $line == "EOF" ]] && break
                    NEW_SECTION_CONTENT+="$line"$'\n'
                done
                echo -e "\n## $new_section_title\n$NEW_SECTION_CONTENT" >> README.md
                git add README.md
                git commit -m "更新 README.md：新增 $new_section_title 章節"
                git push
                show_success "已更新並推送 README.md 檔案。"
                ;;
            3)
                show_info "不修改 README.md。"
                ;;
            *)
                show_error "無效的選擇。不修改 README.md。"
                ;;
        esac
    fi
}

# 函數：更改 GitHub 帳戶
change_github_account() {
    show_info "更改 GitHub 帳戶..."
    set_github_credentials
    git remote remove origin
    create_github_repo
    show_success "GitHub 帳戶已更改。"
}

# 函數：管理 .gitignore
manage_gitignore() {
    if [ ! -f .gitignore ]; then
        touch .gitignore
        show_info "已創建 .gitignore 文件。"
    fi

    while true; do
        echo -e "${YELLOW}管理 .gitignore：${NC}"
        echo "1) 排除文件或目錄"
        echo "2) 查看當前 .gitignore 內容"
        echo "3) 顯示當前目錄內容"
        echo "4) 完成 .gitignore 設置"
        echo -e "${YELLOW}請選擇操作：${NC}"
        read gitignore_choice

        case $gitignore_choice in
            1)
                echo -e "${YELLOW}請輸入要排除的文件或目錄路徑（相對於專案根目錄）：${NC}"
                read exclude_path
                if [ -d "$exclude_path" ]; then
                    echo "$exclude_path/" >> .gitignore
                else
                    echo "$exclude_path" >> .gitignore
                fi
                show_success "已添加 $exclude_path 到 .gitignore。"
                ;;
            2)
                echo -e "${BLUE}當前 .gitignore 內容：${NC}"
                cat .gitignore
                ;;
            3)
                echo -e "${BLUE}當前目錄內容：${NC}"
                ls -la
                ;;
            4)
                show_success ".gitignore 設置完成。"
                return
                ;;
            *)
                show_error "無效的選擇。"
                ;;
        esac
    done
}

# 函數：管理 GitHub 憑證
manage_github_credentials() {
    echo -e "${YELLOW}GitHub 憑證管理：${NC}"
    echo "1) 查看當前憑證"
    echo "2) 更新憑證"
    echo "3) 刪除儲存的憑證"
    echo "4) 返回主選單"
    read -p "請選擇操作：" cred_choice

    case $cred_choice in
        1)
            if [ -f "$CONFIG_FILE" ]; then
                source "$CONFIG_FILE"
                echo -e "${BLUE}當前 GitHub 用戶名：${NC}${GREEN}$github_username${NC}"
                echo -e "${BLUE}當前 GitHub Token：${NC}${GREEN}${github_token:0:4}...${github_token: -4}${NC}"
            else
                show_error "尚未設置 GitHub 憑證。"
            fi
            ;;
        2)
            set_github_credentials
            ;;
        3)
            if [ -f "$CONFIG_FILE" ]; then
                rm "$CONFIG_FILE"
                show_success "已刪除儲存的 GitHub 憑證。"
            else
                show_info "沒有儲存的 GitHub 憑證。"
            fi
            ;;
        4)
            return
            ;;
        *)
            show_error "無效的選擇。"
            ;;
    esac
}

# 函數：分支管理
manage_branches() {
    echo -e "${YELLOW}分支管理：${NC}"
    echo "1) 查看所有分支"
    echo "2) 創新分支"
    echo "3) 切換分支"
    echo "4) 合併分支"
    echo "5) 刪除分支"
    echo "6) 返回主選單"
    read -p "請選擇操作：" branch_choice

    case $branch_choice in
        1)
            git branch -a
            ;;
        2)
            echo -e "${YELLOW}請輸入新分支名稱：${NC}"
            read new_branch_name
            git branch $new_branch_name
            show_success "已創建新分支：$new_branch_name"
            ;;
        3)
            echo -e "${YELLOW}請輸入要切換的分支名稱：${NC}"
            read switch_branch_name
            git checkout $switch_branch_name
            show_success "已切換到分支：$switch_branch_name"
            ;;
        4)
            echo -e "${YELLOW}請輸入要合併的分支名稱：${NC}"
            read merge_branch_name
            git merge $merge_branch_name
            show_success "已合併分支：$merge_branch_name"
            ;;
        5)
            echo -e "${YELLOW}請輸入要刪除的分支名稱：${NC}"
            read delete_branch_name
            git branch -d $delete_branch_name
            show_success "已刪除分支：$delete_branch_name"
            ;;
        6)
            return
            ;;
        *)
            show_error "無效的選擇。"
            ;;
    esac
}

# 函數：簡單的檔案瀏覽器
file_browser() {
    echo -e "${YELLOW}檔案瀏覽器：${NC}"
    echo "當前目錄："
    pwd
    echo "檔案列表："
    ls -la
    echo -e "${YELLOW}請選擇操作：${NC}"
    echo "1) 進入子目錄"
    echo "2) 返回上一級目錄"
    echo "3) 編輯檔案"
    echo "4) 返回主選單"
    read -p "請選擇操作：" file_choice

    case $file_choice in
        1)
            echo -e "${YELLOW}請輸入要進入的目錄名：${NC}"
            read dir_name
            cd $dir_name
            file_browser
            ;;
        2)
            cd ..
            file_browser
            ;;
        3)
            echo -e "${YELLOW}請輸入要編輯的檔案名：${NC}"
            read file_name
            if [ -f $file_name ]; then
                ${EDITOR:-nano} $file_name
            else
                show_error "檔案不存在。"
            fi
            file_browser
            ;;
        4)
            return
            ;;
        *)
            show_error "無效的選擇。"
            file_browser
            ;;
    esac
}

# 函數：簡化的主選單
show_menu() {
    echo -e "${YELLOW}請選擇要執行的操作：${NC}"
    echo "1) 初次設置專案並上傳到 GitHub"
    echo "2) 更新專案並上傳變更"
    echo "3) 管理 GitHub 帳戶"
    echo "4) 退出"
    echo -e "${YELLOW}請輸入選項號碼：${NC}"
    read choice
}

# 函數：檢查並修復遠端儲存庫
check_and_fix_remote() {
    if git remote | grep -q origin; then
        remote_url=$(git remote get-url origin)
        if [[ $remote_url == *"---"* ]]; then
            show_error "檢測到無效的遠端儲存庫 URL：$remote_url"
            echo -e "${YELLOW}是否要重新設置遠端儲存庫？(y/n)${NC}"
            read reset_remote
            if [[ $reset_remote == "y" ]]; then
                git remote remove origin
                create_github_repo
            else
                show_error "無法繼續，遠端儲存庫 URL 無效。"
                exit 1
            fi
        else
            show_info "當前遠端儲存庫 URL：$remote_url"
        fi
    else
        show_info "未檢測到遠端儲存庫，將創建新的儲存庫。"
        create_github_repo
    fi
}

# 函數：初次設置專案
initial_setup() {
    check_and_install_git
    check_git_config
    init_git_repo
    set_github_credentials
    check_and_fix_remote
    manage_gitignore
    commit_changes
    
    show_info "正在嘗試推送到遠端儲存庫..."
    if ! push_to_github; then
        show_error "推送到遠端儲存庫失敗。請檢查您的網絡連接和 GitHub 憑證。"
        echo -e "${YELLOW}您可以稍後使用「更新專案並上傳變更」選項再次嘗試上傳。${NC}"
        return 1
    fi
    
    update_readme
    show_success "專案已成功設置並上傳到 GitHub！"
}

# 函數：更新專案
update_project() {
    if ! git remote | grep -q origin; then
        show_error "尚未設定遠端儲存庫。請先執行初次設置。"
        return 1
    fi
    
    check_and_fix_remote
    
    show_info "正在檢查專案變更..."
    git status
    
    echo -e "${YELLOW}是否要提交並上傳這些變更？(y/n)${NC}"
    read confirm
    if [[ $confirm == "y" ]]; then
        commit_changes
        if push_to_github; then
            update_readme
            show_success "專案更新已完成並上傳到 GitHub！"
        else
            show_error "推送到 GitHub 失敗。專案更新未完成。"
            return 1
        fi
    else
        show_info "取消更新操作。"
    fi
}

# 主程序
echo -e "${GREEN}歡迎使用簡易 GitHub 專案管理工具！${NC}"

# 嘗試讀取配置文件
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
    show_info "已讀取儲存的 GitHub 帳戶資訊。"
else
    show_info "未找到儲存的 GitHub 帳戶資訊。首次使用時需要設置。"
fi

while true; do
    show_menu

    case $choice in
        1)
            if ! initial_setup; then
                echo -e "${YELLOW}初次設置未完全成功。您可以：${NC}"
                echo "1) 重試初次設置"
                echo "2) 嘗試更新專案並上傳變更"
                echo "3) 返回主選單"
                read -p "請選擇操作：" retry_choice
                case $retry_choice in
                    1) continue ;;
                    2) update_project ;;
                    3) continue ;;
                    *) show_error "無效的選擇。返回主選單。" ;;
                esac
            fi
            ;;
        2)
            update_project
            ;;
        3)
            manage_github_credentials
            ;;
        4)
            show_info "感謝使用，再見！"
            exit 0
            ;;
        *)
            show_error "無效的選項，請重新選擇。"
            ;;
    esac
done