#!/bin/sh
# スクリプトを実行するユーザーがrootであることを確認
ID=$(id -u)
if [ "$ID" != 0 ]; then
  echo $ID
  echo "このスクリプトはrootユーザーで実行する必要があります。"
  sudo /bin/bash "$0" "$@"
  exit $?
fi

echo -n "ホスト名[dc01]: "
read HOST
if [ "$HOST" = "" ]; then
  HOST="dc01"
fi
hostnamectl set-hostname $HOST

echo -n "ドメイン[ad.kodama-system.com]: "
read DOMAIN
if [ "$DOMAIN" = "" ]; then
  DOMAIN="ad.kodama-system.com"
fi

# tailscaleのインストール
if [ ! -x /usr/bin/tailscale ];then
	curl -fsSL https://tailscale.com/install.sh | sh
	tailscale up
	tailscale up --ssh
fi

IP=$(/usr/bin/tailscale status | grep `hostname` | cut -d" " -f1)
if ! grep $HOST.$DOMAIN /etc/hosts >/dev/null 2>&1 ;then
	echo "$IP	$HOST.$DOMAIN	$HOST" > /etc/hosts
fi

# DNSを停止
systemctl disable systemd-resolved.service

# Sambaをインストール
apt -q update
PGK=""
for P in acl attr dnsutils krb5-config krb5-user samba samba-dsdb-modules samba-vfs-modules smbclient winbind;do
	apt -q list --installed | grep $P >/dev/null 2>&1 || PKG="$PKG $P"
done
echo "インストール対象のパッケージ"
echo $PKG
exit 0
num_words=$(echo $PKG | wc -w )
if [ $num_words -gt 1 ]; then
  echo apt install -y $PKG
  apt install -y $PKG
fi


# Samba設定ファイルを作成
#sudo nano /etc/samba/smb.conf


# 以下の内容をsmb.confファイルに追加

