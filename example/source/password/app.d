module password.app;

import ncui;

import deimos.ncurses;

final class Password : ScreenBase
{
	override Window ensureWindow(ScreenContext context)
	{
		int height = getmaxy(context.session.root());
		int width = getmaxx(context.session.root());

		int winHeight = height / 2;
		int winWidth = width / 2;

		return new Window(winHeight, winWidth, winHeight - winHeight / 2, winWidth - winWidth / 2);
	}

	override void layout(Window window, ScreenContext context)
	{
		_window.border();
		_window.put(1, 2, "Форма ввода пароля");
	}

	override void build(Window window, ScreenContext context, WidgetContainer ui)
	{
		auto password = new TextBox(3, 2, 30, true, "Введите пароль");

		auto checkbox = new Checkbox(4, 2, "Показать пароль", false, (checked) {
			password.hideText(!checked);
		});

		auto okBtn = new Button(5, 2, "OK", () {
			return ScreenAction.pop(ScreenResult.ok(password.text()));
		});

		auto cancelBtn = new Button(5, okBtn.width + 3, "Cancel", () => ScreenAction.pop(ScreenResult.none()));

		_ui.add(password);
		_ui.add(checkbox);
		_ui.add(okBtn);
		_ui.add(cancelBtn);
	}

	override ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		if (event.status == ERR)
		{
			return ScreenAction.quit(ScreenResult.none());
		}

		if (event.isChar)
		{
			if (event.ch == 27)
			{
				return ScreenAction.quit(ScreenResult.none());
			}
		}

		return ScreenAction.none();
	}
}
