# Next Steps: FreeToken as llama-swap substitute

## Current State (2026-09-02 14:12 verified)
- `ft` installed: `freetoken 0.1.2+ge05cff83a` at `~/.freetoken/venv/bin/ft` (`~/.local/bin/ft`).
- **Local LLM:** `llama-swap` on `:8080` ACTIVE (see `ai/MEMORY.md`), `llama-router` on `:8085` disabled — no conflict, `-ngl 24` fixes 6GB OOM.
- Models GGUF in `/mnt/data/models`: `Qwen2.5-7B-Instruct-Q4_K_M.gguf` (tool_calls OK with --jinja), `Qwen2.5-Coder-7B-Instruct-Q4_K_M.gguf` (XML fallback, avoid for pi), `nomic-embed-text-v1.5-Q8_0.gguf`.
- GPU: `RTX 3050 6GB` driver 610.57, `4800 MiB` with one 7B loaded, `pi` default `llama-swap/qwen2.5-7b-instruct` tool-calling verified.
- `ft serve --model *.gguf` only supports `gemma4` — Qwen gguf still via llama-swap, not ft.

## To Replace llama-swap

### Option A: Keep Qwen Coder (recommended for pi/opencode)
Use FreeToken with safetensors (not gguf):
```bash
export HF_TOKEN=hf_...
~/.freetoken/venv/bin/ft serve --model Qwen/Qwen2.5-Coder-7B-Instruct --port 1919 --host 127.0.0.1
# or 30B MoE (smarter, still fits 6GB hybrid):
~/.freetoken/venv/bin/ft serve --model Qwen/Qwen3-30B-A3B --port 1919
```
- Downloads ~15G (7B) / ~30G (30B) + FTW cache. Stop `llama-server` first (`pkill llama-server`).
- Endpoint for pi/opencode: `http://127.0.0.1:1919/v1` (OpenAI compat, same as llama-swap 8081/v1). Set in `pi`/`opencode` config.

### Option B: Use Gemma GGUF (only if you want gguf on FreeToken)
```bash
~/.freetoken/venv/bin/ft serve --model /path/to/gemma-3-...gguf --port 1919
```
Not ideal for coding.

## Desktop
```bash
pkill -f freetoken-desktop; DISPLAY=:0 FREETOKEN_FT_BIN=~/.freetoken/venv/bin/ft WEBKIT_DISABLE_COMPOSITING_MODE=1 WEBKIT_DISABLE_DMABUF_RENDERER=1 freetoken-desktop &
```
Re-login once to apply `~/.config/environment.d/50-freetoken.conf`.

## Verify
```bash
nvidia-smi  # should be ~300-400M used, not 5G
~/.freetoken/venv/bin/ft bench bw  # expect hybrid, not OOM
curl http://127.0.0.1:1919/v1/models
```

## Decision
- 7B Qwen for coding keep `llama-swap` (4.4G gguf, fastest). 
- For FreeToken substitute, use **Option A safetensors** with HF_TOKEN.
