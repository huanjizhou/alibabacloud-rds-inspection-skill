# RDS AI 助手巡检 API 参考

## CreateInspectionTask

创建数据库巡检任务。

### 请求参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| InstanceIds | String | 是 | 实例 ID 列表，传 `all` 表示全部实例 |

### CLI 调用

```bash
aliyun das CreateInspectionTask --InstanceIds "all"
```

### 成功响应

```json
{
  "Message": "任务创建成功",
  "RequestId": "840E43E9-46EB-5026-919A-9E9C3D672141",
  "Data": {
    "TaskId": "5c8dc00b-699e-48e3-ab2d-cd0aaa2ed818"
  },
  "Success": true
}
```

### 错误响应

| Code | 含义 | 处理方式 |
|------|------|----------|
| InvalidUserOrder | 未开通专业版 RDS AI 助手 | 提示用户前往阿里云控制台开通 |
| InvalidAccessKeyId | AccessKey 无效 | 检查 AK/SK 配置 |
| Forbidden | 权限不足 | 检查 AK 是否具有 DAS API 权限 |

---

## GetInspectionReport

根据 TaskId 获取巡检报告。

### 请求参数

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| TaskId | String | 是 | CreateInspectionTask 返回的任务 ID |

### CLI 调用

```bash
aliyun das GetInspectionReport --TaskId "5c8dc00b-699e-48e3-ab2d-cd0aaa2ed818"
```

### 成功响应

```json
{
  "RequestId": "xxx",
  "Data": {
    "TaskId": "5c8dc00b-699e-48e3-ab2d-cd0aaa2ed818",
    "Status": "completed",
    "Report": {
      "Summary": "巡检完成，共检查 N 个实例",
      "Items": [
        {
          "InstanceId": "rm-xxxxx",
          "InstanceName": "production-db",
          "Level": "warning",
          "Issues": [
            {
              "Category": "性能",
              "Description": "慢查询数量偏高",
              "Suggestion": "建议优化 Top SQL"
            }
          ]
        }
      ]
    }
  },
  "Success": true
}
```

### 注意事项

- 创建任务后需等待约 **20 秒**再获取报告，否则可能返回任务未完成状态
- 如报告未就绪，可间隔 10 秒重试，最多重试 3 次
