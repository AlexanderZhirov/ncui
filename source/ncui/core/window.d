module ncui.core.window;

import deimos.ncurses;

import std.string : toStringz;
import std.conv : to;

import ncui.core.ncwin;
import ncui.lib.checks;

final class Window
{
private:
	NCWin _window;
	bool _closed;

public:
	this(int h, int w, int y, int x)
	{
		_window = ncuiNotNull!newwin(h, w, y, x);
		ncuiNotErr!keypad(_window, true);
	}

	int height()
	{
		return ncuiNotErr!getmaxy(_window);
	}

	int width()
	{
		return ncuiNotErr!getmaxx(_window);
	}

	void border()
	{
		ncuiNotErr!box(_window, 0, 0);
	}

	void erase()
	{
		ncuiNotErr!werase(_window);
	}

	void refresh()
	{
		ncuiNotErr!wrefresh(_window);
	}

	void noutrefresh()
	{
		ncuiNotErr!wnoutrefresh(_window);
	}

	void put(int y, int x, string s)
	{
		ncuiNotErr!mvwaddnstr(_window, y, x, s.toStringz, s.length.to!int);
	}

	void putAttr(int y, int x, string s, int attr)
	{
		if (attr != 0)
		{
			ncuiNotErr!wattron(_window, attr);
		}

		scope(exit)
		{
			if (attr != 0)
			{
				ncuiNotErr!wattroff(_window, attr);
			}
		}

		put(y, x, s);
	}

	void setBackground(int attr)
	{
		wbkgd(_window, cast(chtype)(' ') | cast(chtype)attr);
	}

	@property NCWin handle()
	{
		return _window;
	}

	void close()
	{
		if (_closed)
			return;
		if (!_window.isNull)
			ncuiNotErr!delwin(_window);
		_window = NCWin(null);
		_closed = true;
	}

	~this()
	{
		close();
	}
}
