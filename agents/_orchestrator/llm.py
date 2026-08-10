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
    if MODEL_CONFIG.exists():
        try:
            cfg = json.loads(MODEL_CONFIG.read_text())
            return cfg.get("model", "")
        except Exception:
            pass
    return ""


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

    `model` is passed to `omp --model` (fuzzy match); on failure the call is
    retried without it so the harness default model takes over.
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

    model_attempts: list[str] = [model, ""] if model else [""]
    for attempt in range(1, max_attempts + 1):
        for m in model_attempts:
            cmd = base_cmd[:]
            if m:
                cmd += ["--model", m]
            print(f"[LLM] omp -p attempt {attempt} (model={m or '<harness default>'})", file=sys.stderr)
            try:
                proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout + 60, cwd=str(SCRATCH_DIR))
            except subprocess.TimeoutExpired:
                print(f"[LLM] omp timed out after {timeout}s", file=sys.stderr)
                return None
            if proc.returncode != 0:
                tail = [l for l in proc.stderr.strip().splitlines() if l.strip()][-3:]
                print(f"[LLM] omp failed (model={m or '<harness default>'}): {' | '.join(tail) or 'no stderr'}", file=sys.stderr)
                continue
            result = _extract_text(proc.stdout)
            if not result:
                print(f"[LLM] omp returned no text (model={m or '<harness default>'}); retrying", file=sys.stderr)
                continue
            if not token:
                return result
            stripped = result.lstrip()
            if stripped.startswith(token):
                rest = stripped[len(token):].lstrip("\n").strip() or None
                if rest and not any(marker in rest for marker in TOOL_CALL_MARKERS):
                    return rest
                print(f"[LLM] attempt {attempt}: token echoed but flags partially applied (tool calls in output); retrying", file=sys.stderr)
                break
            if any(marker in result for marker in TOOL_CALL_MARKERS):
                print(f"[LLM] attempt {attempt}: flags not applied (tool calls in output); retrying", file=sys.stderr)
            else:
                print(f"[LLM] attempt {attempt}: verification token missing; retrying", file=sys.stderr)
            break
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
        model=default_model(),
    )
