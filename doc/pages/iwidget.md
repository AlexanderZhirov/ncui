# Общие интерфейсы

## IWidget

Базовый контракт любого виджета.

- `focusable` — можно ли поставить фокус.
- `enabled` — активен ли виджет (если `false`, виджет считается отключенным и не должен принимать ввод).
- `render(window, context, focused)` — отрисовка.
- `handle(context, event)` — обработка ввода, возвращает `ScreenAction`.

```d
interface IWidget
{
	@property bool focusable();
	@property bool enabled();
	void render(Window window, ScreenContext context, bool focused);
	ScreenAction handle(ScreenContext context, KeyEvent event);
}
```

---

## IWidgetClosable

Опциональный интерфейс для детерминированного освобождения ресурсов.

* Используется виджетами, которые выделяют ресурсы ncurses (формы/поля/окна).
* `close()` должен быть идемпотентным (повторный вызов безопасен).

```d
interface IWidgetClosable
{
	void close();
}
```

---

## ICursorOwner

Опциональный интерфейс для виджетов, которые управляют курсором.

* Вызывается контейнером **после отрисовки** всех виджетов.
* Внутри обычно делается:

  * выбор текущего поля (`set_current_field`)
  * установка видимости курсора (`curs_set`)
  * позиционирование (`pos_form_cursor`)

```d
interface ICursorOwner
{
	void placeCursor(ScreenContext context);
}
```

---

## Обработка стандартных клавиш

В модуле `ncui.widgets.widget` есть простые хелперы для распознавания типовых нажатий.

* `isTab` — переключение фокуса внутри контейнера.
* `isEnter` — Enter в разных режимах (символ + KEY_ENTER-код).
* `isSpace` — пробел (часто используется как "активация").

```d
bool isTab(KeyEvent ev);
bool isEnter(KeyEvent ev);
bool isSpace(KeyEvent ev);
```

---

## Жизненный цикл и ресурсы

Виджеты делятся на два типа:

### "Лёгкие" (без ncurses-ресурсов)

* `Button`
* `Checkbox`

Обычно не требуют `close()`.

### "Тяжёлые" (формы/поля/окна)

* `TextBox`
* `TextView`
* `Menu`

Рекомендации:

* Ресурсы создавать лениво (в `ensureCreated()` при первом `render()`).
* В `close()` обязательно:

  * снять публикацию (`unpost_*`)
  * освободить структуры (`free_*`)
  * удалить окна (`delwin`) если создавались `derwin`
* `close()` должен быть идемпотентным.

---

## Когда что использовать

* `Button` — действие (OK/Cancel/Save).
* `Checkbox` — булево состояние, часто влияет на доступность других виджетов.
* `TextBox` — ввод одной строки (логин, пароль, фильтр, значение).
* `TextView` — вывод текста с прокруткой (лог, help, описание).
* `Menu` — выбор одного варианта из списка.
* `WidgetContainer` — всегда, если в окне больше одного виджета и нужен Tab-фокус + курсор.
