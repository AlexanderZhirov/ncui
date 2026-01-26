module ncui.engine.basescreen;

import ncui.core.ncwin;
import ncui.core.window;
import ncui.core.panel;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;
import ncui.widgets.container;

abstract class ScreenBase : IScreen
{
protected:
	Window _window;
	Panel _panel;
	WidgetContainer _ui;
	bool _built;

	Window ensureWindow(ScreenContext context);

	void build(Window window, ScreenContext context, WidgetContainer ui);
	void layout(Window window, ScreenContext context)
	{
	}

	ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		return ScreenAction.none();
	}

	void doUpdate()
	{
		import deimos.ncurses : doupdate;
		import ncui.lib.checks : ncuiNotErr;

		ncuiNotErr!doupdate();
	}

private:
	void render(ScreenContext context)
	{
		// Установка курсора по-умолчанию.
		_window.setCursor(context.session.settings.cursor);
		// Установка фона для окна.
		_window.setBackground(context.theme.attr(StyleId.WindowBackground));
		// Отрисовка пользовтельского оформления окна.
		layout(_window, context);
		// Отрисовка виджетов.
		_ui.render(_window, context);
		// Обновление панелей.
		_panel.update();
		// Установка курсора активному виджету.
		_ui.applyCursor(context);
		// Применение изменений.
		doUpdate();
	}

public:
	override NCWin inputWindow()
	{
		return _window.handle();
	}

	final override void onHide(ScreenContext context)
	{
		if (_ui !is null)
		{
			_ui.setActive(false);
		}

		render(context);
	}

	final override ScreenAction onShow(ScreenContext context)
	{
		if (_window is null)
		{
			_window = ensureWindow(context);
		}

		if (_ui is null)
		{
			_ui = new WidgetContainer();
		}

		if (_panel is null)
		{
			_panel = new Panel(_window.handle());
		}

		if (!_built)
		{
			build(_window, context, _ui);
			_built = true;
		}

		_panel.top();

		_ui.setActive(true);
		render(context);

		return ScreenAction.none();
	}

	override ScreenAction onChildResult(ScreenContext context, ScreenResult child)
	{
		return ScreenAction.none();
	}

	final override ScreenAction handle(ScreenContext context, KeyEvent event)
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

		render(context);

		return ScreenAction.none();
	}

	final override void close()
	{
		if (_ui !is null)
		{
			_ui.close();
		}

		if (_panel !is null)
		{
			_panel.close();
		}

		if (_window !is null)
		{
			_window.close();
		}

		_panel = null;
		_ui = null;
		_window = null;
		_built = false;
	}

	~this()
	{
		close();
	}
}
