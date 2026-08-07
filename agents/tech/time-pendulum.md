# Tech: Pendulum

- **Library**: `pendulum` for ALL date/time operations. `import pendulum`.
- **Banned**: `datetime`, `time`, `calendar` from stdlib.

## Swap Reference

| Stdlib | Pendulum |
|--------|----------|
| `datetime.now()` | `pendulum.now()` |
| `datetime.strptime()` | `pendulum.from_format()` |
| `datetime.strptime(s, f)` | `pendulum.from_format(s, f)` |
| `datetime.timedelta(days=n)` | `pendulum.duration(days=n)` |
| `time.sleep(n)` | `asyncio.sleep(n)` |
| `.strftime(fmt)` | `.format(fmt)` |
