module simple.app;

import ncui;

import deimos.ncurses;

final class Simple : ScreenBase
{
	override void ensureWindow(ScreenContext context)
	{
		int height = getmaxy(context.session.root());
		int width = getmaxx(context.session.root());

		_window = new Window(height, width, 0, 0);
		_panel = new Panel(_window.handle());
	}

	override void layout(ScreenContext context, Window window, WidgetContainer ui)
	{
		_window.border();
		_window.put(1, 2, "Пример простого скрина с кнопками");
	}

	override void build(ScreenContext context, Window window, WidgetContainer ui)
	{
		auto okBtn = new Button(3, 2, "OK", () => ScreenAction.push(new Simple()));
		auto cancelBtn = new Button(3, 9, "Cancel", () => ScreenAction.pop(ScreenResult.none()));

		auto textBox1 = new TextBox(5, 11, 30, true, "Фамилия");
		auto textBox2 = new TextBox(6, 9, 30, false, "Кириллица", "Простой тест", r"^[А-Яа-я]$");
		auto textBox3 = new TextBox(7, 10, 30, false, "Латиница", string.init, r"^[A-Za-z]$");
		auto textBox4 = new TextBox(8, 2, 30, false, "Латиница + цифры", string.init, r"^[a-zA-Z0-9]$");

		auto disableOk = new Checkbox(4, 2, "Показать символы", false, (checked) {
			textBox1.hideText(!checked);
		});

		_ui.add(okBtn);
		_ui.add(cancelBtn);
		_ui.add(disableOk);
		_ui.add(textBox1);
		_ui.add(textBox2);
		_ui.add(textBox3);
		_ui.add(textBox4);
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
