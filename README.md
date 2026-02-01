# Ncurses User Interface Library

[![GitHub tag](https://img.shields.io/github/tag-date/AlexanderZhirov/ncui.svg?maxAge=86400&style=flat)](https://github.com/AlexanderZhirov/ncui/tags)
[![code.dlang.org](https://img.shields.io/dub/v/ncui.svg)](http://code.dlang.org/packages/ncui)
[![license](https://img.shields.io/github/license/AlexanderZhirov/ncui.svg?style=flat)](https://github.com/AlexanderZhirov/ncui/blob/master/LICENSE.txt)

`ncui` — библиотека для построения TUI-приложений на D поверх **ncurses**.

Проект включает:
- сессию ncurses с конфигурацией (`raw/cbreak`, `echo`, `keypad`, `cursor`, `ESC delay`)
- движок со стеком экранов (`push/replace/pop/popTo/quit`)
- два подхода к UI: `ScreenBase` (одно окно) и `WorkspaceScreen` (несколько окон)
- базовые виджеты: `Button`, `Checkbox`, `TextBox`, `TextView`, `Menu`
- единые проверки ошибок для вызовов ncurses / form / menu / panel

---

## DUB

`dub.json` проекта:

```json
{
	"dependencies": {
		"ncui": "~>0.1.0-alpha.4"
	}
}
```

---

## Примеры

В репозитории есть подпакет `example`:

```bash
dub run :example
```

[См. документацию](doc/).

---

## Лицензия

BSL-1.0
