# Ncurses User Interface Library

`ncui` — библиотека для построения TUI-приложений на D поверх **ncurses**.

Проект включает:
- сессию ncurses с конфигурацией (`raw/cbreak`, `echo`, `keypad`, `cursor`, `ESC delay`)
- движок со стеком экранов (`push/replace/pop/popTo/quit`)
- два подхода к UI: `ScreenBase` (одно окно) и `WorkspaceScreen` (несколько окон)
- базовые виджеты: `Button`, `Checkbox`, `TextBox`, `TextView`, `Menu`
- единые проверки ошибок для вызовов ncurses / form / menu / panel

---

## Установка (DUB)

`dub.json` проекта:

```json
{
	"dependencies": {
		"ncui": "~>0.1.0"
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
