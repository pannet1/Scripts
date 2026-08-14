from __future__ import annotations

import io
import json
from unittest.mock import patch

from _orchestrator.llm import _model_chain, llm_complete


def _ndjson(text: str) -> str:
    ev = {"type": "message_end", "message": {"content": [{"type": "text", "text": text}]}}
    return json.dumps(ev) + "\n"


class FakePopen:
    def __init__(self, stdout_text: str = "", stderr_text: str = "", returncode: int = 0):
        self.stdout = io.StringIO(stdout_text)
        self.stderr = io.StringIO(stderr_text)
        self.returncode = returncode
        self._polled = False
        self.terminated = False
        self.killed = False

    def poll(self) -> int | None:
        if self._polled:
            return self.returncode
        self._polled = True
        return None

    def wait(self, timeout: float | None = None) -> int:
        return self.returncode

    def terminate(self) -> None:
        self.terminated = True

    def kill(self) -> None:
        self.killed = True


def _fake_popen(by_model: dict[str, str], error_models: set[str] | None = None):
    calls: list[str] = []
    error_models = error_models or set()

    def fake_popen(cmd: list[str], **kwargs: object) -> FakePopen:
        model = cmd[cmd.index("--model") + 1]
        calls.append(model)
        if model in error_models:
            err_ev = {
                "type": "auto_retry_start",
                "attempt": 1,
                "maxAttempts": 10,
                "delayMs": 30000,
                "errorMessage": "429 Error from provider: Rate limit exceeded",
            }
            return FakePopen(stdout_text=json.dumps(err_ev) + "\n", returncode=0)
        text = by_model.get(model, "")
        return FakePopen(stdout_text=_ndjson(text), returncode=0)

    return fake_popen, calls


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
        fake_popen, calls = _fake_popen({"deepseek-v4-flash-free": "actual content"})
        with patch("_orchestrator.llm._omp_binary", return_value="omp"), \
                patch("_orchestrator.llm.subprocess.Popen", fake_popen):
            result = llm_complete("prompt", system="sys", model="nemotron-3-ultra-free", max_attempts=3)
        assert result == "actual content"
        assert calls[0] == "nemotron-3-ultra-free"
        assert calls[1] == "deepseek-v4-flash-free"

    def test_empty_model_not_retried(self) -> None:
        fake_popen, calls = _fake_popen({})
        with patch("_orchestrator.llm._omp_binary", return_value="omp"), \
                patch("_orchestrator.llm.subprocess.Popen", fake_popen):
            result = llm_complete("prompt", system="sys", model="nemotron-3-ultra-free", max_attempts=3)
        assert result is None
        assert calls == ["nemotron-3-ultra-free", "deepseek-v4-flash-free", "nemotron-3.5-lightning-free"]

    def test_auto_retry_breaks_inner_loop_and_advances(self) -> None:
        fake_popen, calls = _fake_popen(
            {"deepseek-v4-flash-free": "recovered output"},
            error_models={"nemotron-3-ultra-free"},
        )
        with patch("_orchestrator.llm._omp_binary", return_value="omp"), \
                patch("_orchestrator.llm.subprocess.Popen", fake_popen):
            result = llm_complete("prompt", system="sys", model="nemotron-3-ultra-free", max_attempts=3)
        assert result == "recovered output"
        assert calls[0] == "nemotron-3-ultra-free"
        assert calls[1] == "deepseek-v4-flash-free"

    def test_rate_limit_error_advances_to_next_model(self) -> None:
        def fake_popen_rl(cmd: list[str], **kwargs: object) -> FakePopen:
            model = cmd[cmd.index("--model") + 1]
            if model == "nemotron-3-ultra-free":
                return FakePopen(stderr_text="429 Rate limit exceeded\n", returncode=1)
            return FakePopen(stdout_text=_ndjson("success after rate limit"), returncode=0)

        with patch("_orchestrator.llm._omp_binary", return_value="omp"), \
                patch("_orchestrator.llm.subprocess.Popen", fake_popen_rl):
            result = llm_complete("prompt", system="sys", model="nemotron-3-ultra-free", max_attempts=3)
        assert result == "success after rate limit"
