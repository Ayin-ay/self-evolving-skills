# 初始化配置

## 对话内初始化

每次对话首次通过“开始修订”启用时，若本对话尚未初始化，依次选择信任模式和修订方式。选择结果仅写入 `logs\state.json` 的 conversation 字段，只对当前对话生效。

## 信任模式

- **A. 询问后修订（推荐）**：生成报告后逐条确认再执行
- **B. 直接修订**：自动执行修改，输出摘要
- **C. 禁止修订**：只记录和分析，不修改文件

## 修订方式

- **A. 手动模式**：仅用户指示后分析
- **B. 自动模式**：任务完成后自动分析
- **C. 反馈模式**：任务结束后评分
- **D. 校验模式**：多种变体供比较

## 修改新对话默认规则

用户说“修改默认配置”、“设置新对话默认”时，更新 `logs\config.json`：

- **默认启用状态**（default_enabled_on_new_conversation）：新对话开始时 skill-evolver 是否自动启用，默认 false
- **默认信任/修订模式**（default_trust_mode / default_revision_mode）：新对话初始化时直接沿用的模式，跳过询问
- **Skill 修订默认值**（skill_defaults）：各 Skill 在新对话中的修订启用状态

示例：
- “新对话默认启用” → default_enabled_on_new_conversation: true
- “新对话默认信任模式 A、修订方式 B” → 填入 default_trust_mode 和 default_revision_mode，后续新对话跳过初始化询问
- “human-writing 新对话默认禁用修订” → skill_defaults.human-writing: "disabled"

## 配置文件格式

`logs\config.json`：
```json
{
  "default_enabled_on_new_conversation": false,
  "default_trust_mode": null,
  "default_revision_mode": null,
  "skill_defaults": {
    "human-writing": "enabled"
  }
}
```

`logs\state.json` 的 conversation 字段（对话级，不跨对话）：
```json
{
  "enabled": false,
  "initialized": false,
  "trust_mode": null,
  "revision_mode": null,
  "activated_at": null
}
```