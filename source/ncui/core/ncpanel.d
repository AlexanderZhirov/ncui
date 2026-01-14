module ncui.core.ncpanel;

import deimos.panel : PANEL;

struct NCPanel
{
	PANEL* _p;

	this(PANEL* p)
	{
		_p = p;
	}

	@property PANEL* ptr()
	{
		return _p;
	}

	alias ptr this;

	@property bool isNull() const
	{
		return _p is null;
	}

	void opAssign(NCPanel rhs)
	{
		_p = rhs._p;
	}

	void opAssign(PANEL* rhs)
	{
		_p = rhs;
	}
}
