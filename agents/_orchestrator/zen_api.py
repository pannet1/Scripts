import json
import os
import random
import string
import sys
import urllib.request
import uuid
from pathlib import Path
from typing import Any

from .config import REPO_ROOT, MODEL_CONFIG

ZEN_URL = "https://opencode.ai/zen/v1/chat/completions"

ZEN_FALLBACKS = [
    "deepseek-v4-flash",
    "deepseek-v4-flash-free",
]


def _zen_session_id() -> str:
    alphabet = string.ascii_uppercase + string.ascii_lowercase + string.digits + "-_"
    return "ses_" + "".join(random.choices(alphabet, k=26))


def _zen_api_key() -> str:
    return os.environ.get("OPENCODE_ZEN_KEY", "public")


def _zen_model() -> str:
    if MODEL_CONFIG.exists():
        try:
            cfg = json.loads(MODEL_CONFIG.read_text())
            return cfg.get("model", ZEN_FALLBACKS[0])
        except Exception:
            pass
    return ZEN_FALLBACKS[0]


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
    project_id = str(uuid.uuid4())
    api_key = _zen_api_key()
    headers = {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {api_key}",
        "x-opencode-project": project_id,
        "x-opencode-session": _zen_session_id(),
        "x-opencode-request": str(uuid.uuid4()),
        "x-opencode-client": "python-script",
        "User-Agent": "opencode/1.15.4",
    }
    payload: dict[str, Any] = {
        "model": _zen_model(),
        "messages": [
            {"role": "system", "content": system_prompt},
            {"role": "user", "content": f"Feature: {action}\nDomain: {domain or '(none)'}\n\nDescription:\n{prompt}"},
        ],
        "max_tokens": 2048,
        "temperature": 0.3,
    }
    return _zen_chat(headers, payload)


def _zen_chat(headers: dict, payload: dict) -> str | None:
    fallbacks = ZEN_FALLBACKS[:]
    selected = payload["model"]
    if selected in fallbacks:
        fallbacks.remove(selected)
    fallbacks.insert(0, selected)

    for model in fallbacks:
        payload["model"] = model
        data = json.dumps(payload).encode()
        req = urllib.request.Request(ZEN_URL, data=data, headers=headers, method="POST")
        try:
            with urllib.request.urlopen(req, timeout=15) as resp:
                body = json.loads(resp.read())
        except urllib.error.HTTPError as e:
            if e.code == 401:
                print(f"[Orchestrator] Model '{model}' unavailable (free tier ended). Trying next...", file=sys.stderr)
                continue
            print(f"[Orchestrator] Zen API error ({model}): {e}", file=sys.stderr)
            continue
        except Exception as e:
            print(f"[Orchestrator] Zen API error ({model}): {e}", file=sys.stderr)
            continue

        try:
            msg = body["choices"][0]["message"]
        except (KeyError, IndexError, TypeError) as e:
            print(f"[Orchestrator] Model '{model}' returned unexpected response: {e}", file=sys.stderr)
            continue
        content = (msg.get("content") or msg.get("reasoning_content") or "").strip()
        if content.startswith("```"):
            content = content.split("\n", 1)[1] if "\n" in content else content[3:]
            if content.endswith("```"):
                content = content[:-3].strip()
        if not content and model != fallbacks[-1]:
            print(f"[Orchestrator] Model '{model}' returned empty response. Trying next...", file=sys.stderr)
            continue
        if model != selected:
            MODEL_CONFIG.write_text(json.dumps({"model": model}) + "\n")
            print(f"[Orchestrator] Fallback: model config updated to '{model}'", file=sys.stderr)
        return content

    print("[Orchestrator] No working model found. Run ./.agents/select_model.py to pick one.", file=sys.stderr)
    return None
