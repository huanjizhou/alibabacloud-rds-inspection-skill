#!/bin/bash
#
# RDS AI 巡检任务执行脚本
# 产品码：rdsai（自动使用最新 API 版本）
#
# 用法：
#   bash run_inspection.sh create                         创建一次性巡检任务（全部实例）
#   bash run_inspection.sh create <InstanceIds>           创建巡检任务（指定实例，逗号分隔）
#   bash run_inspection.sh report <TaskId>                获取巡检报告（整体）
#   bash run_inspection.sh report <TaskId> <InstanceId>   获取巡检报告（指定实例）
#

set -euo pipefail

PRODUCT="rdsai"

# 从 aliyun configure 获取默认 region，也可通过环境变量 ALICLOUD_REGION 覆盖
if [ -n "${ALICLOUD_REGION:-}" ]; then
    REGION="$ALICLOUD_REGION"
else
    REGION=$(aliyun configure get 2>/dev/null | grep -i "region" | awk -F'=' '{print $2}' | tr -d ' ' || echo "")
fi

if [ -z "$REGION" ]; then
    echo '{"Success":false,"Message":"未检测到 Region，请先运行 aliyun configure 或设置环境变量 ALICLOUD_REGION"}'
    exit 1
fi

ACTION="${1:-}"
TMPFILE=$(mktemp)
trap "rm -f $TMPFILE" EXIT

# 执行 aliyun 命令，写入临时文件，去除 ANSI 颜色码后读取
run_aliyun() {
    aliyun "$@" > "$TMPFILE" 2>&1 || true
    # 去除所有 ANSI 转义序列
    sed 's/\x1b\[[0-9;]*[a-zA-Z]//g' "$TMPFILE"
}

case "$ACTION" in
    create)
        INSTANCE_IDS="${2:-all}"
        OUTPUT=$(run_aliyun "$PRODUCT" create-inspection-task \
            --instance-ids "$INSTANCE_IDS" \
            --region "$REGION")
        echo "$OUTPUT"
        if echo "$OUTPUT" | grep -q '"Success"'; then
            exit 0
        else
            exit 1
        fi
        ;;

    report)
        TASK_ID="${2:-}"
        if [ -z "$TASK_ID" ]; then
            echo '{"Success":false,"Message":"缺少参数: TaskId"}'
            exit 1
        fi
        
        INSTANCE_ID="${3:-}"
        
        MAX_RETRIES=15
        for ((i=1; i<=MAX_RETRIES; i++)); do
            if [ -n "$INSTANCE_ID" ]; then
                OUTPUT=$(run_aliyun "$PRODUCT" get-inspection-report \
                    --task-id "$TASK_ID" \
                    --instance-id "$INSTANCE_ID" \
                    --region "$REGION")
            else
                OUTPUT=$(run_aliyun "$PRODUCT" get-inspection-report \
                    --task-id "$TASK_ID" \
                    --region "$REGION")
            fi
            
            # 终态错误：立即返回，不再重试
            if echo "$OUTPUT" | grep -q 'InvalidUserOrder'; then
                echo "$OUTPUT"
                exit 1
            fi
            if echo "$OUTPUT" | grep -q 'TaskNotFound'; then
                echo "$OUTPUT"
                exit 1
            fi
            if echo "$OUTPUT" | grep -q 'PermissionDenied'; then
                echo "$OUTPUT"
                exit 1
            fi
            
            # 成功：返回了有效报告（包含 Data 字段且有 TaskId）
            if echo "$OUTPUT" | grep -q '"Data"'; then
                echo "$OUTPUT"
                exit 0
            fi
            
            # 调试：输出当前拿到的内容长度，帮助排查
            OUTPUT_LEN=${#OUTPUT}
            >&2 echo "⏳ 巡检报告生成中，请稍候……（第 ${i}/${MAX_RETRIES} 次查询，响应长度: ${OUTPUT_LEN}）"
            sleep 20
        done
        
        # 超时：输出最后一次拿到的内容，方便排查
        if [ -n "$OUTPUT" ]; then
            >&2 echo "⚠️ 最后一次响应内容："
            >&2 echo "$OUTPUT"
        fi
        echo '{"Success":false,"Message":"巡检报告生成超时，请稍后重试"}'
        exit 1
        ;;

    *)
        echo "用法: $0 {create|report} [参数]"
        echo ""
        echo "命令："
        echo "  create [InstanceIds]            创建巡检任务（默认 all = 全部实例）"
        echo "  report <TaskId> [InstanceId]    根据 TaskId 获取巡检报告"
        exit 1
        ;;
esac
