# shipd

shipd is a small deploy queue that runs one job at a time and writes audit logs.

Use it when a team needs serialised deploys without a full CI server.

## Install

```bash
go install github.com/example/shipd@latest
```

## Usage

Start `shipd serve` and POST jobs to `localhost:8080/enqueue`.

## Contributing

See [CONTRIBUTING](CONTRIBUTING.md).

## License

BSD-3-Clause
