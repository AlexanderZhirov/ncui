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
