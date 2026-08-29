# Self-Evolving Skills

**A framework where AI agent skills monitor their own execution, learn from mistakes, and iteratively revise themselves — with human-in-the-loop trust grading, mandatory backups, and rollback.**

Built on [OpenCode](https://opencode.ai), a CLI coding agent. No fine-tuning, no model training — the entire self-improvement loop is implemented through **prompt engineering, file-based state machines, and validation scripts**.

---

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

## Evolution History

17 recorded iterations at time of writing, including: poetry formatting enforcement, imitation-bounds for style transfer, auto-mode trigger redesign (command-level instead of session-level), context-clearing hard constraints, and an 11-item self-audit covering UX, output quality, and performance. Each entry in `skill-evolver/logs/evolution-log.md` records the reason, the change, and the scope of impact.

## What I Learned

- Prompt-based state machines work, but every rule needs an enforcement mechanism (hard gates, mandatory outputs), otherwise rules decay into documentation.
- The hardest bugs in agent frameworks are **self-referential**: the agent misreading its own output, inheriting stale state, or skipping its own safety steps.
- Human oversight should be a *gradient*, not a checkbox — trust modes let the same framework serve cautious and power users.

## Author

**离众 (Ayin)** — Zhejiang University, Class of 2029. Built while learning agent engineering with OpenCode.

*This README was itself written with the help of the human-writing skill, then revised by skill-evolver's feedback loop.*
