from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path

from .config import MODEL_CONFIG, REPO_ROOT

TOOL_CALL_MARKERS = ("<tool_calls>", "<invoke")


def default_model() -> str:
    if not MODEL_CONFIG.exists():
        return ""
    try:
        cfg = json.loads(MODEL_CONFIG.read_text())
    except (json.JSONDecodeError, OSError):
        return ""
    return cfg.get("model", "")


# Free-tier OpenCode Zen models, most capable first (per provider descriptions:
# largest/agentic reasoning first, fast tiers after). llm_complete falls down
# this chain so a failing completion moves to the next model instead of
# retrying the same one.
FREE_MODEL_CHAIN: tuple[str, ...] = (
    "nemotron-3-ultra-free",        # largest Nemotron: max reasoning & agent accuracy
    "deepseek-v4-flash-free",       # DeepSeek V4 Flash: enhanced agentic capabilities
    "nemotron-3.5-lightning-free",  # fast Nemotron MoE: reliable agentic tasks
)


def _model_chain(model: str, limit: int) -> list[str]:
    """Attempt order: an explicitly requested `model` first, then the free
    model chain (most capable first), deduped and capped at `limit`.
    Free-tier values are NOT absorbed — the requested model always leads,
    matching the interactive session's behavior."""
    chain: list[str] = []
    if model:
        chain.append(model)
    for candidate in FREE_MODEL_CHAIN:
        if candidate not in chain:
            chain.append(candidate)
        if len(chain) >= limit:
            break
    return chain[:limit]


def _omp_binary() -> str | None:
    return shutil.which("omp")


def _extract_text(ndjson: str) -> str | None:
    """Pull the final assistant text out of the omp `--mode json` event stream."""
    text: list[str] = []
    for line in ndjson.splitlines():
        line = line.strip()
        if not line:
            continue
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == "message_end":
            content = ev.get("message", {}).get("content", [])
            text = [c.get("text", "") for c in content if c.get("type") == "text" and c.get("text")]
    if text:
        return "\n".join(text).strip()
    return None


def _stop_reason(ndjson: str) -> str:
    reason = ""
    for line in ndjson.splitlines():
        try:
            ev = json.loads(line)
        except json.JSONDecodeError:
            continue
        if ev.get("type") == "message_end":
            r = ev.get("message", {}).get("stopReason")
            if r:
                reason = r
    return f" (stopReason={reason})" if reason else ""


def llm_complete(prompt: str, system: str = "", model: str = "", timeout: int = 300, max_attempts: int = 4) -> str | None:
    """One-shot completion routed through the oh-my-pi harness (`omp -p --mode json`).

    Mirrors the interactive TUI session as closely as possible: runs in the
    repo root, tools enabled (auto-approved, non-interactive), repo rules and
    skills loaded. The model fetches its own context with the read tool
    instead of receiving giant pasted prompts, and can write files / run
    tests itself.

    Returns the model's final text, or None when omp is unavailable or fails.
    The per-attempt model walks the free-model chain (FREE_MODEL_CHAIN, most
    capable first): each model gets exactly one attempt — attempt 1 uses the
    requested model (or the configured default), then the chain, never
    repeating a model.
    """
    omp = _omp_binary()
    if omp is None:
        print("[LLM] omp binary not found on PATH — no oh-my-pi model transport.", file=sys.stderr)
        return None

    base_cmd = [
        omp, "-p", prompt, "--mode", "json",
        "--auto-approve",
        "--cwd", str(REPO_ROOT),
        "--max-time", str(timeout),
    ]
    if system:
        base_cmd += ["--system-prompt", system]

    for i, m in enumerate(_model_chain(model or default_model(), max_attempts), 1):
        cmd = base_cmd[:] + ["--model", m]
        print(f"[LLM] omp -p attempt {i} (model={m})", file=sys.stderr)
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 60, cwd=str(REPO_ROOT), check=False)
        except subprocess.TimeoutExpired:
            print(f"[LLM] omp timed out after {timeout}s", file=sys.stderr)
            return None
        if proc.returncode != 0:
            tail = [l for l in proc.stderr.strip().splitlines() if l.strip()][-3:]
            print(f"[LLM] omp failed (model={m}): {' | '.join(tail) or 'no stderr'}", file=sys.stderr)
            continue
        result = _extract_text(proc.stdout)
        if not result:
            print(f"[LLM] omp returned no text (model={m}{_stop_reason(proc.stdout)}); retrying", file=sys.stderr)
            continue
        if any(marker in result for marker in TOOL_CALL_MARKERS):
            print(f"[LLM] attempt {i}: response contains raw tool-call markers (model={m}); trying next model", file=sys.stderr)
            continue
        return result
    print("[LLM] no model produced usable text — giving up.", file=sys.stderr)
    return None


def generate_spec_with_ai(domain: str, action: str, prompt: str) -> str | None:
    root_spec = REPO_ROOT / "SPEC.md"
    arch_blueprint = root_spec.read_text() if root_spec.exists() else ""

    system_prompt = (
        "You are a spec writer for a software project. "
        "Generate a structured feature specification in markdown.\n\n"
        "Here is the project's architectural blueprint:\n"
        + arch_blueprint +
        "\n\nUse this exact format for the feature spec:\n"
        "  # <Action> — <Domain> Feature\n"
        "  ## Overview\n"
        "  <description>\n"
        "  ## Input / Output\n"
        "  | Direction | Format | Description |\n"
        "  |-----------|--------|-------------|\n"
        "  | Input | <...> | <...> |\n"
        "  | Output | <...> | <...> |\n"
        "  ## Business Logic Constraints\n"
        "  * <rules>\n"
        "  ## Error Cases\n"
        "  | Condition | Error | Message |\n"
        "  |-----------|-------|-------------|\n"
        "  | <when> | <type> | <message> |\n"
        "  ## Dependencies\n"
        "  * <libraries, config>\n"
        "  ## Code Standards\n"
        "  All code must use type annotations per PEP 484.\n\n"
        "Output ONLY the markdown spec — no preamble, no explanation."
    )
    return llm_complete(
        f"Feature: {action}\nDomain: {domain or '(none)'}\n\nDescription:\n{prompt}",
        system=system_prompt,
    )
