# 改进 01：异构 lead / helper 模型

## 动机

原始 GVS5H 的 manager 循环中，**所有角色（lead 主代理 + helper 助手）共用同一个模型**
（`multiagent.py` 的单一 `MODEL` 变量）。本改进让两类角色可以使用**不同模型**，例如：

- 强模型当 lead（负责规划 `primary_plan` / 管理决策 `primary_manage`），便宜模型当 helper（执行 `worker` / `ideation` / `finalize`）→ 在保持编排质量的同时降低成本；
- 或反向配置，探究"管理能力强 vs 执行能力强"哪个对增益贡献更大。

这呼应了项目早期的"模型升级阶梯"（`orchestrator.escalate`）思路，但保留 v2 的共享磁盘编排结构。

## 角色划分

| 类别 | 角色 | 默认模型 |
|---|---|---|
| **lead** | `primary_plan`, `primary_manage` | `LEAD_MODEL` |
| **helper** | `ideation`, `worker:*`, `finalize`, `cutoff_summary`, `single` | `HELPER_MODEL` |

`LEAD_MODEL` / `HELPER_MODEL` 未设置时都回退到 `MULTIAGENT_MODEL`，**行为与原始单模型完全一致**（向后兼容）。

## 应用补丁

从仓库根目录：

```bash
git apply improvements/01-heterogeneous-models/heterogeneous.patch
# 或
patch -p1 < improvements/01-heterogeneous-models/heterogeneous.patch
```

补丁只改 `codebase/v2-current/escalation/multiagent.py` 两处：
1. 新增 `LEAD_MODEL` / `HELPER_MODEL` / `LEAD_ROLES` 定义；
2. `_chat()` 按角色选模型，并把实际 `model` 写入 `transcript.jsonl`（便于事后按角色统计 token / 成本）。

## 配置示例

```bash
# lead 用强模型，helper 用本地 27B
export MULTIAGENT_MODEL="groq:q38"            # 回退默认
export LEAD_MODEL="anthropic:claude-opus-4-5" # 主代理：规划/管理
export HELPER_MODEL="groq:q38"                # 助手：本地 Qwen3.8-27B-FP8
# 其余环境同复现脚本（ESCALATION_OPENAI_BASE 等）
```

底层 `orchestrator.chat()` 已支持任意厂商前缀（`groq:` / `openai:` / `anthropic:` / `dashscope:` / `openrouter:`），
因此 lead 与 helper 可跨后端、跨模型自由组合。

## 建议实验臂（与单模型基线对照）

| 臂 | lead | helper | 目的 |
|---|---|---|---|
| baseline | 27B | 27B | 复现论文单模型结果 |
| strong-lead | Opus/Fable | 27B | 强管理 + 廉价执行，省成本 |
| strong-helper | 27B | Opus/Fable | 强执行 + 廉价管理 |
| cheap-lead | 9B | 27B | 探究管理能力的下限 |

## 权衡与注意

- **混淆变量**：异构配置偏离论文的单模型受控设置，增益不能纯粹归因于编排本身。务必保留单模型基线臂做对照。
- **成本核算**：`transcript.jsonl` 现含每角色 `model` 字段，按角色 × 模型聚合 token 才能准确算异构成本。
- **格式兼容**：不同模型的指令遵循能力不同，`MULTIAGENT_STRICT_FORMAT` 可能需要按 helper 模型调整（原代码对 muse/glimmer 自动加严格格式约束）。
- **判题不变**：判题仍本地执行隐藏测试，与模型无关。

## 状态

- [x] 补丁生成并验证可干净应用（`git apply --check` 通过）
- [ ] 在服务器上跑 baseline vs strong-lead 对照（待全量复现完成后）