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

ROOT_PATH=$(cd "$(dirname "$0")";pwd)
CONFIG_FILE="$ROOT_PATH/config"
BIND_FILE="$ROOT_PATH/bind.json"
ACME_SH_DIRNAME="acme.sh"
ACME_SH_PATH="$ROOT_PATH/$ACME_SH_DIRNAME"
ACME_SH_BIN="$ACME_SH_PATH/acme.sh"

DSM_CERT_PATH="/usr/syno/etc/certificate/_archive"
DSM_CERT_INFO="$DSM_CERT_PATH/INFO"
ACME_SH_INSTALL_PATH="/root/.acme.sh"

W21_ACME_DOMAIN_LIST=""
export PATH=$PATH:$ACME_SH_PATH:"$ROOT_PATH/lib/libidn/src"

function Init() {
    echo "[+] Initialization check..."

    # 检查 acme.sh 是否已安装
    echo "    [*] Check if acme.sh is installed."
    if [ ! -d $ACME_SH_INSTALL_PATH ]; then
        # 设置申请主体邮箱
        $ACME_SH_BIN --register-account -m $W21_ACME_EMAIL
    else
        echo "    [*] acme.sh is installed."
    fi

    # 备份系统原有的证书以及相关配置文件
    if [ ! -d "$ROOT_PATH/backup" ]; then
        echo "    [*] Backup DSM certificate files."
        mkdir -p "$ROOT_PATH/backup"
        cp -r $DSM_CERT_PATH "$ROOT_PATH/backup/"
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
        $ACME_SH_BIN --force --issue --dns $W21_ACME_DNS_ISP -d $domain
    done
}

function CreateBind() {
    echo "[+] Check domain name binding path."
    # 遍历域名数组
    domain_list=""
    let index_max=${#W21_ACME_DOMAIN_ARR[*]}-1
    for index in $(seq 0 $index_max)
    do
        # 判断是否已存在绑定关系
        domain=${W21_ACME_DOMAIN_ARR[$index]}
        d_is_exists=$(cat $BIND_FILE | jq -r "if .\"${domain}\" then \"have\" else \"null\" end")
        if [ "$d_is_exists" == "have" ]; then
            cert_root=$(cat $BIND_FILE | jq -r ".\"${domain}\".root")
            cert_dir_name=$(cat $BIND_FILE | jq -r ".\"${domain}\".name")
            echo "    [*] Bound: $domain -> $cert_root/$cert_dir_name"
        else
            # 判断文件夹是否已存在
            while [ 1 ]
            do
                # 生成文件夹的名字 并 生成绑定关系
                cert_dir_name=`date +%s%N | md5sum | head -c 6`
                if [ ! -d "$DSM_CERT_PATH/$cert_dir_name" ]; then        # 判断目录是否重名
                    cert_bind_node="{\"$domain\": {\"root\": \"$DSM_CERT_PATH\", \"name\": \"$cert_dir_name\", \"time\": \"$(date +'%Y%m%d%H%M%S')\"}}"
                    new_bind_file=$(echo "$(cat $BIND_FILE) $cert_bind_node" | jq -s add)
                    echo $new_bind_file > $BIND_FILE
                    echo "    [*] New bind: $domain -> $DSM_CERT_PATH/$cert_dir_name"
                    break
                else
                    echo "    [*] Rebind name..."
                    sleep 1
                fi
            done
        fi

        # 生成 acme.sh 域名参数
        domain_list="$domain_list -d ${W21_ACME_DOMAIN_ARR[$index]}"
    done

    export W21_ACME_DOMAIN_LIST=$domain_list
    echo "[-] Bind finish."
}

function CopyFile() {
    echo "[+] Copy certificate."
    let index_max=${#W21_ACME_DOMAIN_ARR[*]}-1
    for index in $(seq 0 $index_max)
    do
        # 拼接路径
        domain=${W21_ACME_DOMAIN_ARR[$index]}
        cert_root=$(cat $BIND_FILE | jq -r ".\"${domain}\".root")
        cert_dir_name=$(cat $BIND_FILE | jq -r ".\"${domain}\".name")
        cert_path="$cert_root/$cert_dir_name"

        if [ ! -d $cert_path ]; then
            mkdir -p $cert_path
        fi

        # 开始拷贝证书文件
        echo "    [*] Copying: $domain "
        cp "$ACME_SH_INSTALL_PATH/$domain/$domain.cer" "$cert_path/cert.pem"
        cp "$ACME_SH_INSTALL_PATH/$domain/$domain.key" "$cert_path/privkey.pem"
        cp "$ACME_SH_INSTALL_PATH/$domain/fullchain.cer" "$cert_path/fullchain.pem"

        # 写到系统配置
        echo "    [*] Set DSM certificate information."
        dsm_cert_node="{\"$cert_dir_name\": {\"desc\": \"\", \"services\": []}}"
        dsm_cert_new_file=$(echo "$(cat $DSM_CERT_INFO) $dsm_cert_node" | jq -s add)
        echo $dsm_cert_new_file > $DSM_CERT_INFO
    done
    echo "[-] Copy certificate finish."
}

function ReloadNginx() {
    echo "[+] Reload nginx."
    /usr/syno/etc/rc.sysv/nginx.sh reload
    echo "[-] Reload nginx finish."
}

# 检查脚本运行权限是否正确
if [ "$USER" != "root" ]; then
    echo "[-] It must be run with root."
    exit
else
    source $CONFIG_FILE     # 初始化配置参数
fi

case $1 in 
*)
    Init                # Step.1
    CreateBind          # Step.2
    Submit              # Step.3
    CopyFile            # Step.4
    ReloadNginx         # Step.5
    ;;
esac
