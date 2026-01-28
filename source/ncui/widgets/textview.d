module ncui.widgets.textview;

import deimos.ncurses;

import ncui.widgets.widget;
import ncui.core.window;
import ncui.core.event;
import ncui.core.ncwin;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;
import ncui.lib.checks;
import ncui.lib.wrap;

final class TextView : IWidget, IWidgetClosable
{
private:
	// Поле по умолчанию активно.
	bool _enabled = true;
	// Положение и ширина поля.
	int _y;
	int _x;
	int _width;
	int _height;
	// Устанавливаемый текст.
	dstring[] _text;
	bool _border;
	// Флаг инициализации формы.
	bool _inited;

	// Окно с рамкой.
	NCWin _windowBorder;
	// Окно, на которое копируются данные из холста pad.
	NCWin _window;
	NCWin _pad;

	// Высота и ширина внутреннего окна _window.
	int _innerH;
	int _innerW;

	// Позиция просмотра pad.
	int _padTop;

	// Чтобы не перерисовывать pad на каждом render().
	bool _padDirty = true;
	int _lastTextAttr = int.min;

	// Ширина внутреннего окна.
	int innerWidth()
	{
		return _border ? _width - 2 : _width;
	}

	// Высота внутреннего окна.
	int innerHeight()
	{
		return _border ? _height - 2 : _height;
	}

	// Получить текущие атрибуты виджета.
	int textAttr(ScreenContext context, bool focused)
	{
		StyleId style;

		if (!_enabled)
		{
			style = StyleId.TextViewInactive;
		}
		else if (focused)
		{
			style = StyleId.TextViewActive;
		}
		else
		{
			style = StyleId.TextView;
		}

		return context.theme.attr(style);
	}

	// Использовать высоту pad равную количество установленных строк, иначе - высоту внутреннего окна.
	int padHeight()
	{
		const int h = (_text.length > 0) ? cast(int) _text.length : 1;
		return (h < _innerH) ? _innerH : h;
	}

	// Создание pad.
	void ensurePad(ScreenContext context, bool focused)
	{
		const int attr = textAttr(context, focused);

		// Если изменился стиль (например focus/unfocus) — pad надо пересобрать.
		if (attr != _lastTextAttr)
		{
			_padDirty = true;
		}

		// Если pad существует и не изменился — возврат.
		if (!_pad.isNull && !_padDirty)
		{
			return;
		}

		// Если pad существует — пересобрать с существующими изменениями (_padDirty == true).
		if (!_pad.isNull)
		{
			ncuiNotErr!delwin(_pad);
			_pad = NCWin(null);
		}

		_pad = ncuiNotNull!newpad(padHeight(), _innerW);

		ncuiNotErr!wbkgd(_pad, attr);
		ncuiNotErr!werase(_pad);

		if (attr != 0)
		{
			ncuiNotErr!wattron(_pad, attr);
		}

		scope (exit)
		{
			if (attr != 0)
			{
				ncuiNotErr!wattroff(_pad, attr);
			}
		}

		foreach (i, line; _text)
		{
			if (line.length == 0)
			{
				ncuiNotErr!wmove(_pad, cast(int)i, 0);
				continue;
			}

			ncuiNotErr!mvwaddnwstr(_pad, cast(int) i, 0, line.ptr, cast(int) line.length);
		}

		_lastTextAttr = attr;
		_padDirty = false;
	}

	// Создание окна + границы.
	void ensureWindows(Window window)
	{
		_windowBorder = ncuiNotNull!derwin(window.handle(), _height, _width, _y, _x);
		ncuiNotErr!syncok(_windowBorder, true);

		_innerH = innerHeight();
		_innerW = innerWidth();

		const int offY = _border ? 1 : 0;
		const int offX = _border ? 1 : 0;

		_window = ncuiNotNull!derwin(_windowBorder, _innerH, _innerW, offY, offX);
		ncuiNotErr!syncok(_window, true);
	}

	// Скопировать холст pad на внутреннее окно.
	void blitPadToWindow()
	{
		ncuiNotErr!werase(_window);
		ncuiNotErr!copywin(_pad, _window, _padTop, 0, 0, 0, _innerH - 1, _innerW - 1, 0);
	}

	// Создание виджета.
	void ensureCreated(Window window, ScreenContext context, bool focused)
	{
		if (!_inited)
		{
			_padTop = 0;
			ensureWindows(window);
			_inited = true;
		}

		ensurePad(context, focused);
		clampPad();
		blitPadToWindow();
	}

	// Применение темы.
	void applyTheme(ScreenContext context, bool focused)
	{
		if (_border)
		{
			const int attr = context.theme.attr(focused ? StyleId.BorderActive : StyleId.BorderInactive);

			if (attr != 0)
			{
				ncuiNotErr!wattron(_windowBorder, attr);
			}

			scope (exit)
			{
				if (attr != 0)
				{
					ncuiNotErr!wattroff(_windowBorder, attr);
				}
			}

			ncuiNotErr!box(_windowBorder, 0, 0);
		}
	}

	int maxPadTop()
	{
		const int m = padHeight() - _innerH;
		return m > 0 ? m : 0;
	}

	void clampPad()
	{
		if (_padTop < 0)
		{
			_padTop = 0;
		}

		const int m = maxPadTop();

		if (_padTop > m)
		{
			_padTop = m;
		}
	}

	bool scrollByLines(int delta)
	{
		if (!_inited || _pad.isNull || delta == 0)
		{
			return false;
		}

		const int old = _padTop;

		_padTop += delta;
		clampPad();

		return _padTop != old;
	}

	int pageStep()
	{
		return (_innerH > 1) ? (_innerH - 1) : 1;
	}

	bool scrollTo(int top)
	{
		if (!_inited || _pad.isNull)
		{
			return false;
		}

		const int old = _padTop;

		_padTop = top;
		clampPad();

		return _padTop != old;
	}

public:
	this(int y, int x, int w, int h, string text = string.init, bool border = true)
	{
		if (border)
		{
			ncuiExpectMsg!((int value) => value >= 3)("TextView.height must be >= 3 when border=true", true, h);
			ncuiExpectMsg!((int value) => value >= 3)("TextView.width must be >= 3 when border=true", true, w);
		}
		else
		{
			ncuiExpectMsg!((int value) => value > 0)("TextView.width must be > 0", true, w);
			ncuiExpectMsg!((int value) => value > 0)("TextView.height must be > 0", true, h);
		}

		_y = y;
		_x = x;
		_width = w;
		_height = h;

		_border = border;

		_text = text.wrapWordsWide(innerWidth());
		_padDirty = true;
	}

	@property int width()
	{
		return _width;
	}

	@property int height()
	{
		return _height;
	}

	void append(string text)
	{
		auto more = text.wrapWordsWide(innerWidth());
		if (more.length == 0)
		{
			return;
		}

		if (!_inited)
		{
			_text ~= more;
			_padDirty = true;
			return;
		}

		const bool wasAtBottom = (_padTop >= maxPadTop());

		_text ~= more;
		_padDirty = true;

		if (wasAtBottom)
		{
			_padTop = maxPadTop();
		}
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
		ensureCreated(window, context, focused);
		applyTheme(context, focused);
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!event.isKeyCode)
		{
			return ScreenAction.none();
		}

		bool changed = false;

		switch (event.ch)
		{
		case KEY_UP:
			changed = scrollByLines(-1);
			break;

		case KEY_DOWN:
			changed = scrollByLines(+1);
			break;

		case KEY_PPAGE:
			changed = scrollByLines(-pageStep());
			break;

		case KEY_NPAGE:
			changed = scrollByLines(+pageStep());
			break;

		case KEY_HOME:
			changed = scrollTo(0);
			break;

		case KEY_END:
			changed = scrollTo(maxPadTop());
			break;

		default:
			break;
		}

		if (changed)
		{
			blitPadToWindow();
		}

		return ScreenAction.none();
	}

	override void close()
	{
		if (!_pad.isNull)
		{
			ncuiLibNotErr!delwin(_pad);
			_pad = NCWin(null);
		}

		if (!_window.isNull)
		{
			ncuiNotErr!delwin(_window);
			_window = NCWin(null);
		}

		if (!_windowBorder.isNull)
		{
			ncuiLibNotErr!delwin(_windowBorder);
			_windowBorder = NCWin(null);
		}

		_inited = false;
		_padDirty = true;
		_lastTextAttr = int.min;
		_padTop = 0;
		_innerH = 0;
		_innerW = 0;
	}

	~this()
	{
		close();
	}
}
