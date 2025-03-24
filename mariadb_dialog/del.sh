#!/usr/bin/env bash

# 預設資料庫連線資訊（可自行修改）
DB_USER=""
DB_PASS=""
DB_HOST="localhost"

# 創建暫存目錄（存放錯誤訊息等）
TEMP_DIR="/tmp/mariadb_manager"
mkdir -p "$TEMP_DIR"

# 結束時清理暫存檔
trap 'rm -rf "$TEMP_DIR"; clear' EXIT

# 簡易函式：測試連線
test_connection() {
    mysql -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" -e "SELECT 1;" 2>"$TEMP_DIR/error.log"
}

# 取得資料庫連線資訊
get_db_credentials() {
    DB_USER=$(dialog --title "MariaDB 管理工具" \
        --inputbox "請輸入資料庫使用者名稱:" 8 40 "$DB_USER" 2>&1 >/dev/tty) || return 1
    
    DB_PASS=$(dialog --title "MariaDB 管理工具" \
        --passwordbox "請輸入資料庫密碼:" 8 40 2>&1 >/dev/tty) || return 1
    
    DB_HOST=$(dialog --title "MariaDB 管理工具" \
        --inputbox "請輸入資料庫主機名稱:" 8 40 "$DB_HOST" 2>&1 >/dev/tty) || return 1
    
    # 測試連接
    if ! test_connection; then
        dialog --title "錯誤" \
               --msgbox "無法連接資料庫:\n$(cat "$TEMP_DIR/error.log")" 10 50
        return 1
    fi
}

# 刪除使用者
delete_user() {
    # 取得所有使用者列表
    users=$(mysql -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" -N -B \
        -e "SELECT CONCAT(User, '@', Host) FROM mysql.user;" 2>"$TEMP_DIR/error.log")
    
    # 若查詢失敗或結果為空，就跳出錯誤訊息
    if [ $? -ne 0 ] || [ -z "$users" ]; then
        dialog --title "錯誤" \
               --msgbox "無法取得使用者列表或列表為空。\n$(cat "$TEMP_DIR/error.log")" 10 50
        return 1
    fi
    
    # 轉成 dialog menu 的格式
    menu_items=()
    i=1
    while IFS= read -r line; do
        menu_items+=($i "$line")  # 選單選項：編號 + 使用者@主機
        ((i++))
    done <<< "$users"
    
    # 互動式選擇想刪除的使用者
    choice=$(dialog --title "刪除使用者" \
                    --menu "請選擇要刪除的使用者:" 20 60 10 \
                    "${menu_items[@]}" 2>&1 >/dev/tty) || return 1
    
    # 擷取使用者@主機
    selected_user=$(echo "$users" | sed -n "${choice}p")
    
    # 確認對話
    dialog --title "確認" --yesno "確定要刪除 '$selected_user' 嗎？" 8 50 || return 1
    
    # 分解出 username 和 hostname
    username=$(echo "$selected_user" | cut -d'@' -f1)
    hostname=$(echo "$selected_user" | cut -d'@' -f2)
    
    # 執行 DROP USER
    mysql -u"$DB_USER" -p"$DB_PASS" -h"$DB_HOST" \
          -e "DROP USER '$username'@'$hostname';" 2>"$TEMP_DIR/error.log"
    
    if [ $? -eq 0 ]; then
        dialog --title "成功" --msgbox "使用者 '$selected_user' 已成功刪除。" 8 50
    else
        dialog --title "錯誤" \
               --msgbox "刪除失敗:\n$(cat "$TEMP_DIR/error.log")" 10 50
    fi
}



###############################################################################
# 一開始就要求輸入連線資訊，若失敗可選擇重試或離開
###############################################################################
while true; do
    if get_db_credentials; then
        # 連線成功就跳出這個循環
        break
    else
        dialog --title "連線失敗" --yesno "是否要重新嘗試輸入連線資訊？\n選擇 No (否) 退出程式。" 8 50
        response=$?
        if [ $response -eq 1 ]; then
            clear
            echo "已退出程式。"
            exit 1
        fi
    fi
done

###############################################################################
# 主選單：不斷循環，直到使用者選 0 或取消
###############################################################################
while true; do
    CHOICE=$(dialog --title "MariaDB 管理工具" \
        --menu "目前使用者: $DB_USER\n主機: $DB_HOST\n\n請選擇操作:" 13 55 4 \
        1 "刪除使用者"   \
        2 "回到主選單" 2>&1 >/dev/tty)
        #0 "退出" 2>&1 >/dev/tty)
    
    case "$CHOICE" in
        1)
            # 確認連線後執行刪除使用者
            if test_connection; then
                delete_user
            else
                dialog --title "提示" --msgbox "目前無法連線，請先變更連線。" 8 40
            fi
            ;;
        # 2)
        #     # 確認連線後執行刪除表格
        #     if test_connection; then
        #         delete_table
        #     else
        #         dialog --title "提示" --msgbox "目前無法連線，請先變更連線。" 8 40
        #     fi
        #     ;;
        2)
            # 變更連線資訊
            # get_db_credentials || dialog --title "提示" \
            #     --msgbox "變更連線失敗，請再試一次或退出。" 8 40
            exit 0
            ;;
        *)
            dialog --title "提示" --msgbox "請選擇有效選項。" 8 40
            ;;
        # 0|"")
        #     clear
        #     echo "感謝使用 MariaDB 管理工具！"
        #     # exit 0
        #     ;;
    esac
done
