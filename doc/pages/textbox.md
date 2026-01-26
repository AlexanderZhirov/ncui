# TextBox

Однострочное поле ввода на базе `form` (ncurses forms).

## Особенности

* Реализует `IWidgetClosable` и `ICursorOwner`.
* Использует `FORM*` + `FIELD*` для ввода.
* Поддерживает:

  * метку (не редактируется)
  * маску ввода (regex по `dchar`)
  * скрытый ввод (`hidden`), например пароль
  * ручное управление позицией курсора

## Поведение ввода

* Стрелки/Home/End — перемещение курсора.
* Backspace/Delete — удаление.
* Ввод символов:

  * проверка маски (если задана)
  * ограничение по буферу
  * `REQ_VALIDATION` после изменений

## Курсор

`placeCursor()` делает виджет "активным" с точки зрения ncurses:

* `set_current_field(form, fieldInput)`
* `curs_set(Cursor.high)`
* `pos_form_cursor(form)`

Важно: курсор ставится **после** общей отрисовки контейнера, через `WidgetContainer.applyCursor()`.

## Пример

```d
auto login = new TextBox(2, 2, 20, false, "Login", "", "^[a-zA-Z0-9_]+$");
auto pass  = new TextBox(4, 2, 20, true,  "Pass",  "", "");
```
