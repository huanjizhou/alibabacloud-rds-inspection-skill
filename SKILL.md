---
name: alibabacloud-rds-inspection
description: >-
  阿里云 RDS 数据库定期巡检与通知：环境配置、巡检执行、历史对比、定时任务。
  触发词：RDS巡检, 数据库巡检, 定期巡检, 巡检报告, /inspection.
metadata: { "openclaw": { "emoji": "🔍", "requires": { "bins": ["aliyun"] }, "homepage": "https://github.com/huanjizhou/alibabacloud-rds-inspection-skill" } }
---

# Alibaba Cloud RDS 数据库巡检技能

本技能采用「主 Agent + 子 Agent」协作协议，帮助用户在 OpenClaw 中配置 RDS AI 助手的定期巡检与通知。

API 产品码：`RdsAi`（不指定 `--version`，自动使用最新 API 版本）。

## 协议约定

- **主 Agent**：负责流程编排、用户交互、状态流转判断
- **子 Agent**：负责具体任务执行（环境检查、巡检执行、定时任务配置）
- 所有回复**必须严格遵循**下方定义的回复模板，不得自由发挥
- 模板中 `{variable}` 为占位符，替换为实际值

### 严格禁止（⚠️ 必须遵守）

1. **仅允许调用以下两个 API**（产品码 `RdsAi`，不指定 `--version`）：
   - `CreateInspectionTask` — 创建巡检任务
   - `GetInspectionReport` — 获取巡检报告
2. **绝对禁止**使用任何其他 RDS API 或产品（如 `rds DescribeDBInstances`、`das` 系列）代替或"降级"巡检
3. **绝对禁止**自行添加 `--version` 参数或更换产品码；如遇报错，向用户反馈而非自行尝试
4. **绝对禁止**在巡检等待期间向用户暴露内部错误（如 `InternalError`、`Throttling`）；轮询过程中遇到瞬态错误应静默重试，仅告知用户「⏳ 巡检报告生成中，请稍候……」
5. **绝对禁止**自行发明替代巡检方案（如"用标准 API 做基础巡检"、"手动查询慢日志"等）；本技能只做 RDS AI 专业版巡检，无替代方案

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

是否授权我为您自动安装 ALIYUN CLI？（是/否）
```

用户回答「是」后，执行更稳健的安装脚本自动下载：

```bash
bash {baseDir}/scripts/install_aliyun_cli.sh
```

安装完成后严格回复：

```
✅ ALIYUN CLI 安装完成！

正在重新检查环境配置……
```

随后自动重新执行 `{baseDir}/scripts/check_aliyun_cli.sh`，根据新状态继续流转。

用户回答「否」时严格回复：

```
好的，您也可以手动安装：
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

⚠️ 请确保该 AccessKey 具有 RDS AI 服务（RdsAi）相关 API 的调用权限。

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

1. 调用 CreateInspectionTask（创建一次性巡检任务）：

```bash
bash {baseDir}/scripts/run_inspection.sh create
```

2. 从返回 JSON 中提取 `Data.TaskId`
   - 如果 create 返回 `InvalidUserOrder` → 直接跳转 **C2 模板**（用户未开通专业版）
   - 如果 create 返回其他错误 → 跳转 **C3 模板**

3. 告知用户「⏳ 巡检任务已创建，正在等待报告生成……」，然后调用 report：

```bash
bash {baseDir}/scripts/run_inspection.sh report {TaskId}
```

   脚本内置最高 120 秒自动轮询。**轮询期间所有 InternalError / Throttling 等瞬态错误均由脚本静默重试**，Agent 无需干预，也**禁止向用户展示轮询中间状态或内部错误**。

4. 脚本返回后，从输出中解析 `Data[]`（各实例详情及 `LevelSummary`），根据结果选择回复模板。API 返回结构详见 [references/api_reference.md](references/api_reference.md)
   - 包含有效 `Data` → **C1 模板**
   - 超时未返回 → 向用户说明「巡检报告生成超时，请稍后重试」，不暴露内部错误细节

### 回复模板

**C1 — 巡检成功**（返回中包含 `MarkdownText` 和 `Data`）

解析规则：
1. 遍历所有 `Data[].Data[].Items[]`，按 `Level` 分桶（Error / Warning / Normal）
2. 输出时按严重性排序：**Error 优先 → Warning 次之**
3. 每条问题需包含：实例 ID、实例描述、巡检模块（Group）、具体问题描述（Message）
4. 保存巡检记录（见「巡检记录存储与对比」章节）

严格回复：

```
🔍 巡检测试结果

✅ 巡检任务完成（TaskId: {TaskId}）

📋 总体概览
  巡检实例数：{total_instances}
  检查项总数：{total_checks}
  ✅ 正常：{normal_count} | ⚠️ 警告：{warning_count} | ❌ 错误：{error_count}

{如有 Error 项，输出以下区块}
🔴 高危问题（{error_count} 项）：
{按实例分组，每条 Error 级别 Item 输出一行}
  ❌ {InstanceId} ({InstanceDesc}) — [{Group}] {Message}

{如有 Warning 项，输出以下区块}
⚠️ 警告项（{warning_count} 项）：
{按实例分组，每条 Warning 级别 Item 输出一行}
  ⚠️ {InstanceId} ({InstanceDesc}) — [{Group}] {Message}

📊 异常实例摘要：
{仅列出有 Warning 或 Error 的实例}
  {InstanceId} ({InstanceDesc}, {EngineType}, {Region})
    正常: {Normal} | 警告: {Warning} | 错误: {Error}

📈 模块健康度：
{汇总各 Group 的问题数，仅列出有异常的模块}
  ❌ {Group}：{error}项错误, {warning}项警告
  ⚠️ {Group}：{warning}项警告
  ✅ 其余 {n} 个模块健康

{如果有历史记录，输出对比区块，见「巡检记录存储与对比」章节}

巡检测试通过！是否继续配置定时巡检任务？（是/否）
```

用户回答「是」→ 进入 Phase D，回答「否」→ 结束。

**C2 — 未开通专业版**（HTTP 403，错误码 `InvalidUserOrder`）

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
  • AccessKey 权限是否包含 rdsai 相关 API（rdsai:CreateInspectionTask、rdsai:GetInspectionReport）
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

1. `bash {baseDir}/scripts/run_inspection.sh create` → 提取 `Data.TaskId`
2. 无需等待，下方的 report 工具内置轮询
3. `bash {baseDir}/scripts/run_inspection.sh report {TaskId}` → 获取报告
4. 解析所有 `Data[].Data[].Items[]`，按 Level 分桶（Error / Warning）
5. 调用 `python3 {baseDir}/scripts/compare_inspection.py {last_record} {current_record}` 生成对比分析，直接提取输出区块
6. 保存本次巡检记录
7. 按照下方模板生成通知内容，发送到通知渠道
8. 失败时发送告警通知

### 通知消息模板

**巡检成功：**

```
📊 RDS 定期巡检报告

⏰ 执行时间：{timestamp}
✅ 状态：成功

📋 总体概览
  巡检实例数：{total_instances} | 高危实例：{error_instances} | 警告实例：{warning_instances}
  检查项：✅ {normal} | ⚠️ {warnings} | ❌ {errors}

{如有 Error 项}
🔴 高危问题（{error_count} 项）：
  ❌ {InstanceId} ({InstanceDesc}) — [{Group}] {Message}
  ❌ {InstanceId} ({InstanceDesc}) — [{Group}] {Message}
  ...

{如有 Warning 项}
⚠️ 警告项（{warning_count} 项）：
  ⚠️ {InstanceId} ({InstanceDesc}) — [{Group}] {Message}
  ...

📊 与上次巡检对比：
  🆕 新增问题：{new_count} 项
  ✅ 已修复：{resolved_count} 项
  🔄 持续存在：{persistent_count} 项
  {如有新增问题，逐条列出}

📈 模块健康度：
  {仅列出有异常的模块}
  ❌ {Group}：{errors}项错误, {warnings}项警告
  ✅ 其余 {n} 个模块健康

详细报告请查看阿里云控制台。
```

**巡检失败：**

```
🚨 RDS 巡检告警

⏰ 执行时间：{timestamp}
❌ 状态：失败
📛 错误码：{Code}
📛 错误信息：{Message}

请及时检查处理。
```

---

## 巡检记录存储与对比

### 存储规则

每次巡检完成后（Phase C 或 cron 触发），将结果保存到 `{baseDir}/records/inspections/`：

```
records/inspections/
├── 2026-03-19_0200_{taskId}.json   # 最近一次
├── 2026-03-18_0200_{taskId}.json   # 上一次
└── ...
```

每个 JSON 文件结构：`task_id`、`timestamp`、`total_instances`、`summary`（normal/warning/error/failed 计数）、`issues` 数组。

`issues` 只收录 Level 为 Error 或 Warning 的 Item，每项包含 `instance_id`、`instance_desc`、`engine_type`、`region`、`level`、`group`、`message`，按严重性排序（Error → Warning）。

### 对比分析逻辑

每次生成报告前，不要自己去读取比对庞大的 JSON！！
直接调用内置的对比脚本：
```bash
python3 {baseDir}/scripts/compare_inspection.py {records/inspections/last_record.json} {records/inspections/current_record.json}
```
脚本会立刻输出标准格式的对比结果摘要。将脚本的标准输出（STDOUT）完整嵌入到下方模板的 `📊 与上次巡检对比：` 区块中。

```
📊 与上次巡检对比（上次：{last_timestamp}）：
  🆕 新增问题：{new_count} 项
  ✅ 已修复：{resolved_count} 项
  🔄 持续存在：{persistent_count} 项

{如有新增问题}
  新增：
    ❌ {InstanceId} ({InstanceDesc}) — [{Group}] {Message}
    ...

{如有已修复}
  修复：
    ✅ {InstanceId} ({InstanceDesc}) — [{Group}] {Message}（已恢复正常）
    ...
```

如果没有历史记录（首次巡检），跳过对比区块，仅在末尾提示：`📝 首次巡检，无历史对比数据。`

---

## API 参考

详细的 API 参数与返回值说明见 [references/api_reference.md](references/api_reference.md)。
