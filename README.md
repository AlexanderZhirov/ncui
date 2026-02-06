# Ncurses User Interface Library

[![GitHub tag](https://img.shields.io/github/tag-date/AlexanderZhirov/ncui.svg?maxAge=86400&style=flat)](https://github.com/AlexanderZhirov/ncui/tags)
[![code.dlang.org](https://img.shields.io/dub/v/ncui.svg)](http://code.dlang.org/packages/ncui)
[![license](https://img.shields.io/github/license/AlexanderZhirov/ncui.svg?style=flat)](https://github.com/AlexanderZhirov/ncui/blob/master/LICENSE.txt)

`ncui` is a library for building TUI (Text User Interface) applications in **D** on top of **ncurses**.

The project includes:
- ncurses session with configurable settings (`raw`/`cbreak`, `echo`, `keypad`, `cursor`, `ESC delay`)
- screen stack engine (`push`/`replace`/`pop`/`popTo`/`quit`)
- two UI approaches: `ScreenBase` (single window) and `WorkspaceScreen` (multiple windows)
- basic widgets: `Button`, `Checkbox`, `TextBox`, `TextView`, `Menu`
- unified error checking for ncurses / form / menu / panel calls

---

## DUB

`dub.json` for your project:

```json
{
	"dependencies": {
		"ncui": "~>0.1.0-alpha.4"
	}
}
```

---

## Examples

The repository contains an `example` subpackage:

```bash
dub run :example
```

[See documentation](doc/).

---

## License

BSL-1.0
