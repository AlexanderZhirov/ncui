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

import std.string : toStringz;
import std.utf : toUTF8, toUTF32;
import std.algorithm : min;
import std.range : repeat;
import std.array : array;
import std.regex : matchFirst, regex, Regex;

final class TextBox : IWidget, IWidgetClosable
{
private:
	// Поле по умолчанию активно.
	bool _enabled = true;
	// Положение и ширина поля.
	int _y;
	int _x;
	int _width;
	// Метка поля.
	dstring _label;
	// Данные поля.
	dstring _text;
	// Наличие установленной маски.
	bool _hasMask;
	// Маска ввода.
	Regex!dchar _mask;
	// Флаг инициализации формы.
	bool _inited;
	// Позиция курсора.
	size_t _cursorPosition;
	// Максимальный буфер.
	int _buffer = 256;
	// Флаг скрытых символов.
	bool _hidden;
	// Скрытый символ.
	dchar _hiddenSymbol = '*';

	FIELD* _fieldLabel;
	FIELD* _fieldInput;
	FIELD*[3] _fields;
	FORM* _form;
	NCWin _window;

	void driveRequest(int request)
	{
		ncuiLibNotErr!form_driver_w(_form, KEY_CODE_YES, request);
	}

	void driveChar(dchar ch)
	{
		ncuiLibNotErr!form_driver_w(_form, OK, ch);
	}

	void setCursor(ScreenContext context, bool focused)
	{
		if (!focused || !_enabled)
		{
			return;
		}

		// Принудительно сделать поле ввода активным.
		ncuiLibNotErr!set_current_field(_form, _fieldInput);
		// Установка высокой видимости.
		ncuiNotErr!curs_set(Cursor.high);
		// Держать курсор на форме при активированном виджете.
		ncuiLibNotErr!pos_form_cursor(_form);
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

	void modifyField()
	{
		dstring currentText = _hidden ? _hiddenSymbol.repeat(_text.length).array.idup : _text;
		ncuiLibNotErr!set_field_buffer(_fieldInput, 0, currentText.toUTF8.toStringz);
	}

	dchar modifyChar(dchar symbol)
	{
		return _hidden ? _hiddenSymbol : symbol;
	}

	void ensureCreated(Window window)
	{
		if (_inited)
		{
			return;
		}

		// Ширина метки поля.
		int labelWidth = cast(int) _label.length;
		// Общая ширина: ширина метки поля + отступ (1) + ширина поля ввода.
		int totalWidth = (labelWidth > 0) ? (labelWidth + 1 + _width) : _width;

		// Создание внутреннего окна.
		_window = ncuiNotNull!derwin(window.handle(), 1, totalWidth, _y, _x);
		// Создание поля ввода.
		_fieldInput = ncuiNotNull!new_field(1, _width, 0, totalWidth - _width, 0, 0);

		// Если метка поля была установлена.
		if (labelWidth > 0)
		{
			// Создание метки поля.
			_fieldLabel = ncuiNotNull!new_field(1, labelWidth, 0, 0, 0, 0);
			// Установка опций для метки поля.
			ncuiLibNotErr!set_field_opts(_fieldLabel, O_VISIBLE | O_PUBLIC | O_AUTOSKIP);
			// Снять активность поля.
			ncuiLibNotErr!field_opts_off(_fieldLabel, O_ACTIVE);
			// Запретить поле для редактирования
			ncuiLibNotErr!field_opts_off(_fieldLabel, O_EDIT);
			// Установка названия метки.
			ncuiLibNotErr!set_field_buffer(_fieldLabel, 0, _label.toUTF8.toStringz);

			_fields[0] = _fieldLabel;
			_fields[1] = _fieldInput;
		}
		// Иначе отобразить только поле ввода.
		else
		{
			_fields[0] = _fieldInput;
			_fields[1] = null;
		}

		_fields[2] = null;

		// Установка атрибута фона для поля — подчеркивание.
		ncuiLibNotErr!set_field_back(_fieldInput, A_UNDERLINE);
		// Отключение опции автоперехода к следующему полю при заполнении.
		ncuiLibNotErr!field_opts_off(_fieldInput, O_AUTOSKIP);
		// Отключение статического режима поля — позволяет использовать горизонтальную прокрутку.
		ncuiLibNotErr!field_opts_off(_fieldInput, O_STATIC);
		// Установка максимального размера текста в поле (ограничение на 255 символов).
		ncuiLibNotErr!set_max_field(_fieldInput, _buffer);
		// Создание формы.
		_form = ncuiNotNull!new_form(cast(FIELD**) _fields);
		// Привязка формы к родителю.
		ncuiLibNotErr!set_form_win(_form, window.handle());
		// Привязка формы к внутреннему окну.
		ncuiLibNotErr!set_form_sub(_form, _window);
		// Публикация формы.
		ncuiLibNotErrAny!post_form([E_OK, E_POSTED], _form);
		// Перевод поля в режим вставки символа (insert mode).
		driveRequest(REQ_INS_MODE);
		// Установка текста в поле.
		modifyField();
		// Позиция курсора в конце текста.
		moveCursor(_text.length);

		_inited = true;
	}

	bool allowedChar(dchar symbol)
	{
		if (!_hasMask)
		{
			return true;
		}

		dchar[1] line = symbol;
		return !matchFirst(line[], _mask).empty;
	}

public:
	this(int y, int x, int width, bool hidden,
		string label = string.init,
		string initText = string.init,
		string mask = string.init)
	{
		// Ширина обязана быть ненулевой.
		ncuiExpectMsg!((int w) => w > 0)("TextBox.width must be > 0", true, width);

		_y = y;
		_x = x;
		_width = width;
		_label = label.length ? label.toUTF32 ~ ":" : "";
		_text = initText.toUTF32;
		_hidden = hidden;

		if (mask.length)
		{
			_mask = regex(mask.toUTF32);
			_hasMask = true;
		}
		else
		{
			_hasMask = false;
		}

		_cursorPosition = _text.length;
	}

	string text()
	{
		return _text.toUTF8;
	}

	override @property bool focusable()
	{
		return true;
	}

	override @property bool enabled()
	{
		return _enabled;
	}

	void hideText(bool hidden)
	{
		_hidden = hidden;

		if (!_inited)
		{
			return;
		}

		modifyField();
		moveCursor(_cursorPosition);
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
				if (_cursorPosition < _text.length)
				{
					driveRequest(REQ_RIGHT_CHAR);
					++_cursorPosition;
				}
				break;
			case KEY_DC:
				if (_cursorPosition < _text.length)
				{
					driveRequest(REQ_DEL_CHAR);
					_text = _text[0 .. _cursorPosition] ~ _text[_cursorPosition + 1 .. $];
					// Если когда-нибудь сломается hidden-режим — раскомментировать.
					// if (_hidden)
					// {
					// 	modifyField();
					// 	moveCursor(_cursorPosition);
					// }
				}
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
			// Чтобы не поймать расхождение данных с формой.
		else if (_text.length < _buffer && allowedChar(event.ch))
			{
				if (_cursorPosition < _text.length)
				{
					_text = _text[0 .. _cursorPosition] ~ event.ch ~ _text[_cursorPosition .. $];
					modifyField();
					moveCursor(++_cursorPosition);
				}
				else
				{
					driveRequest(REQ_INS_MODE);
					driveChar(modifyChar(event.ch));
					_text ~= event.ch;
					++_cursorPosition;
				}
			}

			return ScreenAction.none();
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

		if (_fieldLabel !is null)
		{
			ncuiLibNotErr!free_field(_fieldLabel);
			_fieldLabel = null;
		}

		if (_fieldInput !is null)
		{
			ncuiLibNotErr!free_field(_fieldInput);
			_fieldInput = null;
		}

		_fields[0] = null;
		_fields[1] = null;
		_fields[2] = null;

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
