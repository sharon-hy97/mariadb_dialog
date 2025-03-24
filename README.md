您好，這是一個資料庫圖形化對話窗小工具。
<br>
團隊成員有 Yuma, Sharon, Byron, Kingsley, Sean
<br>

<br>
您可以透過指令下載完整程式碼：

```
git clone https://github.com/sharon-hy97/mariadb_dialog.git
```

進入資料夾後先執行：
<br>
```
chmod +x ins_sql.sh admin.sh cuser.sh del.sh msqlCRUD_2.sh sql.sh
```

這會讓您所有下載內容變成腳本，可以直接運用。
<br>
<br>
假設您沒有mysql資料庫和dialog小工具，請先幫我執行下列程式碼，這會幫您下載好所需資源：
<br>
```
./ins_sql.sh
```

如果您只是沒有dialog，請幫我輸入下列指令：
<br>
```
sudo apt update
sudo apt install dialog
```

如果您只是沒有mysql，請幫我輸入下列指令：
```
sudo apt update
sudo apt install mariadb-server
```

如果您已經都有上述資源了，可以直接輸入下列指令使用所有資源：
```
./sql.sh
```

裡面包含 DB 的 CRUD 操作與新增刪除使用者與管理者。
<br>
<br>
有甚麼問題歡迎在issues上面與我們聯絡。
