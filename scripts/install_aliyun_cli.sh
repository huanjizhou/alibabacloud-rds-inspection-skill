#!/bin/bash
# install_aliyun_cli.sh - 安装阿里云 CLI (健壮版)
# 支持阿里云 CDN 镜像 + GitHub 双源下载，自动选择最快的源

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

FALLBACK_VERSION="3.3.2"
echo "正在获取最新版本号..."
VERSION=$(curl -sS --connect-timeout 5 --max-time 10 \
    "https://api.github.com/repos/aliyun/aliyun-cli/releases/latest" \
    2>/dev/null | grep '"tag_name"' | sed 's/.*"v\([^"]*\)".*/\1/' || true)

if [ -z "$VERSION" ]; then
    echo -e "${YELLOW}⚠${NC} 无法获取最新版本，使用兜底版本 ${FALLBACK_VERSION}"
    VERSION="$FALLBACK_VERSION"
else
    echo "检测到最新版本: ${VERSION}"
fi

FILENAME="aliyun-cli-${OS_TYPE}-${VERSION}-${ARCH_TYPE}.tgz"

# 多源下载：阿里云 CDN 优先（国内快），GitHub 兜底
URLS=(
    "https://aliyuncli.alicdn.com/${FILENAME}"
    "https://github.com/aliyun/aliyun-cli/releases/download/v${VERSION}/${FILENAME}"
)

# curl 参数：连接超时 15s，最低速度 100KB/s 持续 15s 则放弃，总时间上限 5 分钟
CURL_OPTS="-L --connect-timeout 15 --speed-limit 102400 --speed-time 15 --max-time 300 -o aliyun-cli.tgz"

DOWNLOADED=false
for url in "${URLS[@]}"; do
    echo "正在尝试下载: $url"
    if curl $CURL_OPTS "$url" 2>&1; then
        if [ -s aliyun-cli.tgz ]; then
            DOWNLOADED=true
            echo -e "${GREEN}✓${NC} 下载完成"
            break
        fi
    fi
    echo -e "${YELLOW}⚠${NC} 该源下载失败，尝试下一个..."
    rm -f aliyun-cli.tgz
done

if [ "$DOWNLOADED" = false ]; then
    echo -e "${RED}✗${NC} 所有下载源均失败，请检查网络或手动安装："
    echo "  https://github.com/aliyun/aliyun-cli/releases"
    exit 1
fi

tar xzf aliyun-cli.tgz
sudo mv aliyun /usr/local/bin/
rm -f aliyun-cli.tgz
echo -e "${GREEN}✓${NC} 阿里云 CLI 安装完成"

echo "安装完毕，请运行 aliyun configure 进行鉴权配置"
