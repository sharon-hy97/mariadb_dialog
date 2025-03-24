#!/bin/bash

#=====================================================
# 共用函式：檢查指令回傳值，若包含 "denied" 等字樣，回到登入
#=====================================================
function check_permission_or_error() {
    local ret_code=$1
    local err_msg_file=$2

    if [[ $ret_code -ne 0 ]]; then
        local ERR=$(cat "$err_msg_file" 2>/dev/null)

        # 判斷是否含有 "denied" 關鍵字 (忽略大小寫)
        if echo "$ERR" | grep -qi "denied"; then
            dialog --msgbox "您沒有權限執行此操作，將返回登入介面！" 8 50
            rm -f "$err_msg_file"
            clear
            user_login   # 再次進行登入
            return 1     # 回傳 1 表示需要中斷當前流程
        else
            dialog --msgbox "執行過程發生錯誤：\n$ERR" 12 60
            rm -f "$err_msg_file"
            return 1
        fi
    fi

    rm -f "$err_msg_file"
    return 0
}

#=============================
# 函式：使用者登入（最多嘗試三次）
#=============================
function user_login() {
    local MAX_TRIES=3
    local TRY_COUNT=0

    while [[ $TRY_COUNT -lt $MAX_TRIES ]]; do
        DB_USER=$(dialog --stdout --inputbox "請輸入資料庫用戶名稱：" 8 40)
        DB_PASS=$(dialog --stdout --passwordbox "請輸入資料庫用戶密碼：" 8 40)

        # 測試連線 (簡單跑個 SQL，看是否正常)
        if mysql -u"$DB_USER" -p"$DB_PASS" -e "EXIT" 2>/dev/null; then
            dialog --msgbox "登入成功！" 6 30
            return 0
        else
            TRY_COUNT=$((TRY_COUNT + 1))
            local REMAINING=$((MAX_TRIES - TRY_COUNT))

            if [[ $REMAINING -gt 0 ]]; then
                dialog --title "錯誤" --msgbox "無法連接，請檢查名稱或密碼。\n剩餘嘗試次數：$REMAINING" 8 50
            else
                dialog --title "錯誤" --msgbox "無法連接，嘗試已達上限 ($MAX_TRIES 次)。" 8 50
                clear
                exit 1
            fi
        fi
    done
}

#=============================
# 函式：建立資料庫
#=============================
function create_database() {
    NEW_DB=$(dialog --inputbox "請輸入要建立的資料庫名稱：" 8 40 2>&1 >/dev/tty)
    if [[ -z "$NEW_DB" ]]; then
        dialog --msgbox "資料庫名稱不得為空！" 8 40
        return
    fi

    mysql -u "$DB_USER" -p"$DB_PASS" -e "CREATE DATABASE \`$NEW_DB\`;" 2>/tmp/error_msg
    local ret=$?
    check_permission_or_error $ret /tmp/error_msg || return
    if [[ $ret -eq 0 ]]; then
        dialog --msgbox "資料庫 '$NEW_DB' 建立成功！" 8 40
    fi
}

#=============================
# 函式：刪除資料庫 (DROP DATABASE)
#=============================
function drop_database() {
    DB_LIST=$(mysql -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" 2>/tmp/error_msg \
        | awk 'NR>1' \
        | grep -Ev '^(information_schema|performance_schema|mysql|sys)$')
    local ret=$?
    check_permission_or_error $ret /tmp/error_msg || return

    if [[ -z "$DB_LIST" ]]; then
        dialog --msgbox "系統沒有可刪除的自訂資料庫。" 8 40
        return
    fi

    DB_OPTIONS=()
    for DB in $DB_LIST; do
        DB_OPTIONS+=("$DB" "$DB")
    done

    local DB_TO_DROP=$(dialog --clear --title "刪除資料庫" \
        --menu "選擇欲刪除的資料庫：" 15 50 10 \
        "${DB_OPTIONS[@]}" 2>&1 >/dev/tty)

    if [[ -z "$DB_TO_DROP" ]]; then
        dialog --msgbox "您沒有選擇任何資料庫。" 8 40
        return
    fi

    dialog --yesno "確定要刪除資料庫 '$DB_TO_DROP'？此動作無法恢復！" 8 50
    if [[ $? -eq 0 ]]; then
        mysql -u "$DB_USER" -p"$DB_PASS" -e "DROP DATABASE \`$DB_TO_DROP\`;" 2>/tmp/error_msg
        local ret2=$?
        check_permission_or_error $ret2 /tmp/error_msg || return
        if [[ $ret2 -eq 0 ]]; then
            dialog --msgbox "✅ 資料庫 '$DB_TO_DROP' 已成功刪除！" 8 40
        fi
    else
        dialog --msgbox "已取消刪除動作。" 8 40
    fi
}

#=============================
# 函式：選擇資料庫
#=============================
function select_database() {
    DB_LIST=$(mysql -u "$DB_USER" -p"$DB_PASS" -e "SHOW DATABASES;" 2>/tmp/error_msg \
        | awk 'NR>1' \
        | grep -Ev '^(information_schema|performance_schema|mysql|sys)$')
    local ret=$?
    check_permission_or_error $ret /tmp/error_msg || return 1

    if [[ -z "$DB_LIST" ]]; then
        dialog --msgbox "目前沒有任何可用的自訂資料庫。" 8 40
        return 1
    fi

    DB_OPTIONS=()
    for DB in $DB_LIST; do
        DB_OPTIONS+=("$DB" "$DB")
    done

    SELECTED_DB=$(dialog --clear --title "選擇 MySQL 資料庫" \
        --menu "請選擇要操作的資料庫：" 15 50 10 \
        "${DB_OPTIONS[@]}" 2>&1 >/dev/tty)

    if [[ -z "$SELECTED_DB" ]]; then
        dialog --msgbox "沒有選擇任何資料庫！" 8 40
        return 1
    fi

    dialog --yesno "是否要繼續使用 '$SELECTED_DB' 資料庫？" 8 50
    if [[ $? -ne 0 ]]; then
        dialog --msgbox "您放棄使用 '$SELECTED_DB'，將返回主選單。" 8 50
        return 1
    fi
    return 0
}

#=============================
# 函式：建立資料表
#=============================
function create_table_in_db() {
    local NEW_TABLE=$(dialog --inputbox "請輸入要建立的資料表名稱：" 8 40 2>&1 >/dev/tty)
    if [[ -z "$NEW_TABLE" ]]; then
        dialog --msgbox "⚠️ 資料表名稱不得為空。" 8 40
        return
    fi

    local COL_COUNT=$(dialog --inputbox "此表要建立幾個欄位？(1~10 建議)" 8 40 2>&1 >/dev/tty)
    if [[ -z "$COL_COUNT" || ! "$COL_COUNT" =~ ^[0-9]+$ ]]; then
        dialog --msgbox "⚠️ 請輸入數字欄位數。" 8 40
        return
    fi

    local COLUMN_DEFS=()
    for (( i=1; i<=$COL_COUNT; i++ )); do
        local COL_NAME=$(dialog --inputbox "第 $i 個欄位名稱：" 8 40 2>&1 >/dev/tty)
        if [[ -z "$COL_NAME" ]]; then
            dialog --msgbox "欄位名稱不可空白，已取消建立。" 8 40
            return
        fi

        local COL_TYPE_CHOICE=$(dialog --clear --title "欄位型態" \
            --menu "請選擇 '$COL_NAME' 欄位型態：" 10 40 3 \
            1 "var (對應 VARCHAR(255))" \
            2 "integer (對應 INT)" \
            3 "text (對應 TEXT)" \
            2>&1 >/dev/tty)

        local COL_TYPE=""
        case "$COL_TYPE_CHOICE" in
            1) COL_TYPE="VARCHAR(255)" ;;
            2) COL_TYPE="INT" ;;
            3) COL_TYPE="TEXT" ;;
            *)
                dialog --msgbox "無效選擇，已取消建立。" 8 40
                return
                ;;
        esac

        COLUMN_DEFS+=(" \`$COL_NAME\` $COL_TYPE")
    done

    local CREATE_STMT
    CREATE_STMT=$(IFS=, ; echo "${COLUMN_DEFS[*]}")

    mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
        -e "CREATE TABLE \`$NEW_TABLE\` ($CREATE_STMT);" 2>/tmp/error_msg
    local ret=$?
    if ! check_permission_or_error $ret /tmp/error_msg; then
        return
    fi

    if [[ $ret -eq 0 ]]; then
        dialog --msgbox "✅ 已成功建立新資料表 '$NEW_TABLE'。" 8 40
    fi
}

#=============================
# 函式：選擇資料表 or 建立新表
#=============================
function table_menu_in_db() {
    while true; do
        TABLE_LIST=$(mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
            -e "SHOW TABLES;" 2>/tmp/error_msg | awk 'NR>1')
        local ret=$?
        if ! check_permission_or_error $ret /tmp/error_msg; then
            return 1
        fi

        if [[ -z "$TABLE_LIST" ]]; then
            local NO_TABLE_CHOICE=$(dialog --clear --title "資料表選單" \
                --menu "'$SELECTED_DB' 尚無任何資料表，您想執行：" 12 50 3 \
                1 "建立新資料表" \
                2 "返回資料庫選擇" \
                2>&1 >/dev/tty)
            case "$NO_TABLE_CHOICE" in
                1) create_table_in_db ;;
                2) return 1 ;;
                *) return 1 ;;
            esac
        else
            TABLE_OPTIONS=()
            for T in $TABLE_LIST; do
                TABLE_OPTIONS+=("$T" "$T")
            done

            local TABLE_CHOICE=$(dialog --clear --title "資料表選單 (DB: $SELECTED_DB)" \
                --menu "請選擇要操作或進行其他功能：" 15 50 10 \
                1 "選擇既有資料表" \
                2 "建立新資料表" \
                3 "返回資料庫選擇" \
                2>&1 >/dev/tty)

            case "$TABLE_CHOICE" in
                1)
                    SELECTED_TABLE=$(dialog --clear --title "選擇資料表" \
                        --menu "請選擇要操作的資料表：" 15 50 10 \
                        "${TABLE_OPTIONS[@]}" 2>&1 >/dev/tty)

                    if [[ -z "$SELECTED_TABLE" ]]; then
                        dialog --msgbox "⚠️ 沒有選擇任何資料表！" 8 40
                    else
                        crud_menu
                    fi
                    ;;
                2)
                    create_table_in_db
                    ;;
                3)
                    return 1
                    ;;
                *) return 1 ;;
            esac
        fi
    done
}

#=============================
# 函式：刪除整個資料表
#=============================
function drop_table() {
    dialog --yesno "確定要刪除資料表 '$SELECTED_TABLE'？此動作無法恢復！" 8 50
    if [[ $? -eq 0 ]]; then
        mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
            -e "DROP TABLE \`$SELECTED_TABLE\`;" 2>/tmp/error_msg
        local ret=$?
        check_permission_or_error $ret /tmp/error_msg || return 1
        if [[ $ret -eq 0 ]]; then
            dialog --msgbox "✅ 資料表 '$SELECTED_TABLE' 已成功刪除！" 8 40
            return 2
        fi
    else
        dialog --msgbox "已取消刪除動作。" 8 40
    fi
    return 0
}

#=============================
# 函式：在資料表中「新增欄位」
#=============================
function add_column_to_table() {
    local COL_NAME=$(dialog --inputbox "請輸入新欄位名稱：" 8 40 2>&1 >/dev/tty)
    if [[ -z "$COL_NAME" ]]; then
        dialog --msgbox "❌ 欄位名稱不得為空。" 8 40
        return
    fi

    local COL_TYPE_CHOICE=$(dialog --clear --title "欄位型態" \
        --menu "請選擇欄位型態：" 10 40 3 \
        1 "var (VARCHAR(255))" \
        2 "integer (INT)" \
        3 "text (TEXT)" \
        2>&1 >/dev/tty)

    local COL_TYPE=""
    case "$COL_TYPE_CHOICE" in
        1) COL_TYPE="VARCHAR(255)" ;;
        2) COL_TYPE="INT" ;;
        3) COL_TYPE="TEXT" ;;
        *)
            dialog --msgbox "無效選擇，已取消操作。" 8 40
            return
            ;;
    esac

    mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
        -e "ALTER TABLE \`$SELECTED_TABLE\` ADD COLUMN \`$COL_NAME\` $COL_TYPE;" 2>/tmp/error_msg

    local ret=$?
    if ! check_permission_or_error $ret /tmp/error_msg; then
        return
    fi

    if [[ $ret -eq 0 ]]; then
        dialog --msgbox "✅ 成功在 '$SELECTED_TABLE' 中新增欄位 '$COL_NAME' ($COL_TYPE)！" 8 60
    fi
}

#=============================
# 函式：插入資料 - 選擇性欄位
#=============================
function insert_selected_columns() {
    local ALL_COLS=$(mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
        -e "DESC \`$SELECTED_TABLE\`;" 2>/tmp/error_msg | awk 'NR>1 {print $1}')
    local ret=$?
    if ! check_permission_or_error $ret /tmp/error_msg; then
        return
    fi

    local COL_CHECKLIST=()
    for col in $ALL_COLS; do
        COL_CHECKLIST+=("$col" "$col" "off")
    done

    local SELECTED_COLS=$(dialog --checklist "請選擇要插入的欄位 (空白鍵勾選)：" 15 60 10 \
        "${COL_CHECKLIST[@]}" 2>&1 >/dev/tty)

    if [[ -z "$SELECTED_COLS" ]]; then
        dialog --msgbox "您沒有選任何欄位。" 8 40
        return
    fi

    local COL_ARRAY=($SELECTED_COLS)  # 轉成陣列
    local COL_LIST=""
    local VAL_LIST=""
    for chosen_col in "${COL_ARRAY[@]}"; do
        # 移除多餘引號
        local CLEAN_COL
        CLEAN_COL=$(echo "$chosen_col" | sed 's/"//g')

        local VALUE=$(dialog --inputbox "[$CLEAN_COL] 欄位值：(可留空)" 8 50 2>&1 >/dev/tty)
        COL_LIST+="\`$CLEAN_COL\`, "
        VAL_LIST+="'$VALUE', "
    done

    COL_LIST=${COL_LIST%, }
    VAL_LIST=${VAL_LIST%, }

    local SQL_STMT="INSERT INTO \`$SELECTED_TABLE\` ($COL_LIST) VALUES ($VAL_LIST);"
    mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" -e "$SQL_STMT" 2>/tmp/error_msg
    local ret2=$?
    if ! check_permission_or_error $ret2 /tmp/error_msg; then
        return
    fi

    if [[ $ret2 -eq 0 ]]; then
        dialog --msgbox "✅ 新增資料成功 (選擇性欄位)！" 8 50
    fi
}

#=============================
# 函式：插入資料 (Insert Row) 子選單
#=============================
function insert_row_into_table() {
    while true; do
        local INSERT_CHOICE=$(dialog --clear --title "插入資料" \
            --menu "請選擇插入方式：" 15 50 5 \
            1 "自訂欄位插入 (Insert Selected Columns)" \
            2 "返回上層" \
            2>&1 >/dev/tty)

        case "$INSERT_CHOICE" in
            1) insert_selected_columns ;;
            2) return 0 ;;
            *) dialog --msgbox "無效選擇，請重新操作！" 8 40 ;;
        esac
    done
}

#=============================
# 函式：查詢資料 (READ)
#=============================
function read_table_data() {
    local COLUMNS=$(mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
        -e "SHOW COLUMNS FROM \`$SELECTED_TABLE\`;" 2>/tmp/error_msg | awk 'NR>1 {print $1}')
    local ret_cols=$?
    if ! check_permission_or_error $ret_cols /tmp/error_msg; then
        return
    fi

    local QUERY_RESULT=$(mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
        -e "SELECT * FROM \`$SELECTED_TABLE\` LIMIT 10;" 2>/tmp/error_msg)
    local ret_data=$?
    if ! check_permission_or_error $ret_data /tmp/error_msg; then
        return
    fi

    IFS=$'\n' read -r -d '' -a lines <<< "$QUERY_RESULT"

    if [[ ${#lines[@]} -le 1 ]]; then
        dialog --msgbox "⚠️ 查無資料或此表沒有任何記錄！" 8 40
        return
    fi

    local out_str="-- 前 10 筆紀錄 --\n"
    for (( i=0; i<${#lines[@]}; i++ )); do
        out_str+="${lines[$i]}\n"
    done

    dialog --msgbox "$out_str" 25 80
}

#=============================
# 函式：CRUD 選單
#=============================
function crud_menu() {
    while true; do
        local ACTION=$(dialog --clear --title "資料庫：$SELECTED_DB / 資料表：$SELECTED_TABLE" \
            --menu "選擇您要進行的操作：" 17 60 7 \
            1 "新增資料或欄位 (CREATE/ADD)" \
            2 "查詢資料 (READ)" \
            3 "更新資料 (UPDATE)" \
            4 "刪除資料 (DELETE)" \
            5 "刪除整個資料表 (DROP TABLE)" \
            6 "返回資料表選單" \
            7 "返回資料庫選單" \
            2>&1 >/dev/tty)

        case "$ACTION" in
            1)
                create_sub_menu
                ;;
            2)
                read_table_data
                ;;
            3)
                local RESULT=$(mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
                    -e "SELECT * FROM \`$SELECTED_TABLE\` LIMIT 10;" 2>/tmp/error_msg)
                local ret4=$?
                if ! check_permission_or_error $ret4 /tmp/error_msg; then
                    return 0
                fi
                dialog --msgbox "最近 10 筆紀錄：\n$RESULT" 20 70

                local WHERE_COL=$(dialog --inputbox "請輸入 [欲篩選的欄位]：" 8 40 2>&1 >/dev/tty)
                local WHERE_VAL=$(dialog --inputbox "請輸入 [該欄位的值]：" 8 40 2>&1 >/dev/tty)
                local UPDATE_COL=$(dialog --inputbox "請輸入 [要修改的欄位]：" 8 40 2>&1 >/dev/tty)
                local UPDATE_VAL=$(dialog --inputbox "請輸入 [新的值]：" 8 40 2>&1 >/dev/tty)

                mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
                    -e "UPDATE \`$SELECTED_TABLE\` SET \`$UPDATE_COL\`='$UPDATE_VAL' WHERE \`$WHERE_COL\`='$WHERE_VAL';" 2>/tmp/error_msg
                local ret5=$?
                if ! check_permission_or_error $ret5 /tmp/error_msg; then
                    return 0
                fi
                if [[ $ret5 -eq 0 ]]; then
                    dialog --msgbox "✅ 更新資料成功！" 8 40
                fi
                ;;
            4)
                local RESULT_DEL=$(mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
                    -e "SELECT * FROM \`$SELECTED_TABLE\` LIMIT 10;" 2>/tmp/error_msg)
                local ret6=$?
                if ! check_permission_or_error $ret6 /tmp/error_msg; then
                    return 0
                fi
                dialog --msgbox "最近 10 筆紀錄：\n$RESULT_DEL" 20 70

                local DELETE_COL=$(dialog --inputbox "請輸入 [要依據的欄位]：" 8 40 2>&1 >/dev/tty)
                local DELETE_VALUE=$(dialog --inputbox "請輸入 [要刪除的值]：" 8 40 2>&1 >/dev/tty)

                mysql -u "$DB_USER" -p"$DB_PASS" -D "$SELECTED_DB" \
                    -e "DELETE FROM \`$SELECTED_TABLE\` WHERE \`$DELETE_COL\`='$DELETE_VALUE';" 2>/tmp/error_msg
                local ret7=$?
                if ! check_permission_or_error $ret7 /tmp/error_msg; then
                    return 0
                fi
                if [[ $ret7 -eq 0 ]]; then
                    dialog --msgbox "✅ 刪除資料成功！" 8 40
                fi
                ;;
            5)
                drop_table
                local ret_drop=$?
                if [[ $ret_drop -eq 2 ]]; then
                    return 0
                fi
                ;;
            6)
                return 0
                ;;
            7)
                return 2
                ;;
            *)
                dialog --msgbox "無效選擇，請重新操作！" 8 40
                ;;
        esac
    done
}

#=============================
# 函式：CREATE / ADD (次選單)
#=============================
function create_sub_menu() {
    while true; do
        local CREATE_ACTION=$(dialog --clear --title "CREATE / ADD 選單" \
            --menu "請選擇要執行的操作：" 15 50 6 \
            1 "新增欄位 (Add Column)" \
            2 "插入資料 (Insert Row)" \
            3 "返回上層選單" \
            2>&1 >/dev/tty)

        case "$CREATE_ACTION" in
            1)  add_column_to_table ;;              # 這裡改成 新增欄位
            2)  insert_row_into_table ;;            # 這裡改成 插入資料
            3)  return 0 ;;
            *)  dialog --msgbox "無效選擇，請重新操作！" 8 40 ;;
        esac
    done
}

#=============================
# 主選單
#=============================
function main_menu() {
    while true; do
        local CHOICE=$(dialog --clear --title "MySQL 管理選單" \
            --menu "請選擇功能：" 15 60 7 \
            1 "建立資料庫" \
            2 "刪除資料庫" \
            3 "查看/選擇資料庫" \
            4 "離開" \
            2>&1 >/dev/tty)

        case "$CHOICE" in
            1) create_database ;;
            2) drop_database ;;
            3)
                select_database
                if [[ $? -eq 0 ]]; then
                    table_menu_in_db
                fi
                ;;
            4)
                dialog --title "系統提示" --msgbox "感謝您的使用" 8 40
                clear
                exit 0
                ;;
            *)
                clear
                exit 0
                ;;
        esac
    done
}

#=============================
# 主程式入口
#=============================
clear
user_login
main_menu
msqlCRUD_2.sh
21 KB