# cachelite

cachelite is a 200-line in-memory key-value cache for Python scripts that need TTL without Redis.

Use it when you want bounded memory and millisecond reads without running a separate process.

## Install

```bash
pip install cachelite
```

## Usage

Import `Cache`, set keys with `cache.set(k, v, ttl=60)`, read with `cache.get(k)`.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md).

## License

Apache-2.0
