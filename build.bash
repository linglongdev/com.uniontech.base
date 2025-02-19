#!/bin/bash
set -e
set -x

ARCH=$1

case $ARCH in
amd64)
    LINGLONG_ARCH="x86_64"
    TRIPLET_LIST="x86_64-linux-gnu"
    ARCH_PACKAGE="gdbserver"
    ;;
arm64)
    LINGLONG_ARCH="arm64"
    TRIPLET_LIST="aarch64-linux-gnu"
    ARCH_PACKAGE="gdbserver"
    ;;
loongarch64)
    LINGLONG_ARCH="loongarch64"
    TRIPLET_LIST="loongarch64-linux-gnu"
    ARCH_PACKAGE="gdbserver"
    ;;
loong64)
    LINGLONG_ARCH="loong64"
    TRIPLET_LIST="loongarch64-linux-gnu"
    ARCH_PACKAGE="liblol"
    ;;
sw64)
    LINGLONG_ARCH="sw64"
    TRIPLET_LIST="sw_64-linux-gnu"
    ARCH_PACKAGE=""
    ;;
"") echo "enter an architecture, like ./build_base.sh amd64" && exit ;;
*) echo "unknow arch \"$ARCH\", supported arch: amd64, arm64, loongarch64, loong64" && exit ;;
esac

export LINGLONG_ARCH

rm -rf output || true

echo "[Content]" >mkosi.local.conf
echo "Packages=$ARCH_PACKAGE" >>mkosi.local.conf

mkosi --force --output=image_binary
echo "Packages=apt,elfutils,file,gcc,g++,gdb,cmake,make,automake,patchelf" >>mkosi.local.conf
mkosi --force --output=image_develop

# 清理仓库中已存在的base
# shellcheck source=/dev/null
source version.bash

# 在项目目录生成linglong.yaml，用于ll-builder push
envsubst <templates/linglong.template.yaml >"linglong.yaml"

for module in binary develop; do
    # mkosi使用subuid，为避免权限问题，先制作tar格式的rootfs，再手动解压
    mkdir -p output/$module/files
    tar -xf output/image_$module -C output/$module/files
    # 生成linglong-triplet-list（记录架构信息）
    echo "$TRIPLET_LIST" >"output/$module/files/etc/linglong-triplet-list"
    # 生成packages.list(记录deb包列表信息)
    cat output/$module/files/var/lib/dpkg/status | grep ^Package: >"output/$module/files/packages.list"
    # 生成info.json(记录玲珑包信息)
    MODULE=$module envsubst <templates/info.template.json >"output/$module/info.json"
    # 生成appid.install(记录玲珑包文件列表)
    bash -c "cd output/$module/files && find | sed 's|^.||'" >"output/$module/$APPID.install"
    # 保存linglong.yaml(记录玲珑包构建信息)
    cp "linglong.yaml" "output/$module/"
done

# ll-builder list | grep "$APPID/$VERSION" | xargs ll-builder remove
# ll-builder import-dir output/binary
# ll-builder import-dir output/develop
