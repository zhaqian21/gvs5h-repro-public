#!/usr/bin/env bash
: "${QWEN35_9B_MODEL:?Set QWEN35_9B_MODEL to the model directory}"
export PATH=$HOME/.local/bin:/usr/local/cuda/bin:$PATH
export CUDA_HOME=/usr/local/cuda
export CUDA_VISIBLE_DEVICES="${CUDA_VISIBLE_DEVICES:-0}"
exec "${VLLM_BIN:-vllm}" serve "$QWEN35_9B_MODEL" \
  --served-model-name q35-9b --host 127.0.0.1 --port 18010 \
  --max-model-len 262144 --max-num-seqs 16 --gpu-memory-utilization 0.90 \
  --reasoning-parser qwen3 --no-enable-prefix-caching \
  --default-chat-template-kwargs "{\"enable_thinking\": true}"
