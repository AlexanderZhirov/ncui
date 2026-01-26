module ncui.widgets.textview;

import deimos.form;
import deimos.ncurses;

import ncui.widgets.widget;
import ncui.core.window;
import ncui.core.event;
import ncui.core.ncwin;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;
import ncui.lib.checks;

import std.utf : toUTF32;

private enum dstring NL = "\n".toUTF32;

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
	// Флаг инициализации формы.
	bool _inited;
	// Максимальный размер динамического буфера поля.
	int _bufferSize;
	// Устанавливаемый текст.
	dstring _text;

	bool _border = true;

	FIELD* _fieldText;
	FIELD*[2] _fields;
	FORM* _form;
	NCWin _window;
	NCWin _windowBorder;

	int driveRequestAllowDenied(int request)
	{
		return ncuiLibNotErrAny!form_driver_w([E_OK, E_REQUEST_DENIED], _form, KEY_CODE_YES, request);
	}

	void driveRepeat(int request, uint steps)
	{
		foreach (_; 0 .. steps)
		{
			if (driveRequestAllowDenied(request) == E_REQUEST_DENIED)
			{
				break;
			}
		}
	}

	void scrollByLines(int deltaLines)
	{
		if (!_inited || deltaLines == 0)
		{
			return;
		}

		driveRepeat(deltaLines > 0 ? REQ_SCR_FLINE : REQ_SCR_BLINE,
			cast(uint)(deltaLines > 0 ? deltaLines : -deltaLines));
	}

	void scrollByPages(int deltaPages)
	{
		if (!_inited || deltaPages == 0)
		{
			return;
		}

		driveRepeat(deltaPages > 0 ? REQ_SCR_FPAGE : REQ_SCR_BPAGE,
			cast(uint)(deltaPages > 0 ? deltaPages : -deltaPages));
	}

	void scrollToTop()
	{
		if (!_inited)
		{
			return;
		}

		driveRequestAllowDenied(REQ_BEG_FIELD);
		driveRequestAllowDenied(REQ_BEG_LINE);
	}

	void scrollToEnd()
	{
		if (!_inited)
		{
			return;
		}

		driveRequestAllowDenied(REQ_END_FIELD);
		driveRequestAllowDenied(REQ_END_LINE);
	}

	// Очистка формы.
	void cleanForm()
	{
		driveRequestAllowDenied(REQ_CLR_FIELD);
		driveRequestAllowDenied(REQ_BEG_FIELD);
		driveRequestAllowDenied(REQ_BEG_LINE);
	}

	// Непосредственная вставка текста в поле.
	void putText(dstring text)
	{
		foreach (dchar ch; text)
		{
			if (ch == '\r')
			{
				continue;
			}

			if (ch == '\n')
			{
				const int result = driveRequestAllowDenied(REQ_NEW_LINE);
				// Прекратить вставку, если буфер переполнен.
				if (result == E_REQUEST_DENIED)
				{
					break;
				}
				continue;
			}

			const int result = ncuiLibNotErrAny!form_driver_w([E_OK, E_REQUEST_DENIED], _form, OK, ch);
			// Прекратить вставку, если буфер переполнен.
			if (result == E_REQUEST_DENIED)
			{
				break;
			}
		}
	}

	void appendField(dstring text)
	{
		if (!_inited || _fieldText is null)
		{
			return;
		}

		// Установить поле текущим в форме.
		ncuiLibNotErrAny!set_current_field([E_OK, E_CURRENT], _form, _fieldText);

		driveRequestAllowDenied(REQ_END_FIELD);
		driveRequestAllowDenied(REQ_END_LINE);
		driveRequestAllowDenied(REQ_NEXT_LINE);
		driveRequestAllowDenied(REQ_BEG_LINE);
		// Посимвольная вставка текста.
		putText(text);
	}

	// Посимвольное заполнение поля, позволяющее автоматически переносить слова на новую строку.
	void fillField()
	{
		// Установить поле текущим в форме.
		ncuiLibNotErrAny!set_current_field([E_OK, E_CURRENT], _form, _fieldText);

		// Очистить поле формы перед заполнением текстом.
		cleanForm();
		// Посимвольная вставка текста.
		putText(_text);

		driveRequestAllowDenied(REQ_BEG_FIELD);
		driveRequestAllowDenied(REQ_BEG_LINE);
	}

	void setupTheme(ScreenContext context, bool focused)
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

		auto attr = context.theme.attr(style);

		ncuiLibNotErr!set_field_fore(_fieldText, attr);
		ncuiLibNotErr!set_field_back(_fieldText, attr);
	}

	void ensureCreated(Window window, ScreenContext context)
	{
		if (_inited)
		{
			return;
		}

		// Окно с рамкой.
		_windowBorder = ncuiNotNull!derwin(window.handle(), _height, _width, _y, _x);

		const int innerH = _border ? _height - 2 : _height;
		const int innerW = _border ? _width - 2 : _width;
		const int offY = _border ? 1 : 0;
		const int offX = _border ? 1 : 0;

		_window = ncuiNotNull!derwin(_windowBorder, innerH, innerW, offY, offX);

		_fieldText = ncuiNotNull!new_field(innerH, innerW, 0, 0, 0, 0);
		_fields[0] = _fieldText;
		_fields[1] = null;

		ncuiLibNotErr!field_opts_off(_fieldText, O_STATIC);
		ncuiLibNotErr!set_max_field(_fieldText, _bufferSize);

		ncuiLibNotErr!field_opts_off(_fieldText, O_AUTOSKIP);
		ncuiLibNotErr!field_opts_on(_fieldText, O_WRAP);

		_form = ncuiNotNull!new_form(_fields.ptr);

		ncuiLibNotErr!set_form_win(_form, _windowBorder);
		ncuiLibNotErr!set_form_sub(_form, _window);

		ncuiLibNotErrAny!post_form([E_OK, E_POSTED], _form);

		setupTheme(context, false);

		// Заполнение поля текстом.
		fillField();

		_inited = true;
	}

	void applyTheme(ScreenContext context, bool focused)
	{
		if (_fieldText !is null)
		{
			setupTheme(context, focused);
		}

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
					ncuiNotErr!wattroff(_windowBorder, attr);
			}

			ncuiNotErr!box(_windowBorder, 0, 0);
		}
	}

public:
	this(int y, int x, int w, int h, string text = string.init, bool border = true, int bufferSize = 64 * 1024)
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

		_bufferSize = bufferSize > 0 ? bufferSize : 1024;
		_text = text.toUTF32;
	}

	@property int width()
	{
		return _width;
	}

	@property int height()
	{
		return _height;
	}

	void set(string text)
	{
		_text = text.toUTF32;

		if (!_inited || _fieldText is null)
		{
			return;
		}

		fillField();
	}

	void append(string text)
	{
		auto currentText = text.toUTF32;

		if (_text.length != 0)
		{
			_text ~= NL;
			appendField(NL);
		}

		_text ~= currentText;
		appendField(currentText);
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
		ensureCreated(window, context);
		applyTheme(context, focused);
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!_enabled || !_inited || _form is null || !event.isKeyCode)
		{
			return ScreenAction.none();
		}

		switch (event.ch)
		{
		case KEY_UP:
			scrollByLines(-1);
			break;
		case KEY_DOWN:
			scrollByLines(+1);
			break;
		case KEY_PPAGE:
			scrollByPages(-1);
			break;
		case KEY_NPAGE:
			scrollByPages(+1);
			break;
		case KEY_HOME:
			scrollToTop();
			break;
		case KEY_END:
			scrollToEnd();
			break;
		default:
			break;
		}

		return ScreenAction.none();
	}

	override void close()
	{
		if (_form !is null)
		{
			ncuiLibNotErrAny!unpost_form([E_OK, E_NOT_POSTED], _form);
			ncuiLibNotErr!free_form(_form);
			_form = null;
		}

		if (_fieldText !is null)
		{
			ncuiLibNotErr!free_field(_fieldText);
			_fieldText = null;
		}

		_fields[0] = null;
		_fields[1] = null;

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
	}

	~this()
	{
		close();
	}
}
