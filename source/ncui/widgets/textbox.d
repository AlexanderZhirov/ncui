module ncui.widgets.textbox;

import deimos.form;

import ncui.widgets.widget;
import ncui.core.session : Cursor;
import ncui.core.ncwin;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;
import ncui.lib.checks;

import std.string : toStringz, fromStringz;
import std.utf : toUTF8, toUTF32;
import std.algorithm : min;
import std.range : repeat;
import std.array : array;
import std.regex : matchFirst, regex, Regex;

final class TextBox : IWidget, IWidgetClosable, ICursorOwner
{
private:
	// Поле по умолчанию активно.
	bool _enabled;
	// Положение.
	int _y;
	int _x;
	// Ширина метки поля.
	int _widthLabel;
	// Ширина поля.
	int _widthField;
	// Общая ширина.
	int _widthTotal;
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
	// Количество введенных символов в поле.
	size_t _length;
	// Максимальный буфер.
	int _buffer = 256;
	// Флаг скрытых символов.
	bool _hidden;
	// Скрытый символ.
	dchar _hiddenSymbol = '*';
	// Фокус текущего поля.
	bool _focused;

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

	dchar modifyChar(dchar symbol)
	{
		return _hidden ? _hiddenSymbol : symbol;
	}

	void moveCursor(size_t position)
	{
		if (_form is null)
		{
			return;
		}

		// Возврат курсора в начало строки.
		// Используется данный метод, т.к. REQ_BEG_LINE/REQ_BEG_FIELD режут ведущие пробелы.
		while (ncuiLibNotErrAny!form_driver_w([E_OK, E_REQUEST_DENIED], _form, KEY_CODE_YES, REQ_LEFT_CHAR) == E_OK) {}
		_cursorPosition = 0;

		if (position == 0)
		{
			return;
		}

		for (size_t i = 0; i < position; ++i)
		{
			driveRequest(REQ_RIGHT_CHAR);
			_cursorPosition++;
		}

		driveRequest(REQ_INS_MODE);
	}

	void modifyField()
	{
		dstring currentText = _hidden ? _hiddenSymbol.repeat(_length).array.idup : _text;
		ncuiLibNotErr!set_field_buffer(_fieldInput, 0, currentText.toUTF8.toStringz);
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

	void ensureCreated(Window window)
	{
		if (_inited)
		{
			return;
		}

		// Создание внутреннего окна.
		_window = ncuiNotNull!derwin(window.handle(), 1, _widthTotal, _y, _x);
		ncuiNotErr!syncok(_window, true);
		// Создание поля ввода.
		_fieldInput = ncuiNotNull!new_field(1, _widthField, 0, _widthTotal - _widthField, 0, 0);

		// Если метка поля была установлена.
		if (_widthLabel > 0)
		{
			// Создание метки поля.
			_fieldLabel = ncuiNotNull!new_field(1, _widthLabel, 0, 0, 0, 0);
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

		// Отключение опции автоперехода к следующему полю при заполнении.
		ncuiLibNotErr!field_opts_off(_fieldInput, O_AUTOSKIP);
		// Отключение статического режима поля — позволяет использовать горизонтальную прокрутку.
		ncuiLibNotErr!field_opts_off(_fieldInput, O_STATIC);
		// Выключить удаление ведущих пробелов.
		ncuiLibNotErr!field_opts_off(_fieldInput, O_BLANK);
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
		// Установка данных в поле формы.
		modifyField();

		_inited = true;
	}

	void applyTheme(ScreenContext context, bool focused)
	{
		if (!_inited || _form is null || _fieldInput is null)
		{
			return;
		}

		if (_fieldLabel !is null)
		{
			StyleId lid;

			if (!_enabled)
			{
				lid = StyleId.TextBoxLabelInactive;
			}
			else
			{
				lid = StyleId.TextBoxLabel;
			}

			const int lattr = context.theme.attr(lid);

			ncuiLibNotErr!set_field_fore(_fieldLabel, lattr);
			ncuiLibNotErr!set_field_back(_fieldLabel, lattr);
		}

		StyleId iid;

		if (!_enabled)
		{
			iid = StyleId.TextBoxInputInactive;
		}
		else if (focused)
		{
			iid = StyleId.TextBoxInputActive;
		}
		else
		{
			iid = StyleId.TextBoxInput;
		}

		const int attr = context.theme.attr(iid);

		ncuiLibNotErr!set_field_fore(_fieldInput, attr);
		ncuiLibNotErr!set_field_back(_fieldInput, attr);

		// Не перерисовывать курсор лишний раз, если поле активно.
		if (_focused != focused)
		{
			moveCursor(_cursorPosition);
			_focused = focused;
		}
	}

public:
	this(int y, int x, int w, bool hidden,
		string label = string.init,
		string initText = string.init,
		string mask = string.init,
		bool e = true)
	{
		// Ширина обязана быть ненулевой.
		ncuiExpectMsg!((int value) => value > 0)("TextBox.width must be > 0", true, w);

		_y = y;
		_x = x;

		_label = label.length ? label.toUTF32 ~ ":" : "";
		_text = initText.toUTF32;
		_hidden = hidden;

		// Ширина метки поля.
		_widthLabel = cast(int) _label.length;
		// Ширина поля ввода.
		_widthField = w;
		// Общая ширина: ширина метки поля + отступ (1) + ширина поля ввода.
		_widthTotal = (_widthLabel > 0) ? (_widthLabel + 1 + _widthField) : _widthField;

		if (mask.length)
		{
			_mask = regex(mask.toUTF32);
			_hasMask = true;
		}
		else
		{
			_hasMask = false;
		}

		_length = _text.length;
		_cursorPosition = _length;
		_enabled = e;
	}

	void setEnabled(bool e)
	{
		_enabled = e;
	}

	@property int width()
	{
		return _widthTotal;
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

	void setText(string newText)
	{
		_text = newText.toUTF32;

		_length = _text.length;
		_cursorPosition = _length;

		if (!_inited || _form is null || _fieldInput is null)
		{
			return;
		}

		modifyField();
	}

	void hideText(bool hidden)
	{
		_hidden = hidden;

		if (!_inited)
		{
			return;
		}

		modifyField();
	}

	// При фокусе виджет получает курсор после отрисовки всех виджетов.
	override void placeCursor(ScreenContext context)
	{
		if (!_enabled || _form is null || _fieldInput is null)
		{
			return;
		}

		ncuiLibNotErrAny!set_current_field([E_OK, E_CURRENT], _form, _fieldInput);
		ncuiNotErr!curs_set(Cursor.high);
		ncuiLibNotErr!pos_form_cursor(_form);
	}

	override void render(Window window, ScreenContext context, bool focused)
	{
		// Создание формы и привязка к родителю.
		ensureCreated(window);
		// Применение темы.
		applyTheme(context, focused);
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (!_enabled || _form is null || isEnter(event))
		{
			return ScreenAction.none();
		}

		bool validation = false;

		if (event.isKeyCode)
		{
			switch (event.ch)
			{
			case KEY_HOME:
				moveCursor(0);
				break;
			case KEY_END:
				moveCursor(_length);
				break;
			case KEY_LEFT:
				if (_cursorPosition > 0)
				{
					driveRequest(REQ_LEFT_CHAR);
					--_cursorPosition;
				}
				break;
			case KEY_RIGHT:
				if (_cursorPosition < _length)
				{
					driveRequest(REQ_RIGHT_CHAR);
					++_cursorPosition;
				}
				break;
			case KEY_DC:
				if (_cursorPosition < _length)
				{
					_text = _text[0 .. _cursorPosition] ~ _text[_cursorPosition + 1 .. $];

					driveRequest(REQ_DEL_CHAR);
					--_length;

					validation = true;
				}
				break;
			case KEY_BACKSPACE:
				if (_cursorPosition > 0)
				{
					_text = _text[0 .. _cursorPosition - 1] ~ _text[_cursorPosition .. $];

					driveRequest(REQ_DEL_PREV);
					--_cursorPosition;
					--_length;

					validation = true;
				}
				break;
			default:
				// Остальные управлящие символы просто гасить.
				break;
			}
		}
		else if (event.isChar)
		{
			if (event.ch == 127 || event.ch == '\b')
			{
				if (_cursorPosition > 0)
				{
					_text = _text[0 .. _cursorPosition - 1] ~ _text[_cursorPosition .. $];

					driveRequest(REQ_DEL_PREV);
					--_cursorPosition;
					--_length;

					validation = true;
				}
			}
			else if (_length < _buffer && allowedChar(event.ch))
			{
				if (_cursorPosition < _length)
				{
					_text = _text[0 .. _cursorPosition] ~ event.ch ~ _text[_cursorPosition .. $];
				}
				else
				{
					_text ~= event.ch;
				}

				driveChar(modifyChar(event.ch));
				++_length;
				++_cursorPosition;

				validation = true;
			}
		}

		if (validation)
		{
			driveRequest(REQ_VALIDATION);
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
