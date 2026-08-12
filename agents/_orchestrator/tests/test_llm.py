from __future__ import annotations

import json
from unittest.mock import patch

from _orchestrator.llm import _model_chain, llm_complete


def _ndjson(text: str) -> str:
    ev = {"type": "message_end", "message": {"content": [{"type": "text", "text": text}]}}
    return json.dumps(ev) + "\n"


def _fake_run(by_model: dict[str, str]):
    calls: list[str] = []

    def fake_run(cmd: list[str], **kwargs: object) -> object:
        model = cmd[cmd.index("--model") + 1]
        calls.append(model)
        text = by_model.get(model, "")
        return type("R", (), {"returncode": 0, "stdout": _ndjson(text), "stderr": ""})()

    return fake_run, calls


class TestModelChain:

    def test_explicit_free_model_leads_chain(self) -> None:
        chain = _model_chain("deepseek-v4-flash-free", 3)
        assert chain[0] == "deepseek-v4-flash-free"
        assert len(chain) == 3

    def test_non_free_model_leads_chain(self) -> None:
        chain = _model_chain("claude-sonnet-4-5", 3)
        assert chain[0] == "claude-sonnet-4-5"
        assert len(chain) == 3

    def test_chain_capped_at_limit(self) -> None:
        assert len(_model_chain("", 2)) == 2
        assert len(_model_chain("", 5)) == 3


class TestLlmCompleteModelFallback:

    def test_failure_advances_to_next_model(self) -> None:
        fake_run, calls = _fake_run({"deepseek-v4-flash-free": "actual content"})
        with patch("_orchestrator.llm._omp_binary", return_value="omp"), \
                patch("_orchestrator.llm.subprocess.run", fake_run):
            result = llm_complete("prompt", system="sys", model="nemotron-3-ultra-free", max_attempts=3)
        assert result == "actual content"
        assert calls[0] == "nemotron-3-ultra-free"
        assert calls[1] == "deepseek-v4-flash-free"

    def test_empty_model_not_retried(self) -> None:
        fake_run, calls = _fake_run({})
        with patch("_orchestrator.llm._omp_binary", return_value="omp"), \
                patch("_orchestrator.llm.subprocess.run", fake_run):
            result = llm_complete("prompt", system="sys", model="nemotron-3-ultra-free", max_attempts=3)
        assert result is None
        assert calls == ["nemotron-3-ultra-free", "deepseek-v4-flash-free", "nemotron-3.5-lightning-free"]
