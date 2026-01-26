# Проверки ncurses-вызовов

Функции для проверяемых ncurses-вызовов и единых сообщений об ошибках.

---

## ncuiExpect

Вызывает `fn(args)` и проверяет `result == expected`.

- Тип `expected` должен совпадать с типом результата `fn(args)`.
- При ошибке выбрасывается исключение с местом вызова.
- Возвращается `result`.

---

## ncuiExpectMsg

Вызывает `fn(args)` и проверяет `result == expected`, добавляя `message`.

- Тип `expected` должен совпадать с типом результата `fn(args)`.
- При ошибке выбрасывается исключение с местом вызова.
- Возвращается `result`.

---

## ncuiNotErr

Вызывает `fn(args)` и проверяет `result != ERR`.

- `fn(args)` должна возвращать тип `ERR`.
- При ошибке выбрасывается исключение с местом вызова.
- Возвращается `result`.

---

## ncuiNotNull

Вызывает `fn(args)` и проверяет `result !is null`.

- `fn(args)` должна возвращать указатель.
- При ошибке выбрасывается исключение с местом вызова.
- Возвращается `result`.

---

## ncuiLibNotErr

Вызывает `fn(args)` и проверяет, что код возврата равен `E_OK`.

Используется для функций из ncurses-расширений (form/menu/panel), которые возвращают коды `E_*`
вместо `OK/ERR`.

- `fn(args)` должна возвращать `int` (коды `E_*`).
- При ошибке выбрасывается исключение с местом вызова и расшифровкой кода.
- Возвращается `result` (обычно `E_OK`).

---

## ncuiLibNotErrAny

Вызывает `fn(args)` и проверяет, что код возврата входит в список допустимых.

Подходит для "нормальных" ситуаций, когда библиотечная функция может вернуть не только `E_OK`,
но и, например, `E_REQUEST_DENIED`, и это не является ошибкой логики.

- `fn(args)` должна возвращать `int` (коды `E_*`).
- Допустимые коды задаются списком `codes`.
- При ошибке выбрасывается исключение с местом вызова и расшифровкой кода.
- Возвращается фактический `result`.

---

## Когда что использовать

- `ncuiNotErr` — для чистого ncurses, где результат `OK/ERR`.
- `ncuiNotNull` — для функций, возвращающих указатели (`newwin`, `new_form`, `new_field`, ...).
- `ncuiLibNotErr` — для form/menu/panel, где коды `E_*` и успех — это `E_OK`.
- `ncuiLibNotErrAny` — для form/menu/panel, когда допустимы несколько кодов (`E_OK`, `E_POSTED`, `E_REQUEST_DENIED`, ...).
- `ncuiExpect` / `ncuiExpectMsg` — для явной проверки конкретного ожидаемого результата (не только ncurses).

---

## Примеры

### Проверка указателя

```d
auto win = ncuiNotNull!newwin(h, w, y, x);
````

### Проверка OK/ERR

```d
ncuiNotErr!wrefresh(win);
```

### Проверка E_OK (form/menu/panel)

```d
ncuiLibNotErr!set_menu_sub(menu, subwin);
```

### Допустить несколько кодов

```d
ncuiLibNotErrAny!post_form([E_OK, E_POSTED], form);
ncuiLibNotErrAny!form_driver_w([E_OK, E_REQUEST_DENIED], form, KEY_CODE_YES, REQ_LEFT_CHAR);
```

### Ожидание конкретного значения

```d
ncuiExpect!has_colors(true);
ncuiExpectMsg!((int v) => v > 0)("width must be > 0", true, w);
```
