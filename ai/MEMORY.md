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

## FreeToken (2026-09-02 20:05 update)
- `ft 0.1.2` at `~/.freetoken/venv/bin/ft` (`~/.local/bin/ft`), `ft daemon :1900` running
- **WRONG model removed 2026-09-02 20:00:** `Qwen/Qwen2.5-Coder-7B-Instruct` safetensors 15G at `/mnt/data/models/hf/Qwen2.5-Coder-7B-Instruct` — dense bf16 OOMs on 6GB even `--memory-ratio 0.5` (`4.33G+1.02G → 955M free, needs 5.66G`) — acid test failed. Deleted: `rm -rf /mnt/data/models/hf/Qwen2.5-Coder-7B-Instruct` (now 0, `df /mnt/data 37G used`). Temp scripts/logs cleaned: `/tmp/*hf* /tmp/*poll* ai/data/freetoken*.log`.
- **CORRECT for 6GB:** `Qwen/Qwen3-30B-A3B` MoE 30G (only ~3B active, `hybrid` offload fits 6GB) — not yet downloaded. New script: `ai/04-get-freetoken-30b.sh` (resumable, `HF_TOKEN`, `max-workers 2`). Run: `bash ai/04-get-freetoken-30b.sh` or `nohup bash ai/04-get-freetoken-30b.sh > ai/data/freetoken-30b.log 2>&1 &` → serve: `~/.freetoken/venv/bin/ft serve --model Qwen/Qwen3-30B-A3B --port 1919 --host 127.0.0.1 --tool-call-parser qwen25 --memory-ratio 0.9`
- **Keep for llama-swap:** GGUF `Qwen2.5-7B-Instruct/Coder Q4_K_M 4.4G` still correct for `:8080` (quantized, `-ngl24` fits). `ft` gguf only supports `gemma4`, so GGUF stays on llama-swap.
- Desktop: `pkill -f freetoken-desktop; DISPLAY=:0 FREETOKEN_FT_BIN=~/.freetoken/venv/bin/ft WEBKIT_DISABLE_COMPOSITING_MODE=1 WEBKIT_DISABLE_DMABUF_RENDERER=1 freetoken-desktop &` (needs re-login for `50-freetoken.conf`; 7B will OOM, wait for 30B).

## Resume Tomorrow
```bash
# 1. check llama-swap still active (acid test passed)
systemctl --user status llama-swap; curl http://127.0.0.1:8080/v1/models
pi --provider llama-swap --model qwen2.5-7b-instruct -p "create /tmp/acidtest.txt with hello, then list it"
# 2. download correct freetoken model (30G, resumable)
bash ai/04-get-freetoken-30b.sh
# or nohup: nohup bash ai/04-get-freetoken-30b.sh > ai/data/freetoken-30b.log 2>&1 &; tail -f ai/data/freetoken-30b.log
# progress: bash /tmp/show_progress.sh (or while true; do bash /tmp/show_progress.sh; sleep 5; done)
# 3. serve when done (stop llama-swap first to free VRAM)
systemctl --user stop llama-swap
~/.freetoken/venv/bin/ft serve --model Qwen/Qwen3-30B-A3B --port 1919 --host 127.0.0.1 --tool-call-parser qwen25
curl http://127.0.0.1:1919/v1/models
```

## Project Local AI Usage (2026-09-02 20:15, disabled 2026-09-05)
- **make-videos** (`typescript/.../make-videos`) — **NOT using local now** (rendiv + edge-tts). Could use `local-ai :8080` (`qwen2.5-7b-instruct`) to generate `videos/<id>/spec.md` + `vo/*.txt` offline. No `localhost` calls yet; add `generate-spec` opencode skill if wanted.
- **rustjiin-japan** (`rust/.../rustjiin-japan`) — **CORRECT, keep as-is (still on :8080 directly, not via opencode/pi):**
  - `src/features/llm/controller.rs` → `http://localhost:8080/v1/chat/completions` `model: qwen2.5-7b-instruct` (Itachi Japanese teaching)
  - `src/features/llm/memory.rs` → `http://localhost:8080/v1/embeddings` `nomic-embed-text` (rusqlite vector memory)
  - Designed for README's `LM Studio Q4_K_M 5GB` on 16GB CPU, matches our `llama-swap :8080` Q4 setup. **Note:** `rustjiin` still calls `:8080` directly — not via `opencode`/`pi` provider, so disabled there doesn't affect it.
- **pi coding agent** — **DISABLED 2026-09-05:** `7B Q4 useless for agent` — `7b-instruct` *does* `tool_calls` for simple `ls` but weak on multi-step code; `coder` only `XML`. Removed from `pi` (`~/.pi/agent/settings.json` → `opencode/muse-spark-1.2-contributor-free`) and `opencode` (`local-ai` models → `{}`). `llama-swap :8080` still running for `rustjiin` & manual `curl`, just not exposed as `pi`/`opencode` model. To re-enable: restore `opencode.jsonc` `local-ai` models and `pi` `defaultProvider: llama-swap`.

## Commands
```bash
systemctl --user start|stop|status llama-swap  # :8080
systemctl --user start|stop llama-router       # was :8085 (disabled) — port now used by realistic-vision sd-server, do NOT re-enable router on :8085
curl http://127.0.0.1:8080/v1/models
curl http://127.0.0.1:8080/v1/chat/completions -d '{"model":"qwen2.5-7b-instruct","messages":[{"role":"user","content":"hi"}],"tools":[...]}'
pi --provider llama-swap --model qwen2.5-7b-instruct -p "list files"
# freetoken correct:
bash ai/04-get-freetoken-30b.sh
# project checks:
grep -r "localhost:8080" ~/programs/rust/.../rustjiin-japan/src --include="*.rs"; cat ~/programs/typescript/.../make-videos/src/index.tsx | head

## Image generation (2026-10-11/12, RTX 3050 6GB)
- **Installer:** `ai/06-install-image-gen.sh` (idempotent) + step `17/17` in `install-debian.sh`. Builds `~/stable-diffusion.cpp` sd-server (`-DSD_CUDA=ON -DSD_SERVER_BUILD_FRONTEND=ON`), downloads 3 files to `/mnt/data/models`, merges config.
- **Models:** `sdxl-lightning` (:8084, `sdxl_lightning_4step.q8_0.gguf` 3.9G, `--backend vae=cpu` — weights live in RAM, slow) | `realistic-vision` (:8085, RV6 fp16 2G + mse VAE 320M, `--steps 25 --cfg-scale 5 --sampling-method dpm++2m --scheduler karras`, fits VRAM — the daily driver).
- **Gotchas (do not regress):** sd-server has NO `/health` → every image entry needs `checkEndpoint: /v1/models`; cold HDD load >30s → `healthCheckTimeout: 180`; OpenAI route takes ONLY `prompt/n/size` (`routes_openai.cpp`) → sampler/CFG/steps/negative are sd-server CLI defaults in `cmd`; Qwen ttls `0→300` (nothing is pinned on 6GB); full UI at `:8085`/`:8084` only while model loaded (embedded frontend needs Node+pnpm at build).
```
