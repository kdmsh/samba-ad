#!/bin/bash
# 参考サイト Thank you!
# https://zenn.dev/yuyakato/articles/1186de8f2d675d

set -x

. ./config.sh
shopt -s expand_aliases

function enter_to_next () {
  echo "続けるにはEnterキーを押してください..."
  read
}

function service_start () {
  service_name=$@
  # サービスのマスク状態を確認
  systemctl is-enabled $service_name | grep masked > /dev/null 2>&1
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
}

function service_stop () {
  for service_name in $@;do
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
}
# スクリプトを実行するユーザーがrootであることを確認
ID=$(id -u)
if [ "$ID" != 0 ]; then
  echo $ID
  echo "このスクリプトはrootユーザーで実行する必要があります。"
  sudo /bin/bash "$0" "$@"
  exit $?
fi

#######################################
# OSの初期設定
#######################################
# パッケージのアップデート
export DEBIAN_FRONTEND=noninteractive
alias apt-get="apt-get -o 'Acquire::Retries=3' -o 'Acquire::https::Timeout=60' -o 'Acquire::http::Timeout=60' -o 'Acquire::ftp::Timeout=60'"
apt-get update
apt-get -y upgrade
if ! type curl; then
    apt-get -y install curl
fi


# hostname
## affects log, shell-prompt
if [ -n "$fqdn" ]; then
  if [ ! -f /etc/hosts.org ];then
    cp -p /etc/hosts /etc/hosts.org
  fi
  if [ ${fqdn%%.*} == ${fqdn} ]; then
    sed -i -e "s/$(hostname -f)[[:space:]]$(hostname -s)/${fqdn}/" /etc/hosts
  else
    sed -i -e "s/$(hostname -f)[[:space:]]$(hostname -s)/${fqdn} ${fqdn%%.*}/" /etc/hosts
  fi
  echo ${fqdn%%.*} >/etc/hostname
fi
hostnamectl set-hostname ${fqdn%%.*}


# timezone
ln -fs "/usr/share/zoneinfo/$timezone" /etc/localtime
dpkg-reconfigure -f noninteractive tzdata


# lang
if [ $lang != "none" ] && [ $lang != $LANG ]; then
  pkg_mgr_install language-pack-ja language-pack-ja-base && update-locale LANG=$lang
fi


# IPv6
if "${ipv6}"; then
  if [ -f /etc/netplan/01-netcfg.yaml ]; then
    # for Ubuntu 20.04
    mv /etc/sysctl.d/60-disable-ipv6.conf /etc/sysctl.d/60-disable-ipv6.conf.bak
    sed -i -e "s/^#//" /etc/netplan/01-netcfg.yaml
  fi
fi

# avahiのインストール
#apt-get install avahi-daemon avahi-utils
#service_start avahi-daemon

# tailscaleのインストール
if "${tailscale}"; then
  if [ ! -x /usr/bin/tailscale ];then
    curl -fsSL https://tailscale.com/install.sh | sh
    tailscale up
    tailscale up --ssh
  fi
fi

#######################################
# samba-ad-dcの設定
#######################################

#IP=$(/usr/bin/tailscale status | grep `hostname` | cut -d" " -f1)
#IP=$(/usr/bin/tailscale ip |head -1)
#if ! grep $HOST.$REALM /etc/hosts >/dev/null 2>&1 ;then
#	echo "$IP	$HOST.$REALM	$HOST" >> /etc/hosts
#fi

# DNSの設定変更
systemctl disable systemd-resolved.service

enter_to_next

# Sambaをインストール
PGK="acl attr dnsutils krb5-config krb5-user samba samba-dsdb-modules samba-vfs-modules smbclient winbind"
#for P in acl attr dnsutils krb5-config krb5-user samba samba-dsdb-modules samba-vfs-modules smbclient winbind;do
#	apt list --installed $P 2>/dev/null | grep $P >/dev/null 2>&1 || PKG="$PKG $P"
#done

echo "インストール対象のパッケージ"
#echo $PKG
#num_words=$(echo $PKG | wc -w )
#if [ $num_words -gt 1 ]; then
#  echo apt install -y $PKG
#	apt -q update
#  apt install -y $PKG
#fi
apt-get -y install \
  acl \
  attr \
  dnsutils \
  krb5-config \
  krb5-user \
  samba \
  samba-dsdb-modules \
  samba-vfs-modules \
  smbclient winbind

echo "パッケージのインストールが完了しました"
enter_to_next

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

echo "次はsamba-toolの設定です"
enter_to_next

samba-tool domain provision \
  --use-rfc2307 \
  --realm="$REALM" \
  --domain="$domain" \
  --server-role="dc" \
  --dns-backend="SAMBA_INTERNAL" \
  --option="dns forwarder=8.8.8.8" \
  --option="dns forwarder=8.8.4.4" \
  --adminpass="$admin_password"

cp /var/lib/samba/private/krb5.conf /etc/

# 不要なサービスの無効化
#systemctl stop smbd.service nmbd.service winbind.service
service_stop smbd.service nmbd.service winbind.service

# ADサービスの有効化
service_start "samba-ad-dc.service"

# DNSの設定変更 その２
# echo -e "nameserver 127.0.0.1\nsearch ad.nayutaya.jp" | tee /etc/resolv.conf
if grep -E "search.*${fqdn#*.}" /etc/resolv.conf ;then
  echo "nothing"
else
	sed -i "
/search/ {
s/.*/& ${fqdn#*.}/
}
" /etc/resolv.conf

fi

