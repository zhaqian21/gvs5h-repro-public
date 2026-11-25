#!/usr/bin/env bash
: "${QWEN38_MODEL:?Set QWEN38_MODEL to the model directory}"
export PATH=$HOME/.local/bin:/usr/local/cuda/bin:$PATH
export CUDA_HOME=/usr/local/cuda
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
exec "${VLLM_BIN:-vllm}" serve "$QWEN38_MODEL" \
  --served-model-name q38 --host 127.0.0.1 --port 18010 \
  --max-model-len 262144 --kv-cache-dtype fp8 --max-num-seqs 12 \
  --gpu-memory-utilization 0.90 --reasoning-parser qwen3 \
  --no-enable-prefix-caching --enable-auto-tool-choice --tool-call-parser qwen3_xml \
  --default-chat-template-kwargs "{\"enable_thinking\": true}"
