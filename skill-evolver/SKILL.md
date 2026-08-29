---
name: skill-evolver
description: 自动监控、评估并迭代优化所有 OpenCode Skill。触发词：开始修订、结束修订、任务完成、修订完成、进化技能、优化skill、检查技能库、更新skill、技能复盘、状态、回滚上次修改、帮助。
triggers:
  - 开始修订
  - 结束修订
  - 任务完成
  - 修订完成
  - 进化技能
  - 优化 skill
  - 优化skill
  - 检查技能库
  - 更新 skill
  - 更新skill
  - 技能复盘
  - 优化技能
  - skill evolve
  - skill audit
  - review skills
  - 状态
  - 查看状态
  - 回滚上次修改
  - 撤销上次修改
  - 帮助
priority: high
---

# Skill Evolver 1.4.0

## 状态模型

两层状态：

- **对话级状态**（`logs\state.json` 的 `conversation` 字段）：enabled、初始化配置，仅当前对话生效，新对话开始时重置为禁用
- **持久化默认规则**（`logs\config.json`）：新对话的默认启用状态、默认信任/修订模式、各 Skill 的修订默认值，跨对话生效

新对话开始时：conversation.enabled 取 config.json 的 default_enabled_on_new_conversation（默认 false），skill_states 继承 skill_defaults。

**跨对话状态保护**：state.json 持久存储在磁盘上，新对话可能读到上一会话残留的 enabled: true。若当前对话内尚未执行过「开始修订」启用流程，一律视为未初始化状态处理（按未启用或需初始化走流程），不继承旧会话的对话级状态。

## 强制程序（自动模式）

修订方式为 B（自动模式）时，每次命令执行完毕后必须立即自动运行修订检测并输出结果，这是强制步骤，任何情况下不得跳过：

1. 捕获本次执行上下文
2. 识别学习点（失败模式、时间瓶颈、冗余步骤、重复工作流、Token 浪费、内容过时或错误、修改路径追踪——当内容被要求修改时，记录各稿修改的字词与趋势，优化 Skill 使其更贴合终稿）
3. 生成修改建议并输出

即使未发现可修改内容，也必须明确输出「本次无学习点」，让用户确认检测已执行。输出的修改建议只按信任模式决定是否落盘：A 逐条确认，B 直接改，C 仅输出不改。

强制程序只负责检测与输出，不负责清空上下文。清空上下文仅由用户输入「任务完成」或「修订完成」触发，模型不得自行清空。

**不可跳过规则**：自动模式下，每次输出稿件或修改后，必须立即输出学习点分析结果，不得先输出内容再跳过分析。即使分析结果为"无学习点"，也必须明文输出。用户指出的"未检测"问题视为严重违规，需在变更日志中记录。

## 快速判断

读取 `logs\state.json` 后按表执行，命中即返回，不加载其他文件。注意：表中「用户输入」仅指用户实际发送的消息，不响应模型自身输出的文本。

| conversation.enabled | 用户输入 | 动作 |
|----------------------|---------|------|
| true | 状态/查看状态 | 直接返回状态摘要（enabled、信任模式、修订方式、skill_states），不触发任何分析 |
| true | 回滚上次修改/撤销上次修改 | 从 `logs\backups\` 恢复最近一次被修改的文件，记录变更日志 |
| true | 开始修订 | 直接返回状态摘要 |
| true | 任务完成 | revision_mode 为 A → 读 `references/core-workflow.md` 触发修订分析，不清空上下文；为 B/C/D → 清空已完成任务上下文（B 已在此前每次命令后自动检测，本指令仅用于清空） |
| true | 修订完成 | 清空已完成任务上下文（仅 revision_mode A 手动模式下先触发修订分析，用户输入"修订完成"后执行清空） |
| true | 结束修订/停止修订/关闭修订/禁用修订/结束进化 | state.json 写 enabled: false（仅本对话），返回确认 |
| true | 进化技能/优化skill/技能复盘/更新skill | 读 `references/core-workflow.md` 执行修订流程 |
| true | 检查技能库 | 读 `references/audit-criteria.md` 执行审计 |
| true | 启用/禁用 <skill-name> | 更新 state.json 的 skill_states，仅本对话生效 |
| true | 全部启用/全部禁用 | 批量更新 skill_states |
| true | 修改新对话默认 | 更新 config.json（默认启用状态、默认模式、skill 默认值） |
| false | 开始修订/启动修订/启用修订/打开修订/开启技能进化/开始进化 | state.json 写 enabled: true；本对话无配置则读 `references/config.md` 初始化 |
| 任意 | 帮助 | 读 `references/guidelines.md` 输出菜单 |
| 任意 | 创建 Skill/新建 Skill/添加技能 | 读 `references/create-skill.md` |

## 对话清空规则

**硬性约束**：清空上下文只能由用户实际输入「任务完成」或「修订完成」触发，模型不得在自己的回复中自行执行清空。手动模式（A）下「任务完成」不触发清空（仅触发分析），用户确认后输入「修订完成」才清空。

skill-evolver 启用期间，所有任务完成后清空当前对话上下文，使后续任务不重复读取历史记录。

- **自动模式（B）**：每次任务完成后自动检测需要修改的内容并输出，无需用户说"任务完成"；"任务完成"仅用于清空上下文
- **反馈/校验模式（C/D）**：输入"任务完成"后清空上下文
- **手动模式（A）**：输入"任务完成"触发修订分析，用户确认后输入"修订完成"清空上下文

## 修订范围

仅对 skill_states 中标记为 enabled 的 Skill 执行修订分析和修改。标记为 disabled 的 Skill 只记录执行数据供审计，不触发修订。审计（检查技能库）始终覆盖所有 Skill。

## 参考文件索引

| 文件 | 用途 |
|------|------|
| `references/config.md` | 初始化配置选项与默认规则说明 |
| `references/core-workflow.md` | 核心修订流程 |
| `references/create-skill.md` | Skill 创建模块 |
| `references/feedback-mode.md` | 反馈/校验模式 |
| `references/guidelines.md` | 约束、错误处理、帮助菜单 |
| `references/evolution-template.md` | 进化报告模板 |
| `references/audit-criteria.md` | 审计标准 |