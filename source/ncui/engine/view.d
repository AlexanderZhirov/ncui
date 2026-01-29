module ncui.engine.view;

import ncui.core.ncwin;
import ncui.core.window;
import ncui.core.panel;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;

// alias CanActivateFn = bool delegate();

interface IViewBody
{
	void render(Window window, ScreenContext context, bool active);
	ScreenAction handle(ScreenContext context, KeyEvent event);
	void close();
}

abstract class ViewBody : IViewBody
{
private:
	int _tickMs = -1;

protected:
	final void setTickMs(int ms)
	{
		_tickMs = (ms < 0) ? -1 : ms;
	}

public:
	final int tickMs() const
	{
		return _tickMs;
	}
}

final class View
{
private:
	Window _window;
	Panel _panel;
	ViewBody _body;
	IThemeContext _localTheme;

	bool _active;
	bool _focusable = true;

public:
	this(Window w, ViewBody viewBody, bool focusable = true)
	{
		_window = w;
		_body = viewBody;
		_focusable = focusable;
		_panel = new Panel(_window.handle());
	}

	ScreenAction onTick(ScreenContext context)
	{
		if (auto idle = cast(IIdleScreen) _body)
		{
			return idle.onTick(context);
		}

		return ScreenAction.none();
	}

	int tickMs() const
	{
		if (auto idle = cast(IIdleScreen) _body)
		{
			return idle.tickMs();
		}

		return -1;
	}

	Window window()
	{
		return _window;
	}

	NCWin inputWindow()
	{
		return _window.handle();
	}

	@property bool focusable()
	{
		return _focusable;
	}

	@property bool active()
	{
		return _active;
	}

	void top()
	{
		_panel.top();
	}

	void setActive(bool a)
	{
		_active = a;

		if (a)
		{
			top();
		}
	}

	LocalTheme localTheme(ScreenContext context)
	{
		if (_localTheme is null)
		{
			_localTheme = new LocalTheme(context.themeManager, context.theme);
		}

		return cast(LocalTheme) _localTheme;
	}

	void render(ScreenContext context, bool focused)
	{
		auto currentContext = context;
		if (_localTheme !is null)
		{
			currentContext.theme = _localTheme;
		}

		_window.setBackground(currentContext.theme.attr(StyleId.WindowBackground));
		_body.render(_window, currentContext, focused);
	}

	void placeCursor(ScreenContext context)
	{
		if (_body is null)
		{
			return;
		}

		import ncui.widgets.widget : ICursorOwner;

		if (auto c = cast(ICursorOwner) _body)
		{
			c.placeCursor(context);
		}
	}

	ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (_body is null)
		{
			return ScreenAction.none();
		}

		return _body.handle(context, event);
	}

	void close()
	{
		if (_body !is null)
		{
			_body.close();
		}

		if (_panel !is null)
		{
			_panel.close();
		}

		if (_window !is null)
		{
			_window.close();
		}

		_body = null;
		_panel = null;
		_window = null;
	}

	~this()
	{
		close();
	}
}
