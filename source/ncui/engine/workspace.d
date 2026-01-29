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
	bool _workspaceActive = true;

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

	void ensureActiveAllowed()
	{
		if (_views.length == 0)
		{
			_active = -1;
			return;
		}

		if (_active >= 0 && _active < _views.length && _views[_active].focusable)
		{
			return;
		}

		const int index = firstAllowed();

		if (index < 0)
		{
			_active = -1;
			return;
		}

		setActive(index);
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

	void updatePanel()
	{
		import deimos.panel : update_panels;

		update_panels();
	}

	void doUpdate()
	{
		import ncui.lib.checks : ncuiNotErr;

		ncuiNotErr!doupdate();
	}

public:
	void setWorkspaceActive(bool active)
	{
		_workspaceActive = active;
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

	void add(View view)
	{
		_views ~= view;
		if (_active < 0)
		{
			setActive(firstAllowed());
		}
	}

	int tickMs() const
	{
		int best = -1;

		foreach (view; _views)
		{
			const int ms = view.tickMs();

			if (ms < 0)
			{
				 continue;
			}

			if (best < 0 || ms < best)
			{
				best = ms;
			}
		}

		return best;
	}

	ScreenAction onTick(ScreenContext context)
	{
		ensureActiveAllowed();

		foreach (view; _views)
		{
			auto action = view.onTick(context);

			if (action.kind != ActionKind.None)
			{
				return action;
			}
		}

		return ScreenAction.none();
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
			const bool focused = _workspaceActive && view.active;
			view.render(context, focused);
		}

		updatePanel();

		auto a = active();
		if (a !is null)
		{
			a.placeCursor(context);
		}

		doUpdate();
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
			return switchDelta(-1);
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
		foreach (view; _views)
		{
			view.close();
		}

		_views.length = 0;
		_active = -1;
	}

	~this()
	{
		close();
	}
}
