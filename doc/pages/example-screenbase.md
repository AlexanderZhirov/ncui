# Пример ScreenBase

Минимальный экран на `ScreenBase`: одно окно, `WidgetContainer`, несколько виджетов и возврат результата через `ScreenResult`.

## Поведение

- `Tab` — переключение фокуса между виджетами.
- `Enter` / `Space` — активация кнопок и чекбоксов.
- `Esc` / `q` — завершение приложения.

## Код

```d
import ncui;
import ncui.engine.theme : LightTheme;
import deimos.ncurses;

/// Экран авторизации: логин + пароль + показать пароль + OK/Cancel.
/// Возвращает строку "login:password" через ScreenResult.ok(string).
final class LoginScreen : ScreenBase
{
private:
	TextBox _login;
	TextBox _password;
public:
	override Window ensureWindow(ScreenContext context)
	{
		const int H = getmaxy(context.session.root());
		const int W = getmaxx(context.session.root());

		const int h = 12;
		const int w = 54;

		return new Window(h, w, (H - h) / 2, (W - w) / 2);
	}

	override void layout(Window window, ScreenContext context)
	{
		_window.border();
		_window.putAttr(0, 2, " LOGIN ", context.theme.attr(StyleId.Title));

		_window.put(2, 2, "Tab  -> focus next");
		_window.put(3, 2, "Enter-> activate");
		_window.put(4, 2, "Esc/q-> quit");
	}

	override void build(Window window, ScreenContext context, WidgetContainer ui)
	{
		_login = new TextBox(6, 2, 24, false, "Login");
		_password = new TextBox(7, 2, 24, true, "Password");

		auto showPass = new Checkbox(6, 30, "Show", false, (checked) {
			_password.hideText(!checked);
		});

		auto okBtn = new Button(9, 2, "OK", () {
			const string value = _login.text() ~ ":" ~ _password.text();
			return ScreenAction.pop(ScreenResult.ok(value));
		});

		auto cancelBtn = new Button(9, okBtn.width + 3, "Cancel", () {
			return ScreenAction.pop(ScreenResult.cancel());
		});

		ui.add(_login);
		ui.add(showPass);
		ui.add(_password);
		ui.add(okBtn);
		ui.add(cancelBtn);
	}

	override ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		// ERR часто используется как сигнал завершения демонстрационного цикла ввода.
		if (event.status == ERR)
		{
			return ScreenAction.quit(ScreenResult.cancel());
		}

		if (event.isChar && (event.ch == 27 || event.ch == 'q' || event.ch == 'Q'))
		{
			return ScreenAction.quit(ScreenResult.cancel());
		}

		return ScreenAction.none();
	}
}

void main()
{
	auto config = SessionConfig(InputMode.raw, Cursor.normal, Echo.off, Keypad.on);
	auto app = new NCUI(config, new LightTheme());

	app.run(new LoginScreen());
}
```
