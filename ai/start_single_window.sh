#!bin/env sh

./llamafile -m qwen2.5-coder-1.5b-instruct-q8_0.gguf --host 0.0.0.0 --threads 4 --ctx-size 2048 --parallel 1
