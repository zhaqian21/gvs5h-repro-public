# 实验记录

## 实验 01：异构 lead/helper 模型三臂冒烟（2026-11-10）

**目的**：验证异构模型补丁（lead 与 helper 用不同模型）管线可行，并初步对比单模型基线。

**设置**：LiveCodeBench release_v6 的 3 题（arc196_a/b/c，固定 id），manager 引擎，`MAX_ITERS=10`，`MAX_TASKS=12`，输出上限 128k。

**模型**：
- 本地 Qwen3.8-27B-FP8（24 号机 GPU 0，vLLM :18010，256k 上下文，fp8 KV，thinking 开）
- DeepSeek-V4.1-Flash（API `deepseek-flash`，经 `ESCALATION_DASHSCOPE_BASE` 路由）

### 结果

| 臂 | lead | helper | pass@1 | 墙钟耗时 | DS API 成本* |
|---|---|---|---|---|---|
| A | 27B | 27B | 100% (3/3) | 134 min | ¥0（本地） |
| B | DS | DS | 100% (3/3) | 22 min | ¥2.42 |
| C | DS | 27B | 100% (3/3) | 44.8 min | ¥1.41 + 本地 27B |

*按高峰价（输入 ¥2 / 输出 ¥9 每百万 token）估算；空闲时段更低。

### 路由验证（C 臂 transcript）

| 角色 | 实际模型 |
|---|---|
| primary_plan / primary_manage（lead） | dashscope:deepseek-flash |
| ideation / worker（helper） | groq:q38（本地 27B） |

补丁按设计工作：lead 角色走 DS，helper 角色走 27B。

### 发现

1. **准确率天花板**：三臂均 100%。这 3 题对两个模型都太容易，无法区分准确率优劣；冒烟仅验证管线跑通。
2. **速度差异显著**：C（44.8min）比纯 27B 的 A（134min）快约 3×。A 中 27B 自己做管理决策时长思考（单题达 125min），C 用快速 DS 当 lead 砍掉这部分慢思考。
3. **成本权衡**：C 的 API 成本（¥1.41）低于纯 DS 的 B（¥2.42，仅 lead 调 API），又比纯本地 A 快得多——异构在速度↔成本上是折中。
4. **DS Flash 输出短**：B 最长一题 12.6min，A 最长 125min；Flash 的短输出是提速主因。

### 局限与下一步

- 样本太小且太易（天花板效应），准确率对比无区分度。
- 下一步需**有区分度的样本**（baseline single 失败的题，或 20-30 题中等样本 / 全量 100）才能比较异构 vs 单模型的准确率增益。

### 复现命令

```bash
# 在仓库根目录运行
bash repro/smoke-tests/run_smoke_parallel.sh   # B、C 并行；A 见 runs/smoke/
# 结果：runs/smoke-hetero/results/{B_ds,C_hetero}.json
```

## 实验 02：Qwen3.5-9B 单模型烟测（2026-11-10）

**目的**：在三臂全 100% 的天花板之外，换一个更弱的模型（Qwen3.5-9B）看同一 3 题能否产生区分度，并观察 manager 协同在弱模型上是否仍然有效。

**设置**：与实验 01 相同的 LiveCodeBench release_v6 3 题（arc196_a/b/c，固定 id）。single 与 manager 两个引擎**并行**跑（各 `--parallel 2`），互不共享 checkpoint。

**模型**：本地 Qwen3.5-9B（24 号机 GPU 0，vLLM :18010，`--max-model-len 262144`，thinking 开，`--served-model-name q35-9b`；引擎内路由名 `groq:q35-9b`）。

**输出上限**：single 250k（`ESCALATION_CLOUD_MAX_TOKENS=250000`），manager 128k。

### 结果

| 臂 | pass@1 | arc196_b | arc196_c | arc196_a | 墙钟耗时 |
|---|---|---|---|---|---|
| single | **0.0%** (0/3) | ok，未过（撞 250k 上限） | truncated | truncated | 2h36m（16:14→18:50） |
| manager | **0.0%** (0/3) | ok，未过（正常停止） | truncated | ok，未过 | 3h56m（16:14→20:10） |

- vLLM 全程累计生成 **2,540,216 tokens**，prompt 仅 47,758 tokens。
- single 单题输出字符数：arc196_c 570,051、arc196_b 804,014，均为 `finish=length`。
- GPU0（9B vLLM）运行期间 util 100%、显存约 87.4 GB。

### 发现

1. **下限效应**：两臂均 0/3。9B 在这 3 道 hard 题上不具备可解性，manager 协同也没能救回来（公共样例自测始终 0/1）。
2. **输出失控**：thinking 开启后 9B 极度啰嗦，几乎所有调用都撞 token 上限被截断；single 的 3 题全部 `finish=length`，这是耗时远超 27B 的直接原因。
3. **manager 行为异常**：arc196_b 出现"重复下发同一任务、两轮无进展后停止"；arc196_c 有 worker 调用被截断后向 manager 汇报。
4. **样本区分度**：与实验 01（27B 三臂 100%）相比，同一 3 题在 9B 上直接落到 0%，说明样本本身不是"送分题"；但两臂同时触底，准确率上仍无有效信号。
5. **参考**：上游仓库归档的 9B 旧数据（`runs/q9-reasoning-on-archived/infra_contaminated_archive/q9_multiagent.json`，100 题、标记 infra 污染）manager pass@1 约 37%，与本次 3 题全灭不矛盾——样本难度与题量不同。

### 局限与下一步

- 3 题 + 双触底，只能说明 9B 不适合该难度带，不能用于评价 manager 增益。
- 若要在弱模型上观察协同效果，需要**中等难度**样本（例如 27B single 可解、9B single 失败的题），而不是当前 hard 集合。
- 9B 的长输出问题可考虑关闭 thinking 或收紧输出上限，但会改变实验语义，需单独设臂。

### 复现命令

```bash
# 在仓库根目录运行
bash repro/smoke-tests/start_vllm_q35_9b.sh    # 启动 9B vLLM (:18010)
bash repro/smoke-tests/run_smoke_9b.sh         # single + manager 并行
# 结果：runs/smoke-9b/results/{9b_single,9b_manager}.json
# 日志：logs/smoke_9b.log、logs/9b_single.log、logs/9b_manager.log
```