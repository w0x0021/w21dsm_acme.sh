#1/usr/bin/env sh

##############################################################
# Copyleft(Ɔ) 2021 by w0x0021.
#
# Filename : w21_acme.sh
# Author   ：w0x0021
# Email    : w0x0021@gmail.com
# Site     : https://www.wangsansan.com
# Date     : 2021-07-19 周一 14:26:43
#    
# Description ：
##############################################################

RUN_PATH=$(cd "$(dirname "$0")";pwd)
CERT_PATH="/etc/pve/nodes/pve"

W21_ACME_DOMAIN_LIST=""

function Init() {
    echo "[+] Initialization check..."

    # 检查 acme.sh 是否已安装
    echo "    [*] Check if acme.sh is installed."
    if [ ! -d "/root/.acme.sh" ]; then
        # 设置申请主体邮箱
        $RUN_PATH/acme.sh/acme.sh --register-account -m $W21_ACME_EMAIL
    else
        echo "    [*] acme.sh is installed."
    fi

    # 备份系统原有的证书以及相关配置文件
    if [ ! -d "$RUN_PATH/backup" ]; then
        echo "    [*] Backup certificate files."

        backup_path="$RUN_PATH/backup/$(hostname)/$(date +'%Y%m%d%H%M%S')"
        mkdir -p $backup_path

        cp $CERT_PATH/pve-ssl.pem $backup_path
        cp $CERT_PATH/pve-ssl.key $backup_path
        if [ -f "$CERT_PATH/pveproxy-ssl.pem" ]; then
            cp $CERT_PATH/pveproxy-ssl.pem $backup_path
        fi
        if [ -f "$CERT_PATH/pveproxy-ssl.key" ]; then
            cp $CERT_PATH/pveproxy-ssl.key $backup_path
        fi
    fi

    echo "[-] Initialization finish."
}

function Submit() {
    # 使用此方式申请同根域名时没有创建两个证书
    #$ACME_SH_BIN --force --issue $W21_ACME_DOMAIN_LIST --dns $W21_ACME_DNS_ISP

    # 循环申请的方式进行申请
    # 可以保证每个域名都能生成新的证书
    let index_max=${#W21_ACME_DOMAIN_ARR[*]}-1
    for index in $(seq 0 $index_max)
    do
        domain=${W21_ACME_DOMAIN_ARR[$index]}
        $RUN_PATH/acme.sh/acme.sh --force --issue --dns $W21_ACME_DNS_ISP -d $domain
    done
}

function CopyFile() {
    echo "[+] Copy certificate."

    domain=${W21_ACME_DOMAIN_ARR[0]}
    cp "/root/.acme.sh/$domain/$domain.key" "$CERT_PATH/pveproxy-ssl.key"
    cp "/root/.acme.sh/$domain/fullchain.cer" "$CERT_PATH/pveproxy-ssl.pem"

    if [ ! -f "/etc/cron.d/w21AutoAcme" ]; then
        echo "58 11 * * * root /root/tools/w21_acme/w21PVE_acme.sh" > /etc/cron.d/w21AutoAcme
        crontab -u root /etc/cron.d/w21AutoAcme
    fi

    echo "[-] Copy certificate finish."
}


# 检查脚本运行权限是否正确
if [ "$USER" != "root" ]; then
    echo "[-] It must be run with root."
    exit
else
    source $RUN_PATH/config     # 初始化配置参数
    export PATH=$PATH:"$RUN_PATH/lib/libidn/src"
fi

case $1 in 
*)
    Init                # Step.1
    Submit              # Step.3
    CopyFile            # Step.4
    ;;
esac
