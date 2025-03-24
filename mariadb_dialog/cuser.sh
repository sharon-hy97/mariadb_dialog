#!/usr/bin/env bash

dialog --title "訊息盒子" --msgbox "請先登入 MySQL" 10 50
admin=$(dialog --title "登入" --inputbox "管理員帳號" 10 50 2>&1 >/dev/tty)
if [ $? -ne 0 ]; then
    clear
    echo "取消輸入管理員帳號，結束。"
    exit 0
fi

admin_password=$(dialog --title "登入" --passwordbox "請輸入管理員密碼" 10 50 2>&1 >/dev/tty)
if [ $? -ne 0 ]; then
    clear
    echo "取消輸入管理員密碼，結束。"
    exit 0
fi

while true  # ←主要迴圈
do
    # 1. 輸入 USER 名
    user=$(dialog --title "請用英文輸入USER名字" \
                  --inputbox "USER的名字:" 10 50 \
                  2>&1 >/dev/tty)
    # 若使用者按下 Esc/Cancel
    if [ $? -ne 0 ]; then
        continue  # 回到 while 起始，重新輸入
    fi

    # 2. 輸入 USER 密碼
    password=$(dialog --title "請輸入USER的密碼" \
                      --passwordbox "USER的密碼:" 10 50 \
                      2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        continue
    fi

    # 3. 選擇權限 (checklist)
    permission=$(dialog --title "表單模式" \
                        --checklist "請選擇要開啟的權限(空白鍵為選擇與取消)" 13 50 5 \
                            1 "ALL PRIVILEGES" on \
                            2 "SELECT"         off \
                            3 "INSERT"         off \
                            4 "UPDATE"         off \
                            5 "DELETE"         off \
                        2>&1 >/dev/tty)
    if [ $? -ne 0 ]; then
        continue
    fi

    # 4. 整理權限
    perm_str=""
    for p in $permission; do
        case $p in
            1)
                perm_str="ALL PRIVILEGES"
                break
                ;;
            2) perm_str="$perm_str, SELECT" ;;
            3) perm_str="$perm_str, INSERT" ;;
            4) perm_str="$perm_str, UPDATE" ;;
            5) perm_str="$perm_str, DELETE" ;;
        esac
    done
    perm_str=$(echo "$perm_str" | sed 's/^, //')

    # 5. 以 menu 顯示確認資訊
    dialog --title "選單模式" \
           --menu "請確認以下資訊" 10 50 2 \
               1 "使用者名稱: $user" \
               2 "使用者權限:$perm_str"
    if [ $? -ne 0 ]; then
        continue
    fi

    # 6. 呼叫 MySQL 建立使用者
    mysql -u"$admin" -p"$admin_password" \
          -e "CREATE USER IF NOT EXISTS '$user'@'localhost' IDENTIFIED BY '$password';
              GRANT $perm_str ON mydb.* TO '$user'@'localhost';"

    if [ $? -eq 0 ]; then
        dialog --title "結果" --msgbox "已成功新增使用者 $user" 10 50
    else
        dialog --title "錯誤" --msgbox "使用者 $user 新增失敗，請檢查帳號密碼或資料庫設定" 10 50
    fi

    # 7. 是否繼續新增使用者？
    dialog --yesno "是否繼續新增使用者" 5 40
    if [ $? -eq 0 ]; then
        # Yes => 繼續下一輪 while
        echo "確定，繼續新增使用者"
    else
        # No / Cancel => 跳回 sql.sh，然後結束
        echo "取消，回到主選單"
        ./sql.sh
        clear
        exit 0
    fi
done
