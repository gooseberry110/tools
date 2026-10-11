#!/bin/bash

# 确保脚本以 root 权限运行
if [ "$EUID" -ne 0 ]; then
  echo "❌ 请使用 root 权限或 sudo 运行此脚本。"
  exit 1
fi

# 核心修改：接收命令行第一个参数 ($1)，如果为空则使用默认值 1.8.2
VERSION="${1:-1.8.2}"
ARCH="linux-amd64"
INSTALL_DIR="/opt/exporter"
DOWNLOAD_URL="https://github.com{VERSION}/node_exporter-${VERSION}.${ARCH}.tar.gz"

echo "================================================="
echo "⚙️  准备安装 Node Exporter 版本: v${VERSION}"
echo "================================================="

echo ">>>>>>>>> 1. 创建安装目录 <<<<<<<<<"
mkdir -p ${INSTALL_DIR}
cd ${INSTALL_DIR}

echo ">>>>>>>>> 2. 下载 Node Exporter <<<<<<<<<"
if [ ! -f "node_exporter-${VERSION}.${ARCH}.tar.gz" ]; then
    wget -c ${DOWNLOAD_URL}
    if [ $? -ne 0 ]; then
        echo "❌ 下载失败！请确认 GitHub 上是否存在 v${VERSION} 版本，或检查网络连接。"
        exit 1
    fi
else
    echo "📦 对应的安装包已存在，跳过下载。"
fi

echo ">>>>>>>>> 3. 解压并配置目录 <<<<<<<<<"
tar -zxvf node_exporter-${VERSION}.${ARCH}.tar.gz
# 更新软链接指向新版本
ln -sfn ${INSTALL_DIR}/node_exporter-${VERSION}.${ARCH} ${INSTALL_DIR}/node_exporter_current

echo ">>>>>>>>> 4. 配置 Systemd 服务开机自启 <<<<<<<<<"
cat > /etc/systemd/system/node_exporter.service <<EOF
[Unit]
Description=Prometheus Node Exporter
Documentation=https://github.com
After=network.target

[Service]
Type=simple
User=root
ExecStart=${INSTALL_DIR}/node_exporter_current/node_exporter
Restart=on-failure

[Install]
WantedBy=multi-user.target
EOF

echo ">>>>>>>>> 5. 启动/重启 Node Exporter 服务 <<<<<<<<<"
systemctl daemon-reload
systemctl enable node_exporter
systemctl restart node_exporter  # 使用 restart 方便平滑升级

echo ">>>>>>>>> 6. 检查服务状态 <<<<<<<<<"
if systemctl is-active --quiet node_exporter; then
    echo "================================================="
    echo "🎉 Node Exporter v${VERSION} 部署成功！"
    echo "🌐 访问地址: http://$(hostname -I | awk '{print $1}'):9100/metrics"
    echo "================================================="
else
    echo "❌ 服务启动失败，请运行 'systemctl status node_exporter' 检查日志。"
fi
