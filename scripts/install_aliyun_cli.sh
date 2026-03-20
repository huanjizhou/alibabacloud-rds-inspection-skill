#!/bin/bash
# install_aliyun_cli.sh - 安装阿里云 CLI (健壮版)

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

if command -v aliyun &> /dev/null; then
    echo -e "${GREEN}✓${NC} 阿里云 CLI 已安装"
    exit 0
fi

# 检测操作系统
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$ID
elif [ "$(uname)" = "Darwin" ]; then
    OS="macos"
else
    OS="unknown"
fi

echo "=== 安装阿里云 CLI | Installing Aliyun CLI ==="

# 尝试使用 brew 安装 (如果是 macOS 且有 brew)
if [ "$OS" = "macos" ] && command -v brew &> /dev/null; then
    echo "检测到 Homebrew，尝试使用 brew 安装..."
    if brew install aliyun-cli; then
        echo -e "${GREEN}✓${NC} 阿里云 CLI (Homebrew) 安装完成"
        exit 0
    fi
    echo -e "${YELLOW}⚠${NC} brew 安装失败，尝试官方包下载..."
fi

OS_TYPE=""
if [ "$OS" = "macos" ]; then
    OS_TYPE="macosx"
else
    OS_TYPE="linux"
fi

ARCH=$(uname -m)
ARCH_TYPE=""
if [ "$ARCH" = "x86_64" ] || [ "$ARCH" = "amd64" ]; then
    ARCH_TYPE="amd64"
elif [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
    ARCH_TYPE="arm64"
else
    echo -e "${RED}✗${NC} 不支持的架构: $ARCH"
    exit 1
fi

VERSION="3.3.2"
CLI_URL="https://github.com/aliyun/aliyun-cli/releases/download/v${VERSION}/aliyun-cli-${OS_TYPE}-${VERSION}-${ARCH_TYPE}.tgz"

echo "正在下载: $CLI_URL"
if curl -Lo aliyun-cli.tgz "$CLI_URL"; then
    tar xzf aliyun-cli.tgz
    sudo mv aliyun /usr/local/bin/
    rm -f aliyun-cli.tgz
    echo -e "${GREEN}✓${NC} 阿里云 CLI 安装完成"
else
    echo -e "${RED}✗${NC} 下载失败，请检查网络"
    rm -f aliyun-cli.tgz
    exit 1
fi

echo "安装完毕，请运行 aliyun configure 进行鉴权配置"
