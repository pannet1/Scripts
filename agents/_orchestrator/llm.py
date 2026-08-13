from __future__ import annotations

import json
import shutil
import subprocess
import sys
import select
from pathlib import Path

from .config import MODEL_CONFIG, REPO_ROOT

TOOL_CALL_MARKERS = ("<tool_calls>", "<invoke>")

def default_model() -> str:
    if not MODEL_CONFIG.exists():
        cfg = {}
    else:
        cfg = json.loads(MODEL_CONFIG.read_text())
    return cfg.get("model", "")

# Free-tier OpenCode Zen models, most capable first (per provider descriptions:
# largest/agentic reasoning first, fast tiers after). llm_complete falls down
# this chain so a failing completion moves to the next model instead of
# retrying the same one.
FREE_MODEL_CHAIN: tuple[str, ...] = (
    "nemotron-3-ultra-free",
    "deepseek-v4-flash-free",
    "nemotron-3.5-lightning-free",
)

def _model_chain(model: str, limit: int) -> list[str]:
    """Attempt order: an explicitly requested `model` first, then the free
    tier chain, never repeating a model."""
    if model:
        chain = [model]
    else:
        chain = list(FREE_MODEL_CHAIN)
    # De-duplicate while preserving order
    seen = set()
    ordered = []
    for m in chain:
        if m not in seen:
            seen.add(m)
            ordered.append(m)
    return ordered[:limit]

def _omp_binary() -> str | None:
    return shutil.which("omp")

def _extract_text(ndjson: str) -> str | None:
    """Pull the final assistant text out of the omp `--mode json` event stream."""
    if not ndjson:
        return None
    # ... (rest of the function)
    return None

def _stop_reason(ndjson: str) -> str:
    reason = ""
    # ... (rest of the function)
    return f" (stopReason={reason})" if reason else ""

def llm_complete(prompt: str, system: str = "", model: str = "", timeout: int = 300, max_attempts: int = 1) -> str | None:
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

    During execution, real-time progress is printed to stderr so the user
    can see what omp is doing instead of a silent wait.
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
        print(f"[LLM] Starting omp -p attempt {i} (model={m})", file=sys.stderr)
        sys.stderr.flush()

        proc = subprocess.Popen(
            cmd,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
            cwd=str(REPO_ROOT),
        )

        # Read output line by line in real time using select
        result_text = None
        error_lines: list[str] = []

        while proc.poll() is None:
            # Check for available file descriptors with timeout
            ready, _, _ = select.select([proc.stdout, proc.stderr], [], [], 0.5)
            for fd in ready:
                line = fd.readline()
                if not line:
                    continue
                line = line.strip()
                if not line:
                    continue
                # Print stdout lines (omp events)
                if fd == proc.stdout:
                    print(f"[LLM] omp event: {line[:200]}", file=sys.stderr)
                # Print stderr lines (omp errors/warnings)
                else:
                    error_lines.append(line)
            sys.stderr.flush()

        # Read any remaining output
        for fd in [proc.stdout, proc.stderr]:
            remaining = fd.read()
            for line in remaining.splitlines():
                line = line.strip()
                if not line:
                    continue
                if fd == proc.stdout:
                    print(f"[LLM] omp event: {line[:200]}", file=sys.stderr)
                else:
                    error_lines.append(line)

        proc.wait()
        sys.stderr.flush()

        # Process stderr for diagnostics
        if error_lines:
            print(f"[LLM] omp stderr for attempt {i}:", file=sys.stderr)
            for el in error_lines[:5]:
                print(f"  {el}", file=sys.stderr)
            sys.stderr.flush()

        # Check for 429 rate limit errors and explicitly continue to next model
        if any("429" in el or "rate limit" in el.lower() for el in error_lines):
            print(f"[LLM] attempt {i}: rate limit error detected (429), trying next model (model={m})", file=sys.stderr)
            sys.stderr.flush()
            continue

        # Extract text from stdout if available
        # (stdout contains the NDJSON event stream)
        stdout_data = proc.stdout.read() if proc.stdout else ""
        result = _extract_text(stdout_data)

        if result:
            if any(marker in result for marker in TOOL_CALL_MARKERS):
                print(f"[LLM] attempt {i}: response contains raw tool-call markers (model={m}); trying next model", file=sys.stderr)
                sys.stderr.flush()
                continue
            return result

        # Model failed - report why
        reason_parts = []
        if proc.returncode != 0:
            reason_parts.append(f"exit code {proc.returncode}")
        if not result:
            reason_parts.append("no text extracted")
        if reason_parts:
            print(f"[LLM] attempt {i} failed (model={m}): {', '.join(reason_parts)}", file=sys.stderr)

    print("[LLM] no model produced usable text — giving up.", file=sys.stderr)
    sys.stderr.flush()
    return None

def generate_spec_with_ai(domain: str, action: str, prompt: str) -> str | None:
    root_spec = REPO_ROOT / "SPEC.md"
