module ncui.core.ncwin;

import deimos.ncurses : WINDOW;

struct NCWin
{
	WINDOW* _p;

	this(WINDOW* p)
	{
		_p = p;
	}

	@property WINDOW* ptr()
	{
		return _p;
	}

	alias ptr this;

	@property bool isNull() const
	{
		return _p is null;
	}

	void opAssign(NCWin rhs)
	{
		_p = rhs._p;
	}

	void opAssign(WINDOW* rhs)
	{
		_p = rhs;
	}
}
