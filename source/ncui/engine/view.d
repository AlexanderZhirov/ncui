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

final class View
{
private:
	Window _window;
	Panel _panel;
	IViewBody _body;

	bool _active;
	bool _focusable = true;

public:
	this(Window w, IViewBody viewBody, bool focusable = true)
	{
		_window = w;
		_body = viewBody;
		_focusable = focusable;
		_panel = new Panel(_window.handle());
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

	void render(ScreenContext context, bool focused)
	{
		_window.setBackground(context.theme.attr(StyleId.WindowBackground));
		_body.render(_window, context, focused);
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
