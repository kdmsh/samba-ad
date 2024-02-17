#!/bin/sh
# 参考サイト Thank you!
# https://zenn.dev/yuyakato/articles/1186de8f2d675d

. ./config.sh 
# スクリプトを実行するユーザーがrootであることを確認
ID=$(id -u)
if [ "$ID" != 0 ]; then
  echo $ID
  echo "このスクリプトはrootユーザーで実行する必要があります。"
  sudo /bin/bash "$0" "$@"
  exit $?
fi

hostnamectl set-hostname $HOST

# tailscaleのインストール
if [ ! -x /usr/bin/tailscale ];then
	curl -fsSL https://tailscale.com/install.sh | sh
	tailscale up
	tailscale up --ssh
fi

#IP=$(/usr/bin/tailscale status | grep `hostname` | cut -d" " -f1)
IP=$(/usr/bin/tailscale ip |head -1)
if ! grep $HOST.$REALM /etc/hosts >/dev/null 2>&1 ;then
	echo "$IP	$HOST.$REALM	$HOST" >> /etc/hosts
fi

# DNSの設定変更
systemctl disable systemd-resolved.service


# Sambaをインストール
PGK=""
for P in acl attr dnsutils krb5-config krb5-user samba samba-dsdb-modules samba-vfs-modules smbclient winbind;do
	apt -q list --installed | grep $P >/dev/null 2>&1 || PKG="$PKG $P"
done
echo "インストール対象のパッケージ"
echo $PKG
num_words=$(echo $PKG | wc -w )
if [ $num_words -gt 1 ]; then
  echo apt install -y $PKG
	apt -q update
  apt install -y $PKG
fi

# 設定ファイルの退避
if [ ! -f /etc/resolv.conf.org ];then
	mv /etc/resolv.conf /etc/resolv.conf.org
fi

if [ ! -f /etc/samba/smb.conf.org ];then
	mv /etc/samba/smb.conf /etc/samba/smb.conf.org
fi
if [ ! -f /etc/krb5.conf.org ];then
	mv /etc/krb5.conf /etc/krb5.conf.org
fi

samba-tool domain provision \
  --use-rfc2307 \
  --realm="$REALM" \
  --domain="$domain" \
  --server-role="$server_role" \
  --dns-backend="$dns_backend" \
  --option="dns forwarder=8.8.8.8" \
  --option="dns forwarder=8.8.4.4" \
  --adminpass="$admin_password"

cp /var/lib/samba/private/krb5.conf /etc/

# 不要なサービスの無効化
#systemctl stop smbd.service nmbd.service winbind.service
for service_name in smbd.service nmbd.service winbind.service;do
	systemctl status $service_name > /dev/null 2>&1
	# サービスが起動している場合
  if [ $? -eq 0 ]; then
    # サービスを停止
	  echo "サービス[$service_name]を停止しています..."
	  systemctl stop $service_name
		systemctl disable $service_name
	
	  # サービスの停止を確認
	  systemctl status $service_name > /dev/null 2>&1
	
	  # サービスが停止した場合
	  if [ $? -ne 0 ]; then
	    echo "サービス[$service_name]の停止に成功しました。"
	  else
	    echo "サービス[$service_name]の停止に失敗しました。"
	  fi
	else
	  echo "サービス[$service_name]は起動していないため、停止処理はスキップされます。"
	fi
done

# ADサービスの有効化
#systemctl unmask samba-ad-dc.service
# サービス名
service_name="samba-ad-dc.service"

# サービスのマスク状態を確認
systemctl is-masked $service_name > /dev/null 2>&1

# サービスがマスクされている場合
if [ $? -eq 0 ]; then
  # サービスのマスクを解除
  echo "サービス[$service_name]のマスクを解除しています..."
  systemctl unmask $service_name

  # サービスのマスク解除を確認
  systemctl is-masked $service_name > /dev/null 2>&1

  # サービスがマスク解除されている場合
  if [ $? -ne 0 ]; then
    echo "サービス[$service_name]のマスク解除に成功しました。"
  else
    echo "サービス[$service_name]のマスク解除に失敗しました。"
  fi
else
  echo "サービス[$service_name]はマスクされていないため、マスク解除処理はスキップされます。"
fi

# サービスの有効状態を確認
systemctl is-enabled $service_name > /dev/null 2>&1

# サービスが無効化されている場合
if [ $? -ne 0 ]; then
  # サービスを有効化
  echo "サービス[$service_name]を有効化しています..."
  systemctl enable $service_name

  # サービスの有効化を確認
  systemctl is-enabled $service_name > /dev/null 2>&1

  # サービスが有効化されている場合
  if [ $? -eq 0 ]; then
    echo "サービス[$service_name]の有効化に成功しました。"
  else
    echo "サービス[$service_name]の有効化に失敗しました。"
  fi
else
  echo "サービス[$service_name]は既に有効化されているため、有効化処理はスキップされます。"
fi
#systemctl enable samba-ad-dc.service
#systemctl start samba-ad-dc.service
# サービスの起動状態を確認
systemctl is-active $service_name > /dev/null 2>&1

# サービスが停止している場合
if [ $? -ne 0 ]; then
  # サービスを起動
  echo "サービス[$service_name]を起動しています..."
  systemctl start $service_name

  # サービスの起動を確認
  systemctl is-active $service_name > /dev/null 2>&1

  # サービスが起動している場合
  if [ $? -eq 0 ]; then
    echo "サービス[$service_name]の起動に成功しました。"
  else
    echo "サービス[$service_name]の起動に失敗しました。"
  fi
else
  echo "サービス[$service_name]は既に起動しているため、起動処理はスキップされます。"
fi

# DNSの設定変更 その２
# echo -e "nameserver 127.0.0.1\nsearch ad.nayutaya.jp" | tee /etc/resolv.conf
realm=$(echo $REALM |tr '[:upper:]' '[:lower:]')
echo $realm
if grep -E "search.*$realm" /etc/resolv.conf ;then
  echo "nothing"
else
	sed -i "
/search/ {
s/.*/& $realm/
}
" /etc/resolv.conf

fi

