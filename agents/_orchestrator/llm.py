from __future__ import annotations

import json
import shutil
import subprocess
import sys
import tempfile
import uuid
from pathlib import Path

from .config import MODEL_CONFIG, REPO_ROOT

TOOL_CALL_MARKERS = ("<tool_calls>", "<invoke", "tool_call", '"name":"bash"', '"name":"read"')

SCRATCH_DIR = Path(tempfile.gettempdir()) / "omp-completions"


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
    """Attempt order: an explicitly requested non-chain `model` first (e.g. a
    paid model via `--model`), then the free model chain (most capable first),
    deduped and capped at `limit`. Free-tier values from model_config are
    absorbed into the chain's capability order instead of leading it."""
    chain: list[str] = []
    if model and model not in FREE_MODEL_CHAIN:
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


def llm_complete(prompt: str, system: str = "", model: str = "", timeout: int = 300, max_attempts: int = 4) -> str | None:
    """One-shot completion routed through the oh-my-pi harness (`omp -p --mode json`).

    Returns the model's text output, or None when omp is unavailable or fails.
    When `system` is given, the response must echo a per-call verification token
    that was injected into the system prompt; attempts whose flags were not
    applied (harness print-mode bug) are detected and retried.

    The per-attempt model walks the free-model chain (FREE_MODEL_CHAIN, most
    capable first): each model gets exactly one attempt — attempt 1 uses the
    first model, attempt 2 the second, and so on, never repeating a model.
    `model`, when given, overrides the configured default — a non-free value
    (e.g. `--model claude-sonnet-4-5`) leads the attempts, free-tier values
    are absorbed into the chain.
    """
    omp = _omp_binary()
    if omp is None:
        print("[LLM] omp binary not found on PATH — no oh-my-pi model transport.", file=sys.stderr)
        return None

    token = ""
    if system:
        token = f"[VERIFY_{uuid.uuid4().hex[:8]}]"
        system = f"{system}\n\nBegin your response with the exact token {token} on the first line, followed by a newline. Then give ONLY the requested output — no greetings, no preamble, no tool calls."
    base_cmd = [
        omp, "-p", prompt, "--mode", "json",
        "--no-tools", "--no-session", "--no-extensions", "--no-skills", "--no-rules", "--no-lsp",
        "--max-time", str(timeout),
    ]
    if system:
        base_cmd += ["--system-prompt", system]
    SCRATCH_DIR.mkdir(parents=True, exist_ok=True)

    for i, m in enumerate(_model_chain(model or default_model(), max_attempts), 1):
        cmd = base_cmd[:] + ["--model", m]
        print(f"[LLM] omp -p attempt {i} (model={m})", file=sys.stderr)
        try:
            proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 60, cwd=str(SCRATCH_DIR), check=False)
        except subprocess.TimeoutExpired:
            print(f"[LLM] omp timed out after {timeout}s", file=sys.stderr)
            return None
        if proc.returncode != 0:
            tail = [l for l in proc.stderr.strip().splitlines() if l.strip()][-3:]
            print(f"[LLM] omp failed (model={m}): {' | '.join(tail) or 'no stderr'}", file=sys.stderr)
            continue
        result = _extract_text(proc.stdout)
        if not result:
            print(f"[LLM] omp returned no text (model={m}); retrying", file=sys.stderr)
            continue
        if not token:
            return result
        stripped = result.lstrip()
        if stripped.startswith(token):
            rest = stripped[len(token):].lstrip("\n").strip() or None
            if rest and not any(marker in rest for marker in TOOL_CALL_MARKERS):
                return rest
        print(f"[LLM] attempt {i}: verification failed (model={m}); trying next model", file=sys.stderr)
    print("[LLM] verification never passed — giving up.", file=sys.stderr)
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
