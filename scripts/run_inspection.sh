#!/bin/bash
#
# RDS AI 巡检任务执行脚本
# 产品码：RdsAi | API 版本：2025-05-07
#
# 用法：
#   bash run_inspection.sh create                         创建一次性巡检任务（全部实例）
#   bash run_inspection.sh create <InstanceIds>           创建巡检任务（指定实例，逗号分隔）
#   bash run_inspection.sh report <TaskId>                获取巡检报告（整体）
#   bash run_inspection.sh report <TaskId> <InstanceId>   获取巡检报告（指定实例）
#

set -euo pipefail

API_VERSION="2025-05-07"
PRODUCT="RdsAi"

ACTION="${1:-}"

case "$ACTION" in
    create)
        INSTANCE_IDS="${2:-all}"
        aliyun "$PRODUCT" CreateInspectionTask \
            --InstanceIds "$INSTANCE_IDS" \
            --version "$API_VERSION" 2>&1
        ;;

    report)
        TASK_ID="${2:-}"
        if [ -z "$TASK_ID" ]; then
            echo '{"Success":false,"Message":"缺少参数: TaskId"}'
            exit 1
        fi
        INSTANCE_ID="${3:-}"
        if [ -n "$INSTANCE_ID" ]; then
            aliyun "$PRODUCT" GetInspectionReport \
                --TaskId "$TASK_ID" \
                --InstanceId "$INSTANCE_ID" \
                --version "$API_VERSION" 2>&1
        else
            aliyun "$PRODUCT" GetInspectionReport \
                --TaskId "$TASK_ID" \
                --version "$API_VERSION" 2>&1
        fi
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
