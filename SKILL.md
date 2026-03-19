---
name: alibabacloud-rds-inspection
description: >-
  Configure Alibaba Cloud RDS AI Assistant periodic database inspection and notification in OpenClaw.
  Use when user mentions: RDS巡检, 数据库巡检, RDS inspection, 定期巡检, 巡检报告, RDS health check,
  数据库健康检查, 配置巡检, inspection cron, RDS AI助手巡检. Covers ALIYUN CLI setup, one-time
  inspection test, cron scheduling, and notification channel binding for RDS instances.
metadata: { "openclaw": { "emoji": "🔍", "requires": { "bins": ["aliyun"] }, "homepage": "https://github.com/alibabacloud/alibabacloud-rds-inspection-skill" } }
---

# Alibaba Cloud RDS 数据库巡检技能

本技能采用「主 Agent + 子 Agent」协作协议，帮助用户在 OpenClaw 中配置 RDS AI 助手的定期巡检与通知。

## 协议约定

- **主 Agent**：负责流程编排、用户交互、状态流转判断
- **子 Agent**：负责具体任务执行（环境检查、巡检执行、定时任务配置）
- 所有回复**必须严格遵循**下方定义的回复模板，不得自由发挥
- 模板中 `{variable}` 为占位符，替换为实际值

## 工作流程总览

```
[开始]
  │
  ▼
Phase A ─ 环境检查（子 Agent: env-checker）
  │
  ▼
Phase B ─ 巡检测试确认
  ├─ 是 → Phase C（执行巡检测试）→ Phase D
  └─ 否 → Phase D
  │
  ▼
Phase D ─ 配置定时任务与通知（子 Agent: cron-scheduler）
  │
  ▼
[完成]
```

---

## Phase A：环境检查

**执行者**：子 Agent `env-checker`

执行 `{baseDir}/scripts/check_aliyun_cli.sh`，根据返回的 JSON 状态码决定回复。

### 回复模板

**A1 — CLI 未安装**（脚本返回 `CLI_NOT_INSTALLED`）

严格回复：

```
🔧 环境检查结果

❌ 未检测到 ALIYUN CLI，需要先安装才能继续。

📦 安装方式（请选择适合您系统的方式）：

  • macOS:
    brew install aliyun-cli

  • Linux:
    curl -fsSL https://aliyun-client-download.oss-cn-hangzhou.aliyuncs.com/install.sh | bash

  • 手动安装:
    https://github.com/aliyun/aliyun-cli/releases

安装完成后请告诉我，我将继续为您配置。
```

**A2 — CLI 已安装但 AK/SK 未配置**（脚本返回 `AK_NOT_CONFIGURED`）

严格回复：

```
🔧 环境检查结果

✅ ALIYUN CLI 已安装（版本：{version}）
❌ 未检测到有效的 AccessKey 配置

请执行以下命令配置您的阿里云访问凭证：

  aliyun configure

您需要准备：
  • AccessKey ID
  • AccessKey Secret
  • 默认 Region（如 cn-hangzhou）

⚠️ 请确保该 AccessKey 具有 RDS 和 DAS 相关 API 的调用权限。

配置完成后请告诉我，我将继续下一步。
```

**A3 — 环境就绪**（脚本返回 `READY`）

严格回复：

```
🔧 环境检查结果

✅ ALIYUN CLI 已安装（版本：{version}）
✅ AccessKey 已配置（Region：{region}）

环境检查通过！是否要进行一次巡检测试，验证配置是否正确？（是/否）
```

当用户完成安装或配置后再次确认，重新执行检查脚本，直到状态为 `READY` 后进入 Phase B。

---

## Phase B：巡检测试确认

**执行者**：主 Agent

用户在 Phase A3 回复后：

- 回答「是」→ 进入 **Phase C**
- 回答「否」→ 进入 **Phase D**

---

## Phase C：执行巡检测试

**执行者**：子 Agent `inspection-runner`

### 步骤

1. 调用 CreateInspectionTask：

```bash
bash {baseDir}/scripts/run_inspection.sh create
```

2. 从返回 JSON 中提取 `Data.TaskId`

3. 等待 **20 秒**

4. 调用 GetInspectionReport：

```bash
bash {baseDir}/scripts/run_inspection.sh report {TaskId}
```

5. 根据结果选择回复模板

### 回复模板

**C1 — 巡检成功**（GetInspectionReport 返回 `Success: true`）

严格回复：

```
🔍 巡检测试结果

✅ 巡检任务创建成功
   TaskId: {TaskId}
✅ 巡检报告已生成

📊 报告摘要：
{将报告中的关键指标和建议以简洁列表呈现}

巡检测试通过！是否继续配置定时巡检任务？（是/否）
```

用户回答「是」→ 进入 Phase D，回答「否」→ 结束。

**C2 — 未开通专业版**（返回错误码 `InvalidUserOrder`）

严格回复：

```
🔍 巡检测试结果

❌ 巡检失败 — 错误码：InvalidUserOrder

原因：您的 RDS 实例尚未开通「专业版 RDS AI 助手」，巡检功能需要专业版支持。

🔗 开通方式：
  1. 登录阿里云控制台
  2. 进入 RDS 管理页面
  3. 在「AI 助手」中开通专业版

开通后请告诉我，我将重新进行巡检测试。
```

用户确认开通后，重新执行 Phase C。

**C3 — 其他错误**

严格回复：

```
🔍 巡检测试结果

❌ 巡检失败
   错误信息：{Message}
   错误码：{Code}
   RequestId：{RequestId}

请检查以下可能原因：
  • AccessKey 权限是否包含 DAS 相关 API
  • 是否存在可用的 RDS 实例
  • 网络连接是否正常

排查后请告诉我，我将重新尝试。
```

---

## Phase D：配置定时任务与通知

**执行者**：子 Agent `cron-scheduler`

### Step D1：收集调度参数

严格回复：

```
⏰ 定时巡检配置

请告诉我您期望的巡检调度方案：

  1. 巡检频率：每天 / 每周 / 每月
  2. 执行时间：如 02:00
  3. 如选每周，请指定星期几：如 周一

示例：「每天凌晨 2:00 执行一次巡检」
```

### Step D2：生成 Cron 并配置

根据用户回答生成 cron 表达式，写入 OpenClaw 配置。

频率与 cron 对照：
- 每天 02:00 → `0 2 * * *`
- 每周一 03:00 → `0 3 * * 1`
- 每月 1 号 04:00 → `0 4 1 * *`

将以下配置写入 `~/.openclaw/openclaw.json` 的 `agents` 节点：

```json
{
  "agents": {
    "rds-inspection-cron": {
      "cron": "{cron_expression}",
      "message": "执行 RDS 数据库定期巡检：调用 CreateInspectionTask（InstanceIds=all），等待 20 秒后调用 GetInspectionReport 获取报告，将报告摘要发送到通知渠道。",
      "skill": "alibabacloud-rds-inspection"
    }
  }
}
```

### Step D3：配置通知渠道

严格回复：

```
📢 通知配置

是否需要将巡检结果发送到通知渠道？（是/否）
```

用户回答「是」时，读取 OpenClaw 当前已配置的 channel 列表，严格回复：

```
📢 可用通知渠道

{列出从 OpenClaw channel 配置中获取的渠道列表，编号展示}

请选择要接收巡检通知的渠道（输入编号，可多选，用逗号分隔）：
```

### Step D4：配置完成

**D4a — 含通知渠道**

严格回复：

```
✅ 定时巡检配置完成！

📋 配置摘要：
  • 巡检频率：{frequency}
  • 执行时间：{time}
  • Cron 表达式：{cron_expression}
  • 通知渠道：{channel_names}

🔄 下次巡检时间：{next_run_time}

定时巡检已激活，巡检结果将通过 {channel_names} 通知您。
如需修改配置，随时告诉我。
```

**D4b — 不含通知渠道**

严格回复：

```
✅ 定时巡检配置完成！

📋 配置摘要：
  • 巡检频率：{frequency}
  • 执行时间：{time}
  • Cron 表达式：{cron_expression}

🔄 下次巡检时间：{next_run_time}

定时巡检已激活。如需添加通知渠道或修改配置，随时告诉我。
```

---

## 定时巡检执行流程

当 cron 触发时，按以下流程执行：

1. `bash {baseDir}/scripts/run_inspection.sh create` → 提取 TaskId
2. 等待 20 秒
3. `bash {baseDir}/scripts/run_inspection.sh report {TaskId}` → 获取报告
4. 有通知渠道 → 发送报告摘要；无通知渠道 → 仅记录日志
5. 失败时通过通知渠道发送告警

### 通知消息模板

**巡检成功：**

```
📊 RDS 定期巡检报告

⏰ 执行时间：{timestamp}
✅ 状态：成功

{报告关键指标摘要}

详细报告请查看阿里云控制台。
```

**巡检失败：**

```
🚨 RDS 巡检告警

⏰ 执行时间：{timestamp}
❌ 状态：失败
📛 错误：{error_message}

请及时检查处理。
```

---

## API 参考

详细的 API 参数与返回值说明见 [references/api_reference.md](references/api_reference.md)。
