# Button

Кнопка "нажимаемая" (Enter/Space).

## Поведение

* `focusable = true`
* `enabled` управляется через `setEnabled()`
* Срабатывает по `Enter` или `Space`, вызывает `OnClick`, возвращает `ScreenAction`

## Отрисовка

* Выбирает стиль по состоянию:

  * `ButtonInactive` если `!enabled`
  * `ButtonActive` если `focused`
  * `Button` иначе

## Пример

```d
auto btn = new Button(2, 2, "Save", () => ScreenAction.pop(ScreenResult.ok(true)));
btn.setEnabled(true);
```
