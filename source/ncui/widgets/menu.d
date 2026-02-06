module ncui.widgets.menu;

import deimos.menu;

import ncui.widgets.widget;
import ncui.core.ncwin;
import ncui.core.ncmenu;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;
import ncui.lib.checks;

import std.algorithm : min;

alias AcceptCallback = ScreenAction delegate(size_t index, string label);

struct MenuLabel
{
	string name;
	string description;
}

final class Menu : IWidget, IWidgetClosable
{
private:
	// Поле по умолчанию активно.
	bool _enabled = true;

	int _y;
	int _x;
	int _width;
	int _height;

	bool _border = true;
	bool _inited;

	MenuLabel[] _labels;
	string _mark = " > ";

	NCWin _window;
	NCWin _windowBorder;
	NCMenu _menu;
	NCItem[] _items;

	AcceptCallback _accept;

	size_t selectedIndex()
	{
		if (_labels.length == 0 || _menu.isNull)
		{
			return 0;
		}

		NCItem item = _menu.currentitem();

		if (item.isNull)
		{
			return 0;
		}

		return min(item.itemindex(), cast(int) _labels.length - 1);
	}

	int driveAllowDenied(int request)
	{
		return _menu.menudriver(request, [E_OK, E_REQUEST_DENIED]);
	}

	void applyMenuTheme(ScreenContext context, bool focused)
	{
		if (!_menu.isNull)
		{
			const int backAttr = context.theme.attr(StyleId.MenuItem);
			const int foreAttr = context.theme.attr(focused ? StyleId.MenuItemActive : StyleId.MenuItem);
			const int greyAttr = context.theme.attr(StyleId.MenuItemInactive);

			_menu.setmenuback(backAttr);
			_menu.setmenufore(foreAttr);
			_menu.setmenugrey(greyAttr);
		}

		if (_border)
		{
			const int attr = context.theme.attr(focused ? StyleId.BorderActive : StyleId.BorderInactive);
			_windowBorder.boxattr(0, 0, attr);
		}
	}

	void ensureCreated(Window window)
	{
		if (_inited)
		{
			return;
		}

		// Окно с рамкой.
		_windowBorder.derwin(window.handle(), _height, _width, _y, _x);
		_windowBorder.syncok();

		const int innerH = _border ? _height - 2 : _height;
		const int innerW = _border ? _width - 2 : _width;
		const int offY = _border ? 1 : 0;
		const int offX = _border ? 1 : 0;

		// Создание внутреннего окна.
		_window.derwin(_windowBorder, innerH, innerW, offY, offX);
		_window.syncok();

		_items.length = _labels.length + 1;
		foreach (index, label; _labels)
		{
			_items[index].newitem(label.name, label.description);
		}

		_items[$ - 1] = null;

		_menu.newmenu(_items);

		_menu.setmenuwin(_windowBorder);
		_menu.setmenusub(_window);
		_menu.setmenuformat(innerH, 1);

		_menu.setmenumark(_mark);
		// Публикация формы.
		_menu.postmenu();

		_inited = true;
	}

public:
	this(int y, int x, int w, int h, MenuLabel[] labels, AcceptCallback accept, bool border = true)
	{
		if (border)
		{
			ncuiExpectMsg!((int value) => value >= 3)("Menu.width must be >= 3 when border=true", true, w);
			ncuiExpectMsg!((int value) => value >= 3)("Menu.height must be >= 3 when border=true", true, h);
		}
		else
		{
			ncuiExpectMsg!((int value) => value > 0)("Menu.width must be > 0", true, w);
			ncuiExpectMsg!((int value) => value > 0)("Menu.height must be > 0", true, h);
		}
		ncuiExpectMsg!((MenuLabel[] l) => l.length > 0)("Menu.labels must not be empty", true, labels);
		ncuiExpectMsg!((AcceptCallback f) => f !is null)("Menu.accept must not be null", true, accept);

		_y = y;
		_x = x;
		_width = w;
		_height = h;
		_accept = accept;
		_border = border;

		// Хранение исходных наименований.
		_labels = labels;
	}

	override @property bool focusable()
	{
		return true;
	}

	override @property bool enabled()
	{
		return _enabled;
	}

	override void render(Window window, ScreenContext context, bool focused)
	{
		ensureCreated(window);
		applyMenuTheme(context, focused);
	}

	@property int width()
	{
		return _width;
	}

	@property int height()
	{
		return _height;
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!_enabled || _menu.isNull)
		{
			return ScreenAction.none();
		}

		if (event.isEnter)
		{
			if (_accept is null)
			{
				return ScreenAction.none();
			}

			const auto index = selectedIndex();
			return _accept(index, _labels[index].name);
		}

		if (!event.isKeyCode)
		{
			return ScreenAction.none();
		}

		switch (event.ch)
		{
		case KEY_UP:
			driveAllowDenied(REQ_UP_ITEM);
			break;
		case KEY_DOWN:
			driveAllowDenied(REQ_DOWN_ITEM);
			break;
		case KEY_HOME:
			driveAllowDenied(REQ_FIRST_ITEM);
			break;
		case KEY_END:
			driveAllowDenied(REQ_LAST_ITEM);
			break;
		default:
			break;
		}

		return ScreenAction.none();
	}

	override void close()
	{
		_menu.unpostmenu();
		_menu.freemenu();

		foreach (item; _items)
		{
			item.freeitem();
		}

		_items.length = 0;
		_labels.length = 0;

		_window.delwin();
		_windowBorder.delwin();

		_inited = false;
	}

	~this()
	{
		close();
	}
}
