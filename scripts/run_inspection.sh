#!/bin/bash
#
# RDS AI 巡检任务执行脚本
# 产品码：RdsAi（自动使用最新 API 版本）
#
# 用法：
#   bash run_inspection.sh create                         创建一次性巡检任务（全部实例）
#   bash run_inspection.sh create <InstanceIds>           创建巡检任务（指定实例，逗号分隔）
#   bash run_inspection.sh report <TaskId>                获取巡检报告（整体）
#   bash run_inspection.sh report <TaskId> <InstanceId>   获取巡检报告（指定实例）
#

set -euo pipefail

PRODUCT="RdsAi"

ACTION="${1:-}"

case "$ACTION" in
    create)
        INSTANCE_IDS="${2:-all}"
        OUTPUT=$(aliyun "$PRODUCT" CreateInspectionTask \
            --InstanceIds "$INSTANCE_IDS" \
            2>&1) || true
        echo "$OUTPUT"
        if echo "$OUTPUT" | grep -q '"Success":true'; then
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
        
        MAX_RETRIES=12
        for ((i=1; i<=MAX_RETRIES; i++)); do
            if [ -n "$INSTANCE_ID" ]; then
                OUTPUT=$(aliyun "$PRODUCT" GetInspectionReport \
                    --TaskId "$TASK_ID" \
                    --InstanceId "$INSTANCE_ID" \
                    2>&1) || true
            else
                OUTPUT=$(aliyun "$PRODUCT" GetInspectionReport \
                    --TaskId "$TASK_ID" \
                    2>&1) || true
            fi
            
            # 终态错误：立即返回，不再重试
            if echo "$OUTPUT" | grep -q '"InvalidUserOrder"'; then
                echo "$OUTPUT"
                exit 1
            fi
            if echo "$OUTPUT" | grep -q '"TaskNotFound"'; then
                echo "$OUTPUT"
                exit 1
            fi
            if echo "$OUTPUT" | grep -q '"PermissionDenied"'; then
                echo "$OUTPUT"
                exit 1
            fi
            
            # 成功：返回了有效报告
            if echo "$OUTPUT" | grep -q '"Data"'; then
                echo "$OUTPUT"
                exit 0
            fi
            
            # 瞬态错误（InternalError / Throttling / 报告未就绪）：静默重试
            >&2 echo "⏳ 巡检报告生成中，请稍候……（第 ${i}/${MAX_RETRIES} 次查询）"
            sleep 10
        done
        
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
