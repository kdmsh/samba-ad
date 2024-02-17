#!/bin/sh
# スクリプトを実行するユーザーがrootであることを確認
ID=$(id -u)
if [ "$ID" != 0 ]; then
  echo $ID
  echo "このスクリプトはrootユーザーで実行する必要があります。"
  sudo /bin/bash "$0" "$@"
  exit $?
fi

# Sambaをインストール
apt update
PGK=""
apt list --installed | grep samba     || PKG="$PKG samba"
apt list --installed | grep krb5-user || PKG="$PKG krb5-user"
apt list --installed | grep realmd    || PKG="$PKG realmd"

num_words=$(echo $PKG | wc -w )
if [ $num_words -gt 1 ]; then
  echo apt install -y $PKG
  apt install -y $PKG
fi


# Samba設定ファイルを作成
#sudo nano /etc/samba/smb.conf


# 以下の内容をsmb.confファイルに追加

