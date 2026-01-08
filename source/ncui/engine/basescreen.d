module ncui.engine.basescreen;

import ncui.core.ncwin;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.widgets.container;

abstract class ScreenBase : IScreen
{
protected:
	Window _window;
	WidgetContainer _ui;
	bool _built;

	void ensureWindow(ScreenContext context);
	void build(ScreenContext context, Window window, WidgetContainer ui);
	void layout(ScreenContext context, Window window, WidgetContainer ui)
	{
	}

	ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		return ScreenAction.none();
	}

private:
	void renderAll(ScreenContext context)
	{
		import deimos.ncurses : doupdate;
		import ncui.lib.checks;

		_window.erase();
		layout(context, _window, _ui);
		_ui.render(_window, context);
		_window.noutrefresh();

		ncuiNotErr!doupdate();
	}

public:
	this()
	{
		_ui = new WidgetContainer();
	}

	override NCWin inputWindow()
	{
		return _window.handle();
	}

	override ScreenAction onShow(ScreenContext context)
	{
		if (_window !is null)
		{
			_window.close();
		}

		ensureWindow(context);

		if (!_built)
		{
			build(context, _window, _ui);
			_built = true;
		}

		renderAll(context);
		return ScreenAction.none();
	}

	override ScreenAction onChildResult(ScreenContext context, ScreenResult child)
	{
		return ScreenAction.none();
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		auto result = handleGlobal(context, event);

		if (result.kind != ActionKind.None)
		{
			return result;
		}

		auto action = _ui.handle(context, event);

		if (action.kind != ActionKind.None)
		{
			return action;
		}

		renderAll(context);
		return ScreenAction.none();
	}

	override void close()
	{
		if (_window !is null)
		{
			_window.close();
		}

		_window = null;
		_built = false;
		_ui = new WidgetContainer();
	}
}
