module simple.app;

import ncui;

import deimos.ncurses;

final class Simple : ScreenBase
{
	override ScreenAction onShow(ScreenContext context)
	{
		int height = getmaxy(context.session.root());
		int width = getmaxx(context.session.root());

		if (_window !is null)
		{
			_window.close();
		}

		_window = new Window(height, width, 0, 0);
		_window.erase();

		_window.border();

		string title = "Для выхода нажать ESC";

		_window.put(height / 2, width / 2 - cast(int) title.length / 2, title);

		_window.refresh();

		return ScreenAction.none();
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (event.status == ERR)
		{
			return ScreenAction.quit(ScreenResult.none());
		}

		if (event.isChar)
		{
			if (event.ch == 27) {
				return ScreenAction.quit(ScreenResult.none());
			}
		}

		return ScreenAction.none();
	}
}
