module ncui.widgets.textview;

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
	bool _enabled;
	// Положение и ширина поля.
	int _y;
	int _x;
	int _width;
	int _height;
	// Устанавливаемый текст (строки).
	dstring[] _text;
	bool _border;
	// Флаг горизонтальной прокрутки.
	bool _hscroll;
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
	int _padLeft;

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

	// Использовать высоту pad равную количеству установленных строк, иначе - высоту внутреннего окна.
	int padHeight()
	{
		const int h = (_text.length > 0) ? cast(int) _text.length : 1;
		return (h < _innerH) ? _innerH : h;
	}

	// Ширина строки в "ячейках" терминала.
	int lineWidthCells(dstring line)
	{
		int w = 0;
		foreach (dchar ch; line)
		{
			w += cellWidth(ch);
		}
		return w;
	}

	// Максимальная ширина строки (в ячейках терминала).
	int maxTextWidth()
	{
		// Минимум 1, чтобы pad был валиден.
		int m = 1;

		foreach (line; _text)
		{
			const int w = lineWidthCells(line);
			if (w > m)
			{
				m = w;
			}
		}

		return m;
	}

	// Ширина pad: либо ширина окна (без hscroll), либо по самой длинной строке.
	int padWidth()
	{
		if (!_hscroll)
		{
			return _innerW;
		}

		const int m = maxTextWidth();
		return (m < _innerW) ? _innerW : m;
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
		_pad.delwin();
		_pad.newpad(padHeight(), padWidth());
		_pad.wbkgd(attr);
		_pad.werase();
		_pad.mvwaddnwstrs(_text, attr);

		_lastTextAttr = attr;
		_padDirty = false;
	}

	// Создание окна + границы.
	void ensureWindows(Window window)
	{
		_windowBorder.derwin(window.handle(), _height, _width, _y, _x);
		_windowBorder.syncok();

		_innerH = innerHeight();
		_innerW = innerWidth();

		const int offY = _border ? 1 : 0;
		const int offX = _border ? 1 : 0;

		_window.derwin(_windowBorder, _innerH, _innerW, offY, offX);
		_window.syncok();
	}

	// Скопировать холст pad на внутреннее окно.
	void blitPadToWindow()
	{
		_window.werase();
		_window.copywin(_pad, _padTop, _padLeft, 0, 0, _innerH - 1, _innerW - 1);
	}

	// Создание виджета.
	void ensureCreated(Window window, ScreenContext context, bool focused)
	{
		if (!_inited)
		{
			_padTop = 0;
			_padLeft = 0;
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
				_windowBorder.wattron(attr);
			}

			scope (exit)
			{
				if (attr != 0)
				{
					_windowBorder.wattroff(attr);
				}
			}

			_windowBorder.box(0, 0);
		}
	}

	int maxPadTop()
	{
		const int m = padHeight() - _innerH;
		return m > 0 ? m : 0;
	}

	int maxPadLeft()
	{
		if (!_hscroll)
		{
			return 0;
		}

		const int m = padWidth() - _innerW;
		return m > 0 ? m : 0;
	}

	void clampPad()
	{
		if (_padTop < 0)
		{
			_padTop = 0;
		}

		const int mt = maxPadTop();

		if (_padTop > mt)
		{
			_padTop = mt;
		}

		if (_padLeft < 0)
		{
			_padLeft = 0;
		}

		const int ml = maxPadLeft();

		if (_padLeft > ml)
		{
			_padLeft = ml;
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

	bool scrollByCols(int delta)
	{
		if (!_hscroll || !_inited || _pad.isNull || delta == 0)
		{
			return false;
		}

		const int old = _padLeft;

		_padLeft += delta;
		clampPad();

		return _padLeft != old;
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

	// Разбить текст на строки без переноса по ширине (для горизонтальной прокрутки).
	dstring[] splitTextLines(string text)
	{
		import std.string : splitLines;
		import std.utf : toUTF32;

		auto parts = text.splitLines();
		dstring[] output;

		if (parts.length == 0)
		{
			return output;
		}

		output.length = parts.length;

		foreach (i, line; parts)
		{
			output[i] = line.toUTF32();
		}

		return output;
	}

public:
	this(int y, int x, int w, int h, string text = string.init, bool border = true, bool enabled = true,
		bool hscroll = false)
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
		_enabled = enabled;
		_hscroll = hscroll;

		// Если включена горизонтальная прокрутка — строки не переносим.
		// Иначе — переносим по ширине внутреннего окна.
		if (_hscroll)
		{
			_text = splitTextLines(text);
		}
		else
		{
			_text = text.wrapWordsWide(innerWidth());
		}

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
		dstring[] more;

		if (_hscroll)
		{
			more = splitTextLines(text);
		}
		else
		{
			more = text.wrapWordsWide(innerWidth());
		}

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

		clampPad();
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

		import deimos.ncurses : KEY_UP, KEY_DOWN, KEY_PPAGE, KEY_NPAGE, KEY_HOME, KEY_END, KEY_LEFT, KEY_RIGHT;

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

		case KEY_LEFT:
			changed = scrollByCols(-1);
			break;

		case KEY_RIGHT:
			changed = scrollByCols(+1);
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
		_pad.delwin();
		_window.delwin();
		_windowBorder.delwin();

		_inited = false;
		_padDirty = true;
		_lastTextAttr = int.min;
		_padTop = 0;
		_padLeft = 0;
		_innerH = 0;
		_innerW = 0;
	}

	~this()
	{
		close();
	}
}
