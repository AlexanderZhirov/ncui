# Menu

Вертикальное меню на базе `menu` (ncurses menu).

## Назначение

* Список пунктов, перемещение стрелками.
* Подтверждение выбором по Enter, вызывается `AcceptCallback`.

## Управление

* `Up/Down` — вверх/вниз
* `Home/End` — первый/последний пункт
* `Enter` — принять выбор

## Отрисовка и стили

* `set_menu_back` — фон
* `set_menu_fore` — активный пункт (когда `focused`)
* `set_menu_grey` — "серые" пункты (в текущей реализации используется стиль `MenuItemInactive`)

Если включена рамка — рисуется box с `BorderActive/BorderInactive`.

## Пример

```d
MenuLabel[] items = [
	MenuLabel("Open", "Open file"),
	MenuLabel("Exit", "Quit"),
];

auto menu = new Menu(2, 2, 20, 6, items, (i, label) {
	if (label == "Exit") return ScreenAction.quit(ScreenResult.ok(true));
	return ScreenAction.none();
});
```
