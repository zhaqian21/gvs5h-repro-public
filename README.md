# GVS5H 复现与改进

GVS5H 的**复现与改进优化**工作仓库。基于 [slee-persis/GVS5H](https://github.com/slee-persis/GVS5H)
（论文 [arXiv:2608.26480](https://arxiv.org/abs/2608.26480)），管理本地复现实验与后续方法改进。

> GVS5H 核心：ledger-based zero-shot self-orchestration —— 同一模型的多个全新上下文角色
> （lead 主代理 + helper 助手）通过共享文件系统（plan / notes / solution）协作解题。
> 论文 headline：Qwen3.8-27B-FP8 在 LiveCodeBench Hard 100 题上 single 66.8% → manager 92.4%。

## 仓库结构

```
codebase/                          # 上游 GVS5H 脚手架与复现改动（MIT）
  ├── v2-current/escalation/       # 当前脚手架：run_bench / multiagent / orchestrator
  ├── v1-be9dfa2/                  # 旧版脚手架
  └── livecodebench/               # LiveCodeBench fork（数据集 + 判题）
repro/                             # 复现脚本
  └── campaign_q38_repro.sh        # 改造后的 27B-FP8 headline 复现 campaign
improvements/                      # 方法改进（补丁 + 设计文档）
  └── 01-heterogeneous-models/     # 异构 lead/helper 模型
docs/                              # 部署与实验记录
  └── DEPLOYMENT.md                # 服务器 / vLLM / 冒烟结果
```

## 复现状态

| 阶段 | 状态 | 结果 |
|---|---|---|
| 环境部署（单卡 H20 + vLLM Qwen3.8-27B-FP8） | ✅ 完成 | 256k 上下文，fp8 KV，thinking 默认开 |
| 冒烟测试（3 题 × 2 引擎） | ✅ 通过 | single **66.7%** (2/3) / manager **100%** (3/3) |
| 全量复现（100 题 × 5 pass × 2 引擎） | ⏳ 待启动 | 预计 3.5–5 天，对照论文 66.8 / 92.4 |

冒烟中 manager 做对了 single 失败的 arc196_b，微型验证了论文核心主张。详见 [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md)。

## 改进路线图

- [x] **01 异构 lead/helper 模型**：补丁已就绪（`improvements/01-heterogeneous-models/`），支持 lead 与 helper 用不同模型/后端
- [ ] 全量复现完成后，跑 baseline vs strong-lead 对照
- [ ] 其他候选：worker 并发化、笔记压缩策略、判题反馈增强

任务跟踪见仓库 [Issues](https://github.com/zhaqian21/gvs5h-repro-public/issues)。

## 快速开始

在仓库根目录填写本地权重目录，启动默认监听回环地址的 vLLM 服务。

~~~bash
export QWEN38_MODEL=/path/to/Qwen3.8-27B-FP8
bash repro/smoke-tests/start_vllm_q38.sh
~~~

服务就绪后，在另一个终端从仓库根目录运行冒烟测试。完整参数见 [部署说明](docs/DEPLOYMENT.md)。

~~~bash
bash repro/smoke-tests/run_smoke_single.sh
bash repro/smoke-tests/run_smoke.sh
~~~

异构 lead/helper 选择和 LongCat 流式接入已包含在当前代码中。[冒烟脚本和结果摘要](repro/smoke-tests/README.md)

## 许可

导入的 `codebase/` 遵循上游 MIT 许可（见 [LICENSE](LICENSE)）；上游论文/数据为 CC BY 4.0
（[LICENSE-CC-BY-4.0](LICENSE-CC-BY-4.0)）。归属与路径许可见 [NOTICE.md](NOTICE.md)。
本仓库新增的复现脚本与改进代码同样以 MIT 发布。