# RDS AI 巡检 API 参考

产品码：`rdsai`（不指定 `--version`，自动使用最新 API 版本）

CLI 基础格式：`aliyun rdsai <action> --region <Region> [--<param> <value>]`

API 文档：https://help.aliyun.com/zh/rds/developer-reference/api-rdsai-2025-05-07-overview

---

## 一次性巡检

### create-inspection-task — 创建批量实例巡检任务

```bash
aliyun rdsai create-inspection-task --instance-ids "all" --region cn-hangzhou
```

#### 请求参数

| 参数 | 类型 | 必填 | 说明 | 示例 |
|------|------|------|------|------|
| --instance-ids | String | 否 | 实例 ID 列表，逗号分隔；传 `all` 表示全部 | `rm-xxx,rm-yyy` |
| --start-time | String | 否 | 巡检范围开始时间（UTC），默认最近 24h | `2025-12-28T16:00:00Z` |
| --end-time | String | 否 | 巡检范围结束时间（UTC），默认最近 24h | `2026-01-30T02:10:48Z` |
| --inspection-items | String | 否 | 巡检项列表，逗号分隔，空则全部 | `instance_info,resource_usage` |

可用巡检项：
- `instance_info` — 实例信息
- `resource_usage` — 资源使用
- `connection_session_management` — 连接会话管理
- `performance_metrics` — 性能指标
- `slow_query_analysis` — 慢查询分析
- `error_log_analysis` — 错误日志分析
- `lock_wait_deadlock_analysis` — 锁等待与死锁分析
- `backup_recovery_analysis` — 备份恢复分析
- `high_availability_disaster_recovery_analysis` — 高可用与容灾巡检
- `security_configuration_analysis` — 安全配置巡检
- `storage_engine_analysis` — 存储引擎巡检
- `schema_object_analysis` — Schema 与对象巡检

#### 成功响应

```json
{
  "Success": true,
  "Message": "任务创建成功",
  "Data": {
    "TaskId": "9adf8567-b619-4d37-8ff2-01d38a76****"
  },
  "RequestId": "FE9C65D7-930F-57A5-A207-8C396329****"
}
```

---

### get-inspection-report — 获取巡检报告

```bash
aliyun rdsai get-inspection-report --task-id "9adf8567-xxxx" --region cn-hangzhou
```

#### 请求参数

| 参数 | 类型 | 必填 | 说明 | 示例 |
|------|------|------|------|------|
| --task-id | String | 是 | 巡检报告 ID | `9adf8567-b619-4d37-8ff2-01d38a76****` |
| --instance-id | String | 否 | 指定实例则只返回该实例报告（含 MarkdownText）；不传则返回所有实例摘要（MarkdownText 为空） | `rm-2zep6e5u6l2yu****` |

#### 成功响应（不传 --instance-id）

```json
{
  "TaskId": "9adf8567-xxxx",
  "MarkdownText": "# RDS批量巡检汇总报告\n\n> 本次批量巡检共检查 **1** 个实例……",
  "Data": [
    {
      "InstanceId": "rm-2zep6e5u6l2yu****",
      "EngineType": "MySQL",
      "InstanceDesc": "测试实例",
      "Region": "cn-beijing",
      "MarkdownText": "",
      "StartTime": "2025-11-06T16:00:00Z",
      "EndTime": "2026-01-31T02:05:04Z",
      "LevelSummary": {
        "Normal": 57,
        "Warning": 1,
        "Error": 0,
        "Failed": 2
      },
      "Data": [
        {
          "Group": "instance_info",
          "Items": [
            {
              "Name": "instance_runningstatus",
              "Message": "实例运行状态正常",
              "Level": "Normal",
              "Data": [{ "Key": "DBInstanceStatus", "Value": "Running" }]
            }
          ]
        }
      ]
    }
  ],
  "RequestId": "FE9C65D7-930F-57A5-A207-8C396329****"
}
```

#### 关键字段说明

- `MarkdownText`（顶层）：整体批量巡检汇总（Markdown 格式），可直接用于通知
- `Data[].LevelSummary`：各实例巡检级别统计（Normal / Warning / Error / Failed）
- `Data[].MarkdownText`：单实例详细报告（仅传入 --instance-id 时返回）
- `Data[].Data[].Items[]`：各巡检项原始数据

---

### get-stand-alone-reports — 查询非定时任务的巡检报告列表

```bash
aliyun rdsai get-stand-alone-reports --region cn-hangzhou
```

#### 请求参数

| 参数 | 类型 | 必填 | 说明 | 示例 |
|------|------|------|------|------|
| --start-time | String | 否 | 开始时间过滤（UTC） | `2025-03-11T02:09:00Z` |
| --end-time | String | 否 | 结束时间过滤（UTC） | `2026-01-19T02:20:20Z` |
| --page-number | Long | 否 | 页码，默认 1 | `1` |
| --page-size | Long | 否 | 每页数量，默认 20，最大 100 | `10` |

---

## 定时巡检

### create-scheduled-task — 创建定时巡检配置

```bash
aliyun rdsai create-scheduled-task \
  --name "每日巡检" \
  --instance-ids "rm-xxx,rm-yyy" \
  --frequency "DAILY" \
  --start-time "02:00:00Z" \
  --region cn-hangzhou
```

#### 请求参数

| 参数 | 类型 | 必填 | 说明 | 示例 |
|------|------|------|------|------|
| --name | String | 是 | 任务名称（≤64 字符） | `每日RDS巡检` |
| --description | String | 否 | 任务描述 | `定时RDS实例巡检任务` |
| --instance-ids | String | 否 | 实例 ID 列表，逗号分隔 | `rm-xxx,rm-yyy` |
| --start-time | String | 否 | 执行时间（UTC），默认 `02:00:00Z` | `02:00:00Z` |
| --frequency | String | 否 | 频率，默认 `DAILY` | `Monday` |
| --time-range | String | 否 | 巡检时间范围（小时），默认 24，最大 168 | `24` |
| --report-language | String | 否 | 报告语言，默认 `zh-CN` | `zh-CN` |

Frequency 取值：`DAILY`、`Monday`、`Tuesday`、`Wednesday`、`Thursday`、`Friday`、`Saturday`、`Sunday`（多个用逗号分隔，DAILY 覆盖周设置）

#### 成功响应

```json
{
  "ScheduledId": "847268a4-196f-416b-aa12-bfe0c115****",
  "Success": true,
  "Message": "创建定时巡检任务成功",
  "RequestId": "D984FD38-6C2D-55DF-B0D7-8BCAC2E1F8C2"
}
```

### 其他定时巡检 API

- `list-scheduled-tasks` — 查询用户所有巡检配置
- `modify-scheduled-task` — 修改已有巡检配置
- `delete-scheduled-task` — 删除指定巡检配置
- `get-scheduled-instances` — 查询定时巡检配置中的实例列表
- `get-scheduled-reports` — 查询定时任务下的巡检报告列表（支持时间范围过滤和分页）

---

## 统一错误码

| HTTP 状态码 | 错误码 | 错误信息 | 说明 |
|-------------|--------|----------|------|
| 400 | InvalidParameter | Request parameter validation failed. | 请求参数校验失败 |
| 403 | PermissionDenied | User has no operation permission. | 用户无操作权限 |
| 403 | InvalidUserOrder | There is no valid order for this UID. | **未开通专业版 RDS AI 助手** |
| 404 | TaskNotFound | The resource of the specified Id does not exist. | 任务 ID 不存在 |
| 500 | InternalError | System internal exception. | 系统内部异常 |

RAM 权限 Action 前缀：`rdsai:`（如 `rdsai:CreateInspectionTask`、`rdsai:GetInspectionReport`、`rdsai:CreateScheduledTask`）
