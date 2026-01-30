module ncui.widgets.menu;

import deimos.menu;
import deimos.ncurses;

import ncui.widgets.widget;
import ncui.core.ncwin;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;
import ncui.lib.checks;

import std.utf : toUTF32, toUTF8;
import std.string : toStringz, fromStringz;
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
	const (char)* _mark = " > ".ptr;

	NCWin _window;
	NCWin _windowBorder;
	MENU* _menu;
	ITEM*[] _items;

	AcceptCallback _accept;

	size_t selectedIndex() const
	{
		if (_labels.length == 0 || _menu is null)
		{
			return 0;
		}

		ITEM* item = current_item(_menu);

		if (item is null)
		{
			return 0;
		}

		return min(item_index(item), cast(int) _labels.length - 1);
	}

	int driveAllowDenied(int request)
	{
		return ncuiLibNotErrAny!menu_driver([E_OK, E_REQUEST_DENIED], _menu, request);
	}

	void applyMenuTheme(ScreenContext context, bool focused)
	{
		if (_menu !is null)
		{
			const int backAttr = context.theme.attr(StyleId.MenuItem);
			const int foreAttr = context.theme.attr(focused ? StyleId.MenuItemActive : StyleId.MenuItem);
			const int greyAttr = context.theme.attr(StyleId.MenuItemInactive);

			ncuiLibNotErr!set_menu_back(_menu, backAttr);
			ncuiLibNotErr!set_menu_fore(_menu, foreAttr);
			ncuiLibNotErr!set_menu_grey(_menu, greyAttr);
		}

		if (_border)
		{
			const int a = context.theme.attr(focused ? StyleId.BorderActive : StyleId.BorderInactive);

			if (a != 0)
			{
				ncuiNotErr!wattron(_windowBorder, a);
			}

			scope (exit)
			{
				if (a != 0) ncuiNotErr!wattroff(_windowBorder, a);
			}

			ncuiNotErr!box(_windowBorder, 0, 0);
		}
	}


	void ensureCreated(Window window)
	{
		if (_inited)
		{
			return;
		}

		// Окно с рамкой.
		_windowBorder = ncuiNotNull!derwin(window.handle(), _height, _width, _y, _x);
		ncuiNotErr!syncok(_windowBorder, true);

		const int innerH = _border ? _height - 2 : _height;
		const int innerW = _border ? _width - 2 : _width;
		const int offY = _border ? 1 : 0;
		const int offX = _border ? 1 : 0;

		// Создание внутреннего окна.
		_window = ncuiNotNull!derwin(_windowBorder, innerH, innerW, offY, offX);
		ncuiNotErr!syncok(_window, true);
		// +1 для null строки.
		_items.length = _labels.length + 1;

		foreach (index, label; _labels)
		{
			_items[index] = ncuiNotNull!new_item(label.name.toStringz, label.description.toStringz);
		}

		_items[_labels.length] = null;

		_menu = ncuiNotNull!new_menu(_items.ptr);

		ncuiLibNotErr!set_menu_win(_menu, _windowBorder);
		ncuiLibNotErr!set_menu_sub(_menu, _window);
		ncuiLibNotErr!set_menu_format(_menu, innerH, 1);

		ncuiLibNotErr!set_menu_mark(_menu, _mark);
		// Публикация формы.
		ncuiLibNotErrAny!post_menu([E_OK, E_POSTED], _menu);

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
		if (!_enabled || _menu is null)
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
		if (_menu !is null)
		{
			ncuiLibNotErrAny!unpost_menu([E_OK, E_NOT_POSTED], _menu);
			ncuiLibNotErr!free_menu(_menu);
			_menu = null;
		}

		foreach (item; _items)
		{
			if (item !is null)
			{
				ncuiLibNotErr!free_item(item);
			}
		}

		_items.length = 0;
		_labels.length = 0;

		if (!_window.isNull)
		{
			ncuiLibNotErr!delwin(_window);
			_window = NCWin(null);
		}

		if (!_windowBorder.isNull)
		{
			ncuiLibNotErr!delwin(_windowBorder);
			_windowBorder = NCWin(null);
		}

		_inited = false;
	}

	~this()
	{
		close();
	}
}
