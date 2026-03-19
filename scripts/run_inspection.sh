#!/bin/bash
#
# RDS 巡检任务执行脚本
#
# 用法：
#   bash run_inspection.sh create              创建巡检任务
#   bash run_inspection.sh report <TaskId>     获取巡检报告
#

set -euo pipefail

ACTION="${1:-}"

case "$ACTION" in
    create)
        aliyun das CreateInspectionTask --InstanceIds "all" 2>&1
        ;;

    report)
        TASK_ID="${2:-}"
        if [ -z "$TASK_ID" ]; then
            echo '{"Success":false,"Message":"缺少参数: TaskId"}'
            exit 1
        fi
        aliyun das GetInspectionReport --TaskId "$TASK_ID" 2>&1
        ;;

    *)
        echo "用法: $0 {create|report <TaskId>}"
        echo ""
        echo "命令："
        echo "  create            创建巡检任务（InstanceIds=all）"
        echo "  report <TaskId>   根据 TaskId 获取巡检报告"
        exit 1
        ;;
esac
