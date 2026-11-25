# 部署与复现记录

## 本地环境

原始复现实验使用一张 NVIDIA H20 96 GB。以下命令在仓库根目录运行。准备模型权重后，将 QWEN38_MODEL 设置为本机的模型目录。

## 模型服务（vLLM）

权重：`$QWEN38_MODEL`（29G，66 分片，经 hf-mirror 下载；ModelScope 实测更快 ~36MB/s）。

启动脚本 `repro/smoke-tests/start_vllm_q38.sh`：

```bash
CUDA_VISIBLE_DEVICES=0 vllm serve "$QWEN38_MODEL" \
  --served-model-name q38 --host 127.0.0.1 --port 18010 \
  --max-model-len 262144 --kv-cache-dtype fp8 --max-num-seqs 12 \
  --gpu-memory-utilization 0.90 --reasoning-parser qwen3 \
  --no-enable-prefix-caching --enable-auto-tool-choice --tool-call-parser qwen3_xml \
  --default-chat-template-kwargs '{"enable_thinking": true}'
```

实测：KV cache 池 **1,746,093 tokens**，256k 满长请求并发 **6.66×**；GPU 0 占用 ~86GB。

### 部署踩坑

1. **ninja 缺失**：FlashInfer JIT 编译采样内核需要 ninja + nvcc。装 ninja 二进制到 `~/.local/bin`，
   启动环境加 `PATH=~/.local/bin:/usr/local/cuda/bin:$PATH CUDA_HOME=/usr/local/cuda`。
2. **thinking 默认关闭**：vLLM 默认不启用 Qwen 思考；必须加 `--default-chat-template-kwargs '{"enable_thinking": true}'`，
   否则 reasoning 为空、压低基线。验证：短请求返回 `reasoning` 字段非空。
3. **依赖镜像**：可通过 HF_ENDPOINT 和 UV_DEFAULT_INDEX 切换数据集与 Python 依赖镜像。

## 基准运行环境

- 仓库：`当前仓库根目录`
- 数据集：HF `livecodebench/code_generation_lite` `release_v6`（1055 题），经 `HF_ENDPOINT=https://hf-mirror.com` 下载
- 选题：`escalation/lcb100_hardest_v6.json` 固定 100 个 hard 题 id
- 关键环境变量（指向本地端点）：
  ```bash
  ESCALATION_OPENAI_BASE=http://127.0.0.1:18010/v1/chat/completions
  GROQ_API_KEY=dummy ESCALATION_GROQ_REASONING="" MULTIAGENT_MODEL=groq:q38
  LCB_RELEASE=release_v6 MULTIAGENT_MAX_ITERS=10 MULTIAGENT_MAX_TASKS=12 ESCALATION_CLOUD_TIMEOUT=14400
  ```
- 判题全本地（隐藏测试多进程执行），无 API 需求。

## 冒烟结果（3 题 × 2 引擎，1 pass）

| 引擎 | pass@1 | 逐题 | 总生成 token |
|---|---|---|---|
| single | **66.7%** (2/3) | arc196_a✅ b❌ c✅ | 438,852 |
| multiagent | **100%** (3/3) | a✅ b✅ c✅ | 742,724（18 调用） |

- manager 做对了 single 失败的 **arc196_b** —— 微型验证论文主张。
- transcript 角色齐全：`primary_plan` / `ideation` / `primary_manage` / `worker:*`。
- 单流解码 ~73 tok/s；每题平均 single ~146k / manager ~248k token。

## 全量复现

```bash
mkdir -p logs
nohup bash repro/campaign_q38_repro.sh > logs/campaign.log 2>&1 < /dev/null &
```

- 5 pass × {single(cap 250k, par 12), multiagent(cap 128k, par 24)}
- 每 pass 带 `BENCH_CHECKPOINT` 断点续跑 + `[skip done]` 兜底
- 结果：`runs/q38-repro-5pass/results/q38_{single,multiagent}_p{1..5}.json`
- 汇总 5 pass 均值±SD，对照论文 single 66.8 / manager 92.4（±1SD 内即复现成功）
- 预计耗时 **3.5–5 天**（单卡 H20）