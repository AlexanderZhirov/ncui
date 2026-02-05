module ncui.widgets.textbox;

import deimos.form;

import ncui.widgets.widget;
import ncui.core.session : Cursor;
import ncui.core.ncwin;
import ncui.core.ncform;
import ncui.core.window;
import ncui.core.event;
import ncui.engine.screen;
import ncui.engine.action;
import ncui.engine.theme;
import ncui.lib.checks;

import std.utf : toUTF8, toUTF32;
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

	NCField _fieldLabel;
	NCField _fieldInput;
	NCField[2] _fields;
	NCForm _form;
	NCWin _window;

	void driveRequest(int request)
	{
		_form.formdriverw(KEY_CODE_YES, request);
	}

	void driveChar(dchar ch)
	{
		_form.formdriverw(OK, ch);
	}

	dchar modifyChar(dchar symbol)
	{
		return _hidden ? _hiddenSymbol : symbol;
	}

	void moveCursor(size_t position)
	{
		if (_form.isNull)
		{
			return;
		}

		// Возврат курсора в начало строки.
		// Используется данный метод, т.к. REQ_BEG_LINE/REQ_BEG_FIELD режут ведущие пробелы.
		while (_form.formdriverw(KEY_CODE_YES, REQ_LEFT_CHAR, [E_OK, E_REQUEST_DENIED]) == E_OK) {}
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
		_fieldInput.setfieldbuffer(currentText.toUTF8);
	}

	bool isCtrlChar(dchar ch)
	{
		// ASCII control: 0x00..0x1F и DEL(0x7F)
		// Сюда входят Ctrl+A..Z (1..26), Tab(9), Enter(10/13), Esc(27) и т.д.
		return (ch <= 0x1F) || (ch == 0x7F);
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
		_window.derwin(window.handle(), 1, _widthTotal, _y, _x);
		_window.syncok();
		// Создание поля ввода.
		_fieldInput.newfield(1, _widthField, 0, _widthTotal - _widthField, 0, 0);

		// Если метка поля была установлена.
		if (_widthLabel > 0)
		{
			// Создание метки поля.
			_fieldLabel.newfield(1, _widthLabel, 0, 0, 0, 0);
			// Установка опций для метки поля.
			_fieldLabel.setfieldopts(O_VISIBLE | O_PUBLIC | O_AUTOSKIP);
			// Снять активность поля, запретить поле для редактирования.
			_fieldLabel.fieldoptsoff(O_ACTIVE | O_EDIT);
			// Установка названия метки.
			_fieldLabel.setfieldbuffer(_label.toUTF8);

			_fields[0] = _fieldLabel;
			_fields[1] = _fieldInput;
		}
		// Иначе отобразить только поле ввода.
		else
		{
			_fields[0] = _fieldInput;
			_fields[1] = null;
		}

		// Отключение опции автоперехода к следующему полю при заполнении.
		// Отключение статического режима поля — позволяет использовать горизонтальную прокрутку.
		// Выключить удаление ведущих пробелов.
		_fieldInput.fieldoptsoff(O_AUTOSKIP | O_STATIC | O_BLANK);
		// Установка максимального размера текста в поле (ограничение на 255 символов).
		_fieldInput.setmaxfield(_buffer);
		// Создание формы.
		_form.newform(_fields);
		// Привязка формы к родителю.
		_form.setformwin(window.handle());
		// Привязка формы к внутреннему окну.
		_form.setformsub(_window);
		// Публикация формы.
		_form.postform();
		// Перевод поля в режим вставки символа (insert mode).
		driveRequest(REQ_INS_MODE);
		// Установка данных в поле формы.
		modifyField();

		_inited = true;
	}

	void applyTheme(ScreenContext context, bool focused)
	{
		if (!_inited || _form.isNull || _fieldInput.isNull)
		{
			return;
		}

		if (!_fieldLabel.isNull)
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

			_fieldLabel.setfieldfore(lattr);
			_fieldLabel.setfieldback(lattr);
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

		_fieldInput.setfieldfore(attr);
		_fieldInput.setfieldback(attr);

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

		if (!_inited || _form.isNull || _fieldInput.isNull)
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
		if (!_enabled || _form.isNull || _fieldInput.isNull)
		{
			return;
		}

		_form.setcurrentfield(_fieldInput);
		ncuiNotErr!curs_set(Cursor.high);
		_form.posformcursor();
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
		if (!_enabled || _form.isNull || isEnter(event))
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
			else if (isCtrlChar(event.ch))
			{
				return ScreenAction.none();
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
		_form.unpostform();
		_form.freeform();

		_fieldLabel.freefield();
		_fieldInput.freefield();

		_window.delwin();

		_inited = false;
	}

	~this()
	{
		close();
	}
}
