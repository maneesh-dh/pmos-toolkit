# widget-cli

Command-line tool for managing widgets.

## Install

```bash
npm install -g widget-cli
```

## Usage

Create a widget:

```bash
widget create --name foo --color blue
```

List widgets:

```bash
widget list
```

Delete a widget by id:

```bash
widget delete 42
```

## Configuration

Set defaults in `~/.widgetrc`:

```toml
default_color = "blue"
default_size = "medium"
```

## License

MIT.
