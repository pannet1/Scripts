"""Shared logger — standard library logging wrapper."""
import logging

logging.basicConfig(level=logging.INFO, format="%(asctime)s [%(levelname)s] %(name)s: %(message)s")


def logging_func(name: str) -> logging.Logger:
    """Return a logger for the given module name."""
    return logging.getLogger(name)
