module ncui.widgets.textview;

import deimos.form;

import ncui.widgets.widget;
import ncui.core.window;
import ncui.core.event;
import ncui.core.ncwin;
import ncui.engine.screen;
import ncui.engine.action;
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

	FIELD* _fieldText;
	FIELD*[2] _fields;
	FORM* _form;
	NCWin _window;

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
		if (!_inited || deltaLines == 0) return;

		driveRepeat(deltaLines > 0 ? REQ_SCR_FLINE : REQ_SCR_BLINE,
					cast(uint)(deltaLines > 0 ? deltaLines : -deltaLines));
	}

	void scrollByPages(int deltaPages)
	{
		if (!_inited || deltaPages == 0) return;

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

	void ensureCreated(Window window)
	{
		if (_inited)
		{
			return;
		}

		_window = ncuiNotNull!derwin(window.handle(), _height, _width, _y, _x);

		_fieldText = ncuiNotNull!new_field(_height, _width, 0, 0, 0, 0);
		_fields[0] = _fieldText;
		_fields[1] = null;

		ncuiLibNotErr!field_opts_off(_fieldText, O_STATIC);
		ncuiLibNotErr!set_max_field(_fieldText, _bufferSize);

		ncuiLibNotErr!field_opts_off(_fieldText, O_AUTOSKIP);
		ncuiLibNotErr!field_opts_on(_fieldText, O_WRAP);

		_form = ncuiNotNull!new_form(_fields.ptr);

		ncuiLibNotErr!set_form_win(_form, window.handle());
		ncuiLibNotErr!set_form_sub(_form, _window);

		// ncuiLibNotErr!field_opts_off(_fieldText, O_EDIT);

		ncuiLibNotErrAny!post_form([E_OK, E_POSTED], _form);

		// Заполнение поля текстом.
		fillField();

		_inited = true;
	}

public:
	this(int y, int x, int width, int height, string text = string.init, int bufferSize = 64 * 1024)
	{
		ncuiExpectMsg!((int w) => w > 0)("TextView.width must be > 0", true, width);
		ncuiExpectMsg!((int h) => h > 0)("TextView.height must be > 0", true, height);

		_y = y;
		_x = x;
		_width = width;
		_height = height;

		_bufferSize = bufferSize > 0 ? bufferSize : 1024;
		_text = text.toUTF32;
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
		ensureCreated(window);
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

		_inited = false;
	}

	~this()
	{
		close();
	}
}
