dialog --title "資訊輸入框" --msgbox "歡迎使用maridb視覺化系統" 10 50
sudo_password=`dialog --title "sudo 密碼" --passwordbox "請輸入系統的 sudo 密碼" 10 50 2>&1 >/dev/tty`  #修改
user=`dialog --title "創建管理者" --inputbox "請輸入管理者名稱" 10 50 2>&1 >/dev/tty`
password=`dialog --title "創建管理者" --passwordbox "請輸入管理者密碼" 10 50 2>&1 >/dev/tty`
echo "$sudo_password" | sudo -S mysql -uroot -e "CREATE USER '$user'@'localhost' IDENTIFIED BY '$password'; GRANT ALL PRIVILEGES ON *.* TO '$user'@'localhost' WITH GRANT OPTION; FLUSH PRIVILEGES;"  #前面sudo的部分有修改

if [ $? -eq 0 ]; then
        dialog --title "輸出結果" --msgbox "已新增管理員" 10 50  #修改
else
        dialog --title "輸出結果" --msgbox "管理員新增失敗" 10 50  #修改
fi

echo "接下來將以管理者權限進行動作"
chmod +x sql.sh
./sql.sh