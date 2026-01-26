module ncui.core.window;

import deimos.ncurses;

import std.string : toStringz;
import std.conv : to;

import ncui.core.ncwin;
import ncui.lib.checks;

enum WindowBorder : int
{
	none = 0,
	top = 1,
	right = 2,
	bottom = 4,
	left = 8
}

final class Window
{
private:
	NCWin _window;
	bool _closed;

	static bool hasSide(int sides, WindowBorder side) @nogc nothrow
	{
		return (sides & cast(int) side) != 0;
	}

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

	void border(int sides)
	{
		if (_window.isNull || sides == WindowBorder.none)
		{
			return;
		}

		const int h = height();
		const int w = width();

		if (h <= 0 || w <= 0)
		{
			return;
		}

		const bool top = (sides & WindowBorder.top) != 0;
		const bool right = (sides & WindowBorder.right) != 0;
		const bool bottom = (sides & WindowBorder.bottom) != 0;
		const bool left = (sides & WindowBorder.left) != 0;

		const chtype blank = cast(chtype)(' ');

		// Стороны: линия либо пусто.
		const chtype ls = left ? ACS_VLINE : blank;
		const chtype rs = right ? ACS_VLINE : blank;
		const chtype ts = top ? ACS_HLINE : blank;
		const chtype bs = bottom ? ACS_HLINE : blank;

		// Углы: если есть обе стороны — угол; если одна — продолжающая линия; если ни одной — пусто.
		const chtype tl = (top && left) ? ACS_ULCORNER : (top ? ACS_HLINE : (left ? ACS_VLINE : blank));
		const chtype tr = (top && right) ? ACS_URCORNER : (top ? ACS_HLINE : (right ? ACS_VLINE : blank));
		const chtype bl = (bottom && left) ? ACS_LLCORNER : (bottom ? ACS_HLINE : (left ? ACS_VLINE : blank));
		const chtype br = (bottom && right) ? ACS_LRCORNER : (bottom ? ACS_HLINE : (right ? ACS_VLINE : blank));

		ncuiNotErr!wborder(_window, ls, rs, ts, bs, tl, tr, bl, br);
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

		scope (exit)
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
		wbkgd(_window, cast(chtype)(' ') | cast(chtype) attr);
	}

	void setCursor(int cursor)
	{
		ncuiNotErr!curs_set(cursor);
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
