# AI Stack Memory — 2026-09-02

## Current Working State (verified)
- **GPU:** RTX 3050 6GB (610.57), 4800 MiB used when one 7B Q4 loaded, 993 MiB free
- **llama-swap :8080** `enabled+active` — router for local LLMs (pi `llama-swap` provider)
  - Config: `ai/config/llama-swap/config-host.yaml` — `healthCheckTimeout 30`, `default_model: qwen2.5-coder-7b-instruct`
  - Models (all `Q4_K_M`, `-ngl 24`, `-c 8192`, `--jinja --flash-attn on`):
    - `qwen2.5-7b-instruct` → `8083` → `/mnt/data/models/Qwen2.5-7B-Instruct-Q4_K_M.gguf`
    - `qwen2.5-coder-7b-instruct` → `8081` → `/mnt/data/models/Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf`
    - `nomic-embed-text` → `8082` → `ai/models/nomic-embed-text-v1.5-Q8_0.gguf` (`--embedding`)
  - Swaps models (only one 7B fits in 6GB VRAM at a time, `ttl:0` keeps last, auto-unloads on switch)
  - UI: `http://127.0.0.1:8080/ui` (root `/` redirects 302→/ui), API: `http://127.0.0.1:8080/v1`
  - Service: `systemctl --user status llama-swap`, logs: `journalctl --user -u llama-swap -f`
- **llama-router :8085** `disabled+inactive` — former `--models-dir /mnt/data/models` on `:8080`, now moved to `:8085 -ngl 24` and stopped to avoid port/VRAM conflict. Start if needed: `systemctl --user start llama-router`.
- **opencode local-ai** `common/.config/opencode/opencode.jsonc` → `baseURL http://localhost:8080/v1`, models: `qwen2.5-coder-7b-instruct`, `qwen2.5-7b-instruct`, `nomic-embed-text`
- **pi** `~/.pi/agent/settings.json` → `defaultProvider: llama-swap`, `defaultModel: qwen2.5-7b-instruct`, `thinking: high`
  - `pi --list-models` shows `llama-swap qwen2.5-coder-7b-instruct` (catalog), but custom id `qwen2.5-7b-instruct` works.

## Tool Calling
- `qwen2.5-7b-instruct` + `--jinja` → **proper OpenAI `tool_calls`** (`finish_reason: tool_calls`, `tool_calls:[{name,arguments}]`) — works with `pi` (`pi --provider llama-swap --model qwen2.5-7b-instruct -p "list files"` verified).
- `qwen2.5-coder-7b-instruct` + `--jinja` → **XML `<function_call>` in content** (`finish_reason: stop`), still triggers `pi bash` but unreliable — avoid for agent tool loops. Use `instruct` for pi.
- Without `--jinja` both emitted raw XML/json in content — fixed 2026-09-02.

## OOM Fix
- 6GB cannot hold `Qwen 7B Q4` with `-ngl 35` (needs 4168 MiB alloc → `cudaMalloc failed`). Lowered to `-ngl 24` (≈3GB per model) allows one at a time. Do not raise.

## Previous Failure Modes (resolved)
- `model 'qwen2.5-coder-7b-instruct' not found` — was `llama-server --models-dir` on `:8080` exposing `Qwen2.5-Coder-7B-Instruct-Q4_K_M` (capitalized), while `opencode` asked lowercase and `llama-swap` was dead on same port. Fixed by enabling swap on `:8080`, moving router to `:8085`.
- `http://127.0.0.1:8080/ server unavailable` — root is 302 redirect, UI is `/ui`. Use `/ui`.

## FreeToken
- `ft 0.1.2` at `~/.freetoken/venv/bin/ft`, models via safetensors on `:1919` (`Qwen/Qwen2.5-Coder-7B-Instruct` etc via `03-download-freetoken.sh`). Not yet needed — GGUF `7b-instruct` suffices for simple agent tasks. For proper coder tool-calling, serve freetoken safetensors instead of GGUF coder.

## Commands
```bash
systemctl --user start|stop|status llama-swap  # :8080
systemctl --user start|stop llama-router       # :8085 (disabled)
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1:8080/v1/chat/completions -d '{"model":"qwen2.5-7b-instruct","messages":[{"role":"user","content":"hi"}],"tools":[...]}'
pi --provider llama-swap --model qwen2.5-7b-instruct -p "list files"
```
