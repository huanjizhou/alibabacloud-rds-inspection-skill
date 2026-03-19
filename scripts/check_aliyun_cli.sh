#!/bin/bash
#
# 检查 ALIYUN CLI 安装状态和 AK/SK 配置
# 返回 JSON 格式结果，供主 Agent 解析
#
# 返回状态码：
#   CLI_NOT_INSTALLED  - CLI 未安装
#   AK_NOT_CONFIGURED  - CLI 已安装但未配置凭证
#   READY              - 环境就绪
#

set -euo pipefail

if ! command -v aliyun &> /dev/null; then
    echo '{"status":"CLI_NOT_INSTALLED"}'
    exit 0
fi

VERSION=$(aliyun version 2>/dev/null | head -1 || echo "unknown")

PROFILE_OUTPUT=$(aliyun configure list 2>/dev/null || true)

if [ -z "$PROFILE_OUTPUT" ]; then
    echo "{\"status\":\"AK_NOT_CONFIGURED\",\"version\":\"${VERSION}\"}"
    exit 0
fi

HAS_AK=$(echo "$PROFILE_OUTPUT" | grep -c "AccessKeyId" || true)
if [ "$HAS_AK" -eq 0 ]; then
    echo "{\"status\":\"AK_NOT_CONFIGURED\",\"version\":\"${VERSION}\"}"
    exit 0
fi

REGION=$(aliyun configure get 2>/dev/null | grep -i "region" | awk -F'=' '{print $2}' | tr -d ' ' || echo "unknown")

echo "{\"status\":\"READY\",\"version\":\"${VERSION}\",\"region\":\"${REGION}\"}"
