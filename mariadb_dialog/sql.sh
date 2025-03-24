# dialog --title "訊息盒子" --msgbox "請先登入 MySQL" 10 50
# admin=$(dialog --title "登入" --inputbox "管理員帳號" 10 50 2>&1 >/dev/tty)
# admin_password=$(dialog --title "登入" --passwordbox "請輸入管理員密碼" 10 50 2>&1 >/dev/tty)

while true; do
    choice=$(dialog --title "選單模式" --menu "請選擇要進行甚麼動作" 15 50 4 \
        1 "資料庫操作" \
        2 "新增 user" \
        3 "刪除" \
        4 "離開" 2>&1 >/dev/tty)

    # 檢查是否按下 Cancel
    if [ -z "$choice" ]; then
        clear
        dialog --title "退出" --msgbox "感謝您的使用，再見！" 10 50
        clear
        exit 0
    fi

    case $choice in
        1)
            chmod +x msqlCRUD_2.sh
            ./msqlCRUD_2.sh
            ;;
        2)
            chmod +x cuser.sh
            ./cuser.sh
            ;;
        3)
            chmod +x del.sh
            ./del.sh
            ;;   
        4)
            clear
            dialog --title "退出" --msgbox "感謝您的使用，再見！" 10 50
            clear
            exit 0
            ;;
        *)
            clear
            dialog --title "錯誤" --msgbox "請選擇有效選項。" 10 50
            ;;
    esac

    dialog --yesno "是否繼續操作?" 5 40
    if [ $? -ne 0 ]; then
        clear
        dialog --title "退出" --msgbox "感謝您的使用，再見！" 10 50
        clear
        exit 0
    fi
done

