module ncui.widgets.textbox;

import deimos.form;

import ncui.widgets.widget;
import ncui.core.session : Cursor;
import ncui.core.ncwin;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.lib.checks;

import std.string : toStringz, fromStringz;
import std.utf : toUTF8;
import std.algorithm : max, min;
import std.conv : to;

final class TextBox : IWidget, IWidgetClosable
{
private:
	// Поле по умолчанию активно.
	bool _enabled = true;
	// Положение и ширина поля.
	int _y;
	int _x;
	int _width;
	// Данные поля.
	dstring _text;
	// Флаг инициализации формы.
	bool _inited;
	// Позиция курсора.
	size_t _cursorPosition;
	// Максимальный буфер.
	int _buffer = 256;

	FIELD* _field;
	FIELD*[2] _fields;
	FORM* _form;
	NCWin _window;

	void driveRequest(int request)
	{
		ncuiFormNotErr!form_driver_w(_form, KEY_CODE_YES, request);
	}

	void driveChar(dchar ch)
	{
		ncuiFormNotErr!form_driver_w(_form, OK, ch);
	}

	void setCursor(ScreenContext context, bool focused)
	{
		if (!focused || !_enabled)
		{
			return;
		}

		ncuiNotErr!curs_set(Cursor.high);

		// Держать курсор на форме при активированном виджете.
		if (_form !is null)
		{
			ncuiFormNotErr!pos_form_cursor(_form);
		}
	}

	void moveCursor(size_t position)
	{
		if (_form is null)
		{
			return;
		}

		driveRequest(REQ_BEG_LINE);
		driveRequest(REQ_BEG_FIELD);

		position = min(position, _text.length);

		_cursorPosition = 0;

		for (size_t i = 0; i < position; ++i)
		{
			driveRequest(REQ_RIGHT_CHAR);
			_cursorPosition++;
		}

		driveRequest(REQ_INS_MODE);
	}

	void ensureCreated(Window window)
	{
		if (_inited)
		{
			return;
		}

		// Создание внутреннего окна.
		_window = ncuiNotNull!derwin(window.handle(), 1, _width, _y, _x);
		// Создание поля формы.
		_field = ncuiNotNull!new_field(1, _width, 0, 0, 0, 0);

		_fields[0] = _field;
		_fields[1] = null;

		// Установка атрибута фона для поля — подчеркивание.
		ncuiFormNotErr!set_field_back(_field, A_UNDERLINE);
		// Отключение опции автоперехода к следующему полю при заполнении.
		ncuiFormNotErr!field_opts_off(_field, O_AUTOSKIP);
		// Отключение статического режима поля — позволяет использовать горизонтальную прокрутку.
		ncuiFormNotErr!field_opts_off(_field, O_STATIC);
		// Установка максимального размера текста в поле (ограничение на 255 символов).
		ncuiFormNotErr!set_max_field(_field, _buffer);
		// Создание формы.
		_form = ncuiNotNull!new_form(cast(FIELD**) _fields);
		// Привязка формы к родителю.
		ncuiFormNotErr!set_form_win(_form, window.handle());
		// Привязка формы к внутреннему окну.
		ncuiFormNotErr!set_form_sub(_form, _window);
		// Публикация формы.
		ncuiFormNotErrAny!post_form([E_OK, E_POSTED], _form);
		// Перевод поля в режим вставки символа (insert mode).
		driveRequest(REQ_INS_MODE);
		// Установка текста в поле.
		ncuiFormNotErr!set_field_buffer(_field, 0, _text.toUTF8.toStringz);
		// Позиция курсора в конце текста.
		moveCursor(_text.length);

		_inited = true;
	}

public:
	this(int y, int x, int width, dstring text = dstring.init)
	{
		_y = y;
		_x = x;
		_width = width;
		_text = text;

		_cursorPosition = text.length;
	}

	dstring text()
	{
		return _text;
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
		// Создание формы и привязка к родителю.
		ensureCreated(window);
		// Настройка курсора.
		setCursor(context, focused);
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!_enabled || _form is null || isEnter(event))
		{
			return ScreenAction.none();
		}

		if (event.isKeyCode)
		{
			switch (event.ch)
			{
			case KEY_HOME:
				moveCursor(0);
				break;
			case KEY_END:
				moveCursor(_text.length);
				break;
			case KEY_LEFT:
				if (_cursorPosition == 0)
				{
					break;
				}
				driveRequest(REQ_LEFT_CHAR);
				--_cursorPosition;
				break;
			case KEY_RIGHT:
				if (_cursorPosition >= _text.length)
				{
					break;
				}
				driveRequest(REQ_RIGHT_CHAR);
				++_cursorPosition;
				break;
			case KEY_DC:
				if (_cursorPosition >= _text.length)
				{
					break;
				}
				driveRequest(REQ_DEL_CHAR);
				_text = _text[0 .. _cursorPosition] ~ _text[_cursorPosition + 1 .. $];
				break;
			case KEY_BACKSPACE:
				if (_cursorPosition == 0)
				{
					break;
				}
				driveRequest(REQ_DEL_PREV);
				_text = _text[0 .. _cursorPosition - 1] ~ _text[_cursorPosition .. $];
				--_cursorPosition;
				break;
			default:
				// Остальные управлящие символы просто гасить.
				break;
			}

			return ScreenAction.none();
		}

		if (event.isChar)
		{
			if (event.ch == 127 || event.ch == '\b')
			{
				// В случае, если курсор находится не в начале строки.
				if (_cursorPosition > 0)
				{
					driveRequest(REQ_DEL_PREV);
					_text = _text[0 .. _cursorPosition - 1] ~ _text[_cursorPosition .. $];
					--_cursorPosition;
				}
			}
			else if (_cursorPosition < _text.length)
			{
				_text = _text[0 .. _cursorPosition] ~ event.ch ~ _text[_cursorPosition .. $];
				ncuiFormNotErr!set_field_buffer(_field, 0, _text.toUTF8.toStringz);
				moveCursor(++_cursorPosition);
			}
			else
			{
				driveRequest(REQ_INS_MODE);
				driveChar(event.ch);
				_text ~= event.ch;
				++_cursorPosition;
			}

			return ScreenAction.none();
		}

		return ScreenAction.none();
	}

	override void close()
	{
		if (_form !is null)
		{
			ncuiFormNotErrAny!unpost_form([E_OK, E_NOT_POSTED], _form);
			ncuiFormNotErr!free_form(_form);
			_form = null;
		}

		if (_field !is null)
		{
			ncuiFormNotErr!free_field(_field);
			_field = null;
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
