module ncui.engine.view;

import ncui.core.ncwin;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;

// alias CanActivateFn = bool delegate();

interface IViewBody
{
	void render(Window window, ScreenContext context, bool active);
	ScreenAction handle(ScreenContext context, KeyEvent event);
}

final class View
{
private:
	Window _window;
	IViewBody _body;

	bool _active;
	bool _focusable = true;

public:
	this(Window w, IViewBody viewBody, bool focusable = true)
	{
		_window = w;
		_body = viewBody;
		_focusable = focusable;
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

	void setActive(bool a)
	{
		_active = a;
	}

	void render(ScreenContext context)
	{
		if (context.theme !is null)
		{
			_window.setBackground(context.theme.attr(StyleId.WindowBackground));
		}

		_window.erase();

		if (_body !is null)
		{
			_body.render(_window, context, _active);
		}

		_window.noutrefresh();
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
		_window.close();
	}

	~this()
	{
		close();
	}
}
