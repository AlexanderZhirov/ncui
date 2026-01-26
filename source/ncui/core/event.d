module ncui.core.event;

import deimos.ncurses : KEY_CODE_YES, OK, ERR;

struct KeyEvent
{
	int status;
	dchar ch;

	this(int status, dchar ch)
	{
		this.status = status;
		this.ch = ch;
	}

	@property bool isKeyCode() const
	{
		return status == KEY_CODE_YES;
	}

	@property bool isChar() const
	{
		return status == OK;
	}

	@property bool isErr() const
	{
		return status == ERR;
	}
}
