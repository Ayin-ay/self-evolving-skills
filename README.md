# Self-Evolving Skills

**[English](#english) | [中文](#中文)**

---

# 中文

**一套让 AI Agent 技能自我监控、从错误中学习、持续迭代修订自身的框架 —— 带人工信任分级、强制备份与回滚机制。**

基于 [OpenCode](https://opencode.ai)（命令行编程智能体）构建。不做微调、不训练模型，整个自我改进闭环全部通过**提示工程、基于文件的状态机和校验脚本**实现。

## 为什么做这个项目

LLM 智能体的失败方式是重复且可预测的：反复犯同一个格式错误、逐渐偏离用户偏好、跨会话记不住教训。与其每次手动补丁提示词，这个项目把**技能文件本身作为进化对象**。

每次任务执行都会被捕获、分析（失败模式、耗时瓶颈、冗余步骤、Token 浪费、多稿修改路径），分析结论再写回技能文件——把一次性的纠正变成永久的行为升级。

## 架构

```
┌────────────────────────────────────────────────────────┐
│                       用户任务                          │
│              （写作、编程、任何任务）                     │
└──────────────────────┬─────────────────────────────────┘
                       ▼
┌────────────────────────────────────────────────────────┐
│              目标技能（human-writing）                   │
│           SKILL.md + 参考规则 + 检查脚本                 │
└──────────────────────┬─────────────────────────────────┘
                       ▼ 执行遥测
┌────────────────────────────────────────────────────────┐
│              元技能（skill-evolver）                     │
│                                                        │
│   捕获 → 识别学习点 → 归类 → 进化报告 → 信任模式闸门      │
│      → 备份 → 修改 → 验证 →（必要时回滚）                │
│                                                        │
│  state.json（对话级）          config.json（全局默认）    │
│  evolution-log.md（变更史）    execution-log.md（运行史）│
└────────────────────────────────────────────────────────┘
```

## 核心设计决策

### 1. 信任模式 —— 自主性梯度

会自我修改的智能体需要一个安全旋钮。三种信任模式决定学习点如何落盘：

| 模式 | 行为 | 类比 |
|------|------|------|
| **A. 询问后修订** | 展示报告，用户逐条批准后才写入 | Human-in-the-loop |
| **B. 直接修订** | 自动修改文件，输出修改摘要 | 完全自主 |
| **C. 禁止修订** | 只分析和建议，绝不碰文件 | 影子模式 |

### 2. 修订模式 —— 何时触发分析

| 模式 | 触发方式 | 适用场景 |
|------|---------|---------|
| **A. 手动** | 用户说"任务完成" | 批量复盘 |
| **B. 自动** | **每条命令后**（强制，不可跳过） | 紧反馈回路 |
| **C. 反馈** | 用户给任务打分（准确性/效率/完整性/易用性，1-5 分）并指出不足 | 评分驱动调优 |
| **D. 校验** | 生成 3 篇风格变体真实内容，用户选定一篇，从差异中挖掘偏好 | 偏好提取 |

B 模式被设计为**强制程序**：即使什么都没发现，也必须明确输出「本次无学习点」，证明检查确实跑了。静默跳过视为违规。

### 3. 自触发智能体里发现的真实 Bug

开发过程中解决的真实问题（完整历史见 `skill-evolver/logs/evolution-log.md`）：

- **自触发** —— 智能体把自己输出里的触发词（"任务完成"）误判为用户指令，提前清空了上下文。用输入来源校验修复：规则只响应真实用户消息。
- **跨会话状态泄漏** —— 持久化的 `state.json` 让新对话继承了上个会话的启用状态。用初始化保护修复。
- **备份规则空转** —— 备份规则写在文档里，但备份目录从来没被创建过，直到一次自检发现。备份现在是硬性门槛：不备份，不修改。
- **强制检查噪音** —— 强制检测连纯确认回复（Y/n）也触发，输出大量零信息内容。现在纯确认被豁免。

### 4. 多稿修改路径追踪

写作任务中，框架追踪稿件从初稿到终稿的演化路径（用词、句式、结构），把用户的编辑偏好提炼回技能文件——让下一次的初稿更接近最终形态。

## 仓库结构

```
human-writing/        中文长文写作技能
├── SKILL.md          主规则（材料优先、禁用修辞等）
├── references/       分体裁指南（小说/现实/格式...）
└── scripts/          check_prose.py — 禁用句式检查器

skill-evolver/        进化其他技能的元技能
├── SKILL.md          状态模型、触发表、强制程序
├── references/       工作流、模式、审计标准、报告模板
├── scripts/          validate-skill.ps1, audit-skill.ps1（PowerShell）
└── logs/             evolution-log.md — 完整迭代历史
```

## 安装

**OpenCode**（Windows/macOS/Linux）
把 `human-writing/` 和 `skill-evolver/` 两个文件夹复制到 skills 目录：
- Windows `C:\Users\<用户名>\.config\opencode\skills\`
- macOS/Linux `~/.config/opencode/skills/`

**Claude Code**
本项目的 SKILL.md 与 Claude Code Agent Skills 格式兼容，把同样的两个文件夹复制到：
- Windows `C:\Users\<用户名>\.claude\skills\`
- macOS/Linux `~/.claude/skills/`

跨平台说明：`check_prose.py` 需要本机装有 Python 3；两个 `.ps1` 脚本仅支持 Windows PowerShell，macOS/Linux 下跳过脚本验证，按 SKILL.md 内的检查清单人工执行。`agents/openai.yaml` 是 OpenCode 专属配置，Claude Code 会忽略它，不影响使用。

## 进化历史

截至写作时共记录 17 次迭代，包括：诗歌格式强制化、风格模仿的借用边界、自动模式触发重设计（命令级而非会话级）、上下文清空硬约束、覆盖体验/质量/性能三端的 11 项自检。`skill-evolver/logs/evolution-log.md` 的每一条都记录了原因、修改内容和影响范围。

## 我学到了什么

- 基于提示的状态机是可行的，但每条规则都需要执行机制（硬性门槛、强制输出），否则规则会退化成文档。
- 智能体框架里最难的 Bug 都是**自指的**：智能体误读自己的输出、继承过期状态、跳过自己的安全步骤。
- 人类监督应该是*梯度*而不是开关——信任模式让同一套框架同时服务谨慎型和效率型用户。

## 作者

**离众（Ayin）** —— 浙江大学 2026 届。在学习智能体工程与 OpenCode 的过程中构建。

*本 README 由 human-writing 技能辅助撰写，并经 skill-evolver 反馈回路修订。*

---

# English

**A framework where AI agent skills monitor their own execution, learn from mistakes, and iteratively revise themselves — with human-in-the-loop trust grading, mandatory backups, and rollback.**

Built on [OpenCode](https://opencode.ai), a CLI coding agent. No fine-tuning, no model training — the entire self-improvement loop is implemented through **prompt engineering, file-based state machines, and validation scripts**.

## Why This Exists

LLM agents fail in recurring, predictable ways: they repeat the same formatting mistakes, drift away from user preferences, and cannot remember lessons across sessions. Instead of patching prompts by hand every time, this project makes **the skill files themselves the object of evolution**.

Every task execution is captured, analyzed for learning points (failure modes, bottlenecks, redundant steps, token waste, multi-draft revision paths), and the findings are written back into the skill — turning a one-off correction into a permanent behavioral upgrade.

## Architecture

```
┌────────────────────────────────────────────────────────┐
│                      User tasks                        │
│              (writing, coding, anything)               │
└──────────────────────┬─────────────────────────────────┘
                       ▼
┌────────────────────────────────────────────────────────┐
│              Target Skill (human-writing)              │
│        SKILL.md + references/ + lint scripts           │
└──────────────────────┬─────────────────────────────────┘
                       ▼ execution telemetry
┌────────────────────────────────────────────────────────┐
│              Meta Skill (skill-evolver)                │
│                                                        │
│  capture → identify learning points → categorize       │
│      → evolution report → trust-mode gate              │
│      → backup → modify → validate → (rollback?)        │
│                                                        │
│  state.json (per-conversation)   config.json (global)  │
│  evolution-log.md (changes)      execution-log.md (run)│
└────────────────────────────────────────────────────────┘
```

## Core Design Decisions

### 1. Trust Modes — an autonomy gradient

Self-modifying agents need a safety dial. Three trust modes decide how detected learning points reach the files:

| Mode | Behavior | Analogous to |
|------|----------|--------------|
| **A. Confirm-first** | Show report, user approves item-by-item, then write | Human-in-the-loop |
| **B. Direct revision** | Modify automatically, output a summary | Full autonomy |
| **C. Read-only** | Analyze and suggest, never touch files | Shadow mode |

### 2. Revision Modes — when analysis triggers

| Mode | Trigger | Use case |
|------|---------|----------|
| **A. Manual** | User says "task complete" | Batch review |
| **B. Auto** | After **every** command (mandatory, cannot be skipped) | Tight feedback loop |
| **C. Feedback** | User scores the task (accuracy/efficiency/completeness/usability, 1–5) + lists shortcomings | Grading-driven tuning |
| **D. Validation** | Generate 3 stylistic variants of real content, user picks one, diff is mined for preference | Preference elicitation |

Mode B is enforced as a **mandatory procedure**: even when nothing is found, the agent must explicitly output "no learning points this round", proving the check ran. Silent skips are treated as violations.

### 3. Bugs found in a self-triggering agent

Real problems solved during development (see `skill-evolver/logs/evolution-log.md` for the full history):

- **Self-triggering** — the agent mistook trigger phrases ("task complete") *in its own output* for user commands and cleared context prematurely. Fixed by input-source validation: rules only respond to actual user messages.
- **Cross-session state leakage** — a persistent `state.json` made a new conversation inherit the previous session's "enabled" flag. Fixed with initialization protection.
- **Unenforced backups** — the backup rule existed on paper but the backup directory was never created until a self-audit caught it. Backups are now a hard gate: no backup, no modification.
- **Noisy mandatory checks** — the mandatory detection fired even on pure confirmations (Y/n), spamming zero-information output. Now pure confirmations are exempted.

### 4. Multi-draft revision-path tracking

For writing tasks, the framework tracks how drafts evolve (word choice, sentence patterns, structure) from first draft to final, and distills the user's editing preferences back into the skill — so the next first draft starts closer to the final shape.

## Repository Layout

```
human-writing/        Chinese long-form prose skill
├── SKILL.md          main rules (material-first, banned rhetoric, etc.)
├── references/       genre-specific guides (fiction, reality, formats...)
└── scripts/          check_prose.py — prose linter for banned patterns

skill-evolver/        the meta skill that evolves the others
├── SKILL.md          state model, trigger table, mandatory procedures
├── references/       workflow, modes, audit criteria, report templates
├── scripts/          validate-skill.ps1, audit-skill.ps1 (PowerShell)
└── logs/             evolution-log.md — full iteration history
```

## Installation

**OpenCode** (Windows/macOS/Linux)
Copy the `human-writing/` and `skill-evolver/` folders into the skills directory:
- Windows `C:\Users\<you>\.config\opencode\skills\`
- macOS/Linux `~/.config/opencode/skills/`

**Claude Code**
The SKILL.md format is compatible with Claude Code Agent Skills. Copy the same two folders into:
- Windows `C:\Users\<you>\.claude\skills\`
- macOS/Linux `~/.claude/skills/`

Cross-platform notes: `check_prose.py` requires Python 3; the two `.ps1` scripts are Windows PowerShell only — on macOS/Linux skip them and follow the manual checklists inside SKILL.md. `agents/openai.yaml` is an OpenCode-specific extra; Claude Code simply ignores it.

## Evolution History

17 recorded iterations at time of writing, including: poetry formatting enforcement, imitation-bounds for style transfer, auto-mode trigger redesign (command-level instead of session-level), context-clearing hard constraints, and an 11-item self-audit covering UX, output quality, and performance. Each entry in `skill-evolver/logs/evolution-log.md` records the reason, the change, and the scope of impact.

## What I Learned

- Prompt-based state machines work, but every rule needs an enforcement mechanism (hard gates, mandatory outputs), otherwise rules decay into documentation.
- The hardest bugs in agent frameworks are **self-referential**: the agent misreading its own output, inheriting stale state, or skipping its own safety steps.
- Human oversight should be a *gradient*, not a checkbox — trust modes let the same framework serve cautious and power users.

## Author

**离众 (Ayin)** — Zhejiang University, Class of 2029. Built while learning agent engineering with OpenCode.

*This README was itself written with the help of the human-writing skill, then revised by skill-evolver's feedback loop.*
