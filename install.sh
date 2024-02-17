#!/bin/bash
# シェル名が"bash"かどうかをチェック
# プロセスの情報を表示
CMD=$(ps -o command= -p $$)
echo "自プロセス：$CMD"
#if [ "$CMD" =~ "bash" ]; then
if echo "$CMD" | grep "bash"  ; then
  echo "bashです"
else
  echo "このスクリプトはbash以外で実行されています"
  /bin/bash "$0" "$@" 
  exit $?
fi

# スクリプトを実行するユーザーがrootであることを確認
WHO=$(whoami)
echo $WHO
if [[ "$WHO" != "root" ]]; then
  echo "このスクリプトはrootユーザーで実行する必要があります。"
  sudo /bin/bash "$0" "$@"
  exit $?
fi

# Sambaをインストール
apt update
PGK=""
apt list --installed | grep samba      || PKG="$PKG samba"
apt list --installed | grep  krb5-user || PKG="$PKG krb5-user"
apt list --installed | grep realmd     || PKG="$PKG realmd"

num_words=$(wc -w <<< "$PKG")
if [[ $num_words -gt 1 ]]; then
  echo apt install -y $PKG
  apt install -y $PKG
fi


# Samba設定ファイルを作成
#sudo nano /etc/samba/smb.conf

# 以下の内容をsmb.confファイルに追加

