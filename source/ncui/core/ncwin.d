module ncui.core.ncwin;

import deimos.ncurses : WINDOW;

struct NCWin
{
	WINDOW* _p;

	this(WINDOW* p) { _p = p; }

	@property WINDOW* ptr() @trusted const { return cast(WINDOW*)_p; }
	alias ptr this;

	@property bool isNull() const { return _p is null; }
}
