module ncui.engine.workspace;

import deimos.ncurses;

import ncui.core.ncwin;
import ncui.core.event;
import ncui.engine.action;
import ncui.engine.screen;
import ncui.engine.view;

final class Workspace
{
private:
	View[] _views;
	int _active = -1;

	int firstAllowed()
	{
		foreach (i, view; _views)
		{
			if (view.focusable)
			{
				return cast(int) i;
			}
		}

		return -1;
	}

	bool setActive(int index)
	{
		if (index < 0)
		{
			return false;
		}

		if (index >= _views.length)
		{
			return false;
		}

		if (_active >= 0 && _active < _views.length)
		{
			_views[_active].setActive(false);
		}

		_active = index;
		_views[_active].setActive(true);

		return true;
	}

	void ensureActiveAllowed()
	{
		if (_views.length == 0)
		{
			_active = -1;
			return;
		}

		if (_active >= 0 && _active < _views.length)
		{
			auto v = _views[_active];

			if (v.focusable)
			{
				return;
			}
		}

		setActive(firstAllowed());
	}

	bool switchDelta(int delta)
	{
		if (_views.length == 0)
		{
			return false;
		}

		int length = cast(int) _views.length;
		int start = _active;

		if (start < 0)
		{
			start = 0;
		}

		int index = start;
		for (int step = 0; step < length; ++step)
		{
			index += delta;

			if (index < 0)
			{
				index = length - 1;
			}

			if (index >= length)
			{
				index = 0;
			}

			auto view = _views[index];

			if (!view.focusable)
			{
				continue;
			}

			return setActive(index);
		}

		return false;
	}

public:
	void add(View view)
	{
		_views ~= view;
		if (_active < 0)
		{
			setActive(firstAllowed());
		}
	}

	View active()
	{
		ensureActiveAllowed();

		if (_active < 0 || _active >= _views.length)
		{
			return null;
		}

		return _views[_active];
	}

	NCWin inputWindow()
	{
		auto a = active();
		return a is null ? NCWin(null) : a.inputWindow();
	}

	void render(ScreenContext context)
	{
		ensureActiveAllowed();

		foreach (view; _views)
		{
			view.render(context);
		}
	}

	bool handleSwitcher(KeyEvent event)
	{
		if (!event.isKeyCode())
		{
			return false;
		}

		switch (event.ch)
		{
		case KEY_BTAB:
			return switchDelta(+1);
		case KEY_SRIGHT:
			return switchDelta(+1);
		case KEY_SLEFT:
			return switchDelta(-1);
		default:
			break;
		}

		return false;
	}

	ScreenAction handleActive(ScreenContext context, KeyEvent event)
	{
		auto a = active();
		return a is null ? ScreenAction.none() : a.handle(context, event);
	}

	void close()
	{
		foreach (v; _views)
		{
			v.close();
		}

		_views.length = 0;
		_active = -1;
	}

	~this()
	{
		close();
	}
}
