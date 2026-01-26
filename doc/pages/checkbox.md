# Checkbox

Флажок с подписью.

## Поведение

* `focusable = true`
* Переключение по `Enter` или `Space`
* `OnChange` — коллбек, вызывается при смене состояния

## Отрисовка

* Рисует `"[x]"` или `"[ ]"` и текст метки.
* Стиль выбирается по состоянию:

  * `CheckboxInactive` если `!enabled`
  * `CheckboxActive` если `focused`
  * `Checkbox` иначе

## Пример: чекбокс управляет доступностью кнопки

```d
Button btn = new Button(4, 2, "Continue", () => ScreenAction.none());
btn.setEnabled(false);

auto cb = new Checkbox(2, 2, "I agree", false, (checked) {
	btn.setEnabled(checked);
});
```
