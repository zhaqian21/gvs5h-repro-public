# GVS5H smoke-test scripts

Run these scripts with Bash. They detect the checkout automatically. Set GVS5H_ROOT for a different checkout, GVS5H_LOG_DIR to change the log directory, and HF_HOME to change the dataset cache.

Set QWEN38_MODEL or QWEN35_9B_MODEL to the appropriate local model directory before running a vLLM launcher. VLLM_BIN can override the vLLM executable. The default serving address is localhost.

The heterogeneous and LongCat scripts use DASHSCOPE_API_KEY and LONGCAT_API_KEY respectively. Set DASHSCOPE_ENV_FILE or LONGCAT_ENV_FILE only if you load credentials from a file outside the checkout. The probe and reporting scripts expect workspace files produced by the corresponding run.

## Experiment summary

| Smoke test | Passed |
|---|---|
| Qwen single-agent and multi-agent | 2/3 and 3/3 |
| Qwen 9B single-agent and multi-agent | 0/3 and 0/3 |
| DeepSeek-only and DeepSeek/Qwen | 3/3 and 3/3 |
| LongCat/Qwen | 3/3 on regraded saved answers after an early stop |
| LongCat non-streaming diagnostic | Recorded HTTP 502 errors |

Original transcripts and logs are held in the private archive. The upstream baseline was slee-persis/GVS5H at 40ec3d29a809e0c0a64a4f360fae3085d8f2464f.
