# WidgetContainer

Контейнер виджетов: хранит список, управляет фокусом и раздаёт ввод/отрисовку.

## Правила фокуса

* Фокус ставится только на `focusable && enabled`.
* Если фокуса нет, контейнер отдаёт фокус первому подходящему при добавлении.
* `Tab` переключает фокус по кругу.

## Рендеринг

* В `render()` каждый виджет получает флаг `focused`:

  * `true`, если контейнер активен и индекс совпадает с `_focus`.

## Курсор

* `applyCursor()` вызывает `placeCursor()` у текущего сфокусированного виджета, если он реализует `ICursorOwner`.

## Пример

```d
auto ui = new WidgetContainer();
ui.add(new Button(1, 2, "OK", () => ScreenAction.pop(ScreenResult.ok(true))));
ui.add(new Checkbox(3, 2, "Enable advanced", false));
ui.add(new TextBox(5, 2, 20, false, "Login", "", ""));

// В рендере экрана:
ui.render(window, ctx);
ui.applyCursor(ctx);
```
