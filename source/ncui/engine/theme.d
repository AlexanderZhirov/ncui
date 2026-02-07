module ncui.engine.theme;

import deimos.ncurses;

import ncui.lib.checks;

/**
 * Идентификаторы стилей, которыми пользуется UI.
 */
enum StyleId
{
	// Фон окон.
	WindowBackground,
	WindowBorderActive,
	WindowBorderInactive,
	// Обычный текст интерфейса.
	Text,
	// Вторичный/приглушённый текст.
	Muted,
	// Заголовки.
	Title,
	// Граница неактивного окна/виджета (не в фокусе).
	BorderInactive,
	// Граница активного окна/виджета (в фокусе/активное).
	BorderActive,
	// Ошибка/критичные сообщения.
	Error,
	// Акцент (выделение важного).
	Accent,

	// Кнопка в обычном состоянии.
	Button,
	// Кнопка в фокусе/активная.
	ButtonActive,
	// Кнопка выключенная (disabled).
	ButtonInactive,

	// Флажок в обычном состоянии.
	Checkbox,
	// Флажок в фокусе/активный.
	CheckboxActive,
	// Флажок выключенный (disabled).
	CheckboxInactive,

	TextBoxLabel,
	TextBoxLabelInactive,

	TextBoxInput,
	TextBoxInputActive,
	TextBoxInputInactive,

	TextView,
	TextViewActive,
	TextViewInactive,

	MenuItem,
	MenuItemActive,
	MenuItemInactive,

	ListBoxItem,
	ListBoxItemActive,
	ListBoxItemInactive,
	ListBoxItemSelect,
}

/**
 * Внутренние слоты color-pair.
 */
enum PairSlot : short
{
	// Базовые пары.
	Normal = 1,
	Muted = 2,
	Accent = 3,
	// Границы окна
	WindowBorderActive = 4,
	WindowBorderInactive = 5,
	// Границы.
	BorderActive = 6,
	BorderInactive = 7,
	// Ошибки
	Error = 8,
	// Кнопки.
	Button = 9,
	ButtonActive = 10,
	ButtonInactive = 11,
	// Флажок.
	Checkbox = 12,
	CheckboxActive = 13,
	CheckboxInactive = 14,
	// Метка текстового поля.
	TextBoxLabel = 15,
	TextBoxLabelInactive = 16,
	// Текстовое поле.
	TextBoxInput = 17,
	TextBoxInputActive = 18,
	TextBoxInputInactive = 19,
	// Поле просмотра текста.
	TextView = 20,
	TextViewActive = 21,
	TextViewInactive = 22,
	// Элемент меню.
	MenuItem = 23,
	MenuItemActive = 24,
	MenuItemInactive = 25,
	// Элемент списка.
	ListBoxItem = 26,
	ListBoxItemActive = 27,
	ListBoxItemInactive = 28,
	ListBoxItemSelect = 29,
}

/**
 * Style — "готовый ответ" темы: какая color-pair + какие attrs.
 */
struct Style
{
	// Номер color-pair.
	short pair;
	// Битовая маска атрибутов.
	int attrs;

	// Нейтральный стиль.
	static Style none()
	{
		return Style(0, 0);
	}

	// Преобразование Style в ncurses-атрибут для рисования.
	@property int attr() const
	{
		if (pair <= 0)
		{
			return attrs;
		}

		return COLOR_PAIR(pair) | attrs;
	}
}

/**
 * Интерфейс темы.
 */
interface ITheme
{
	// Инициализация темы.
	void initialize();

	// Получить Style для заданного семантического идентификатора.
	Style style(StyleId id);
}

/**
 * Контекст темы для отрисовки.
 */
interface IThemeContext
{
	// Возвращает `Style` для семантического идентификатора `id`.
	Style style(StyleId id);

	// Возвращает ncurses-атрибут для рисования (`COLOR_PAIR(pair) | attrs`).
	int attr(StyleId id);
}

void newPair(short slot, short color, short attrs)
{
	ncuiExpectMsg!((int value) => 0 <= value && value <= A_ATTRIBUTES )(
		"Invalid ncurses attributes mask (attrs out of range)",
		true,
		attrs
	);

	ncuiNotErr!init_pair(slot, color, attrs);
}

/**
 * ThemeManager — единая точка доступа к текущей теме.
 */
final class ThemeManager : IThemeContext
{
private:
	ITheme _theme;

	// Следующий свободный id пары для динамической регистрации.
	short _nextPair;
	// Кэш: (foreground, background) -> pairId.
	short[uint] _pairs;

	/**
	 * Упаковывает два `short` (foreground/background) в один `uint` для ключа кэша.
	 *
	 * Делается через `ushort`, чтобы корректно обработать `-1` (default color).
	 *
	 * Params:
	 *   foreground = Цвет переднего плана (0..7 или -1).
	 *   background = Цвет фона (0..7 или -1).
	 *
	 * Returns:
	 *   32-битный ключ, где foreground лежит в верхних 16 битах, background — в нижних 16 битах.
	 */
	static uint pack(short foreground, short background) @nogc nothrow
	{
		return (cast(uint) cast(ushort) foreground << 16) | cast(uint) cast(ushort) background;
	}

	/**
	 * Проверяет, что цвет входит в допустимый набор.
	 *
	 * Разрешены только:
	 * - `-1` (цвет терминала по умолчанию; используется с `use_default_colors()`),
	 * - `0..7` (стандартные цвета ncurses: COLOR_BLACK..COLOR_WHITE).
	 */
	static bool isStdColor(short c) @nogc nothrow
	{
		if (c == -1)
		{
			return true;
		}

		return c >= 0 && c <= 7; // COLOR_BLACK..COLOR_WHITE
	}

	/**
	 * Возвращает id color-pair для `(foreground, background)`.
	 *
	 * Если такая пара уже регистрировалась — берёт из кэша.
	 * Иначе регистрирует новую через `newPair`, проверяя лимит `COLOR_PAIRS`.
	 */
	short registerPair(short foreground, short background)
	{
		ncuiExpectMsg!((bool ok) => ok)("Only standard ncurses colors are allowed (0..7, optional -1)", true,
			isStdColor(foreground));
		ncuiExpectMsg!((bool ok) => ok)("Only standard ncurses colors are allowed (0..7, optional -1)", true,
			isStdColor(background));

		const uint key = pack(foreground, background);

		if (auto p = key in _pairs)
		{
			return *p;
		}

		newPair(_nextPair, foreground, background);

		_pairs[key] = _nextPair;

		return _nextPair++;
	}

public:
	this(ITheme theme = null)
	{
		ncuiExpect!has_colors(true);
		ncuiNotErr!start_color();
		ncuiNotErr!use_default_colors();

		_theme = theme is null ? new DefaultTheme() : theme;

		_theme.initialize();

		_nextPair = PairSlot.max + 1;
	}


	/**
	 * Возвращает ncurses-атрибут (`COLOR_PAIR(pair) | attrs`) для `id`.
	 */
	int attr(StyleId id)
	{
		return style(id).attr;
	}

	/**
	 * Возвращает `Style` для `id` из текущей темы.
	 */
	Style style(StyleId id)
	{
		return _theme.style(id);
	}

	/**
	 * Возвращает id color-pair для заданных стандартных цветов.
	 */
	short pair(short foreground, short background)
	{
		return registerPair(foreground, background);
	}
}

/**
 * LocalTheme — локальное переопределение стилей поверх базовой темы.
 */
final class LocalTheme : IThemeContext
{
private:
	// Базовый контекст (обычно ThemeManager), из которого берутся непереопределённые стили.
	IThemeContext _base;
	// Корневой ThemeManager (нужен для регистрации динамических пар).
	ThemeManager _root;

	// Количество элементов перечисления StyleId (ожидается непрерывный enum от 0).
	enum StyleCount = StyleId.max + 1;
	// Флаги наличия переопределений по StyleId.
	bool[StyleCount] _has;
	// Хранилище переопределений по StyleId.
	Style[StyleCount] _override;

public:
	/**
	 * Создаёт локальную тему поверх `base`.
	 */
	this(ThemeManager root, IThemeContext base)
	{
		_root = root;
		_base = base;
	}

	/**
	 * Устанавливает переопределение для конкретного `StyleId`.
	 *
	 * Params:
	 *   id         = Семантический идентификатор стиля.
	 *   foreground = COLOR_BLACK..COLOR_WHITE (0..7) или -1.
	 *   background = COLOR_BLACK..COLOR_WHITE (0..7) или -1.
	 *   attrs      = Маска атрибутов ncurses (A_BOLD, A_DIM, A_UNDERLINE и т.п.).
	 */
	void set(StyleId id, short foreground, short background, int attrs = 0)
	{
		ncuiExpectMsg!((int value) => 0 <= value && value <= A_ATTRIBUTES )(
			"Invalid ncurses attributes mask (attrs out of range)",
			true,
			attrs
		);

		_override[id] = Style(_root.pair(foreground, background), attrs);
		_has[id] = true;
	}

	/**
	 * Возвращает переопределённый стиль, если он есть, иначе берёт из `_base`.
	 */
	override Style style(StyleId id)
	{
		return _has[id] ? _override[id] : _base.style(id);
	}

	/**
	 * Возвращает ncurses-атрибут для рисования.
	 */
	override int attr(StyleId id)
	{
		return style(id).attr;
	}
}

/**
 * Базовая тема "по умолчанию".
 */
final class DefaultTheme : ITheme
{
	override void initialize()
	{
		newPair(PairSlot.Normal, COLOR_WHITE, -1);
		newPair(PairSlot.Muted, COLOR_CYAN, -1);
		newPair(PairSlot.Accent, COLOR_CYAN, -1);

		newPair(PairSlot.WindowBorderActive, COLOR_CYAN, -1);
		newPair(PairSlot.WindowBorderInactive, COLOR_WHITE, -1);

		newPair(PairSlot.BorderActive, COLOR_CYAN, -1);
		newPair(PairSlot.BorderInactive, COLOR_WHITE, -1);

		newPair(PairSlot.Error, COLOR_RED, -1);

		newPair(PairSlot.Button, COLOR_WHITE, -1);
		newPair(PairSlot.ButtonActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.ButtonInactive, COLOR_WHITE, -1);

		newPair(PairSlot.Checkbox, COLOR_WHITE, -1);
		newPair(PairSlot.CheckboxActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.CheckboxInactive, COLOR_WHITE, -1);

		newPair(PairSlot.TextBoxLabel, COLOR_WHITE, -1);
		newPair(PairSlot.TextBoxLabelInactive, COLOR_CYAN, -1);

		newPair(PairSlot.TextBoxInput, COLOR_WHITE, -1);
		newPair(PairSlot.TextBoxInputActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.TextBoxInputInactive, COLOR_WHITE, -1);

		newPair(PairSlot.TextView, COLOR_WHITE, -1);
		newPair(PairSlot.TextViewActive, COLOR_WHITE, -1);
		newPair(PairSlot.TextViewInactive, COLOR_WHITE, -1);

		newPair(PairSlot.MenuItem, COLOR_WHITE, -1);
		newPair(PairSlot.MenuItemActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.MenuItemInactive, COLOR_WHITE, -1);

		newPair(PairSlot.ListBoxItem, COLOR_WHITE, -1);
		newPair(PairSlot.ListBoxItemActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.ListBoxItemInactive, COLOR_WHITE, -1);
		newPair(PairSlot.ListBoxItemSelect, COLOR_BLACK, COLOR_YELLOW);
	}

	override Style style(StyleId id)
	{
		final switch (id)
		{
			// Фоны.
		case StyleId.WindowBackground:
			return Style(PairSlot.Normal, 0);

			// Текст.
		case StyleId.Text:
			return Style(PairSlot.Normal, 0);
		case StyleId.Muted:
			return Style(PairSlot.Muted, 0);
		case StyleId.Title:
			return Style(PairSlot.Accent, A_BOLD);

			// Рамки окна.
		case StyleId.WindowBorderActive:
			return Style(PairSlot.WindowBorderActive, A_BOLD);
		case StyleId.WindowBorderInactive:
			return Style(PairSlot.WindowBorderInactive, 0);

			// Рамки.
		case StyleId.BorderActive:
			return Style(PairSlot.BorderActive, A_BOLD);
		case StyleId.BorderInactive:
			return Style(PairSlot.BorderInactive, 0);

			// Семантика.
		case StyleId.Error:
			return Style(PairSlot.Error, A_BOLD);
		case StyleId.Accent:
			return Style(PairSlot.Accent, A_BOLD);

			// Кнопки.
		case StyleId.Button:
			return Style(PairSlot.Button, 0);
		case StyleId.ButtonActive:
			return Style(PairSlot.ButtonActive, A_BOLD);
		case StyleId.ButtonInactive:
			return Style(PairSlot.ButtonInactive, 0);

			// Флажок.
		case StyleId.Checkbox:
			return Style(PairSlot.Checkbox, 0);
		case StyleId.CheckboxActive:
			return Style(PairSlot.CheckboxActive, A_BOLD);
		case StyleId.CheckboxInactive:
			return Style(PairSlot.CheckboxInactive, A_DIM);

			// Метка текстового поля.
		case StyleId.TextBoxLabel:
			return Style(PairSlot.TextBoxLabel, 0);
		case StyleId.TextBoxLabelInactive:
			return Style(PairSlot.TextBoxLabelInactive, A_DIM);

			// Текстовое поле.
		case StyleId.TextBoxInput:
			return Style(PairSlot.TextBoxInput, A_UNDERLINE);
		case StyleId.TextBoxInputActive:
			return Style(PairSlot.TextBoxInputActive, A_UNDERLINE | A_BOLD);
		case StyleId.TextBoxInputInactive:
			return Style(PairSlot.TextBoxInputInactive, A_UNDERLINE | A_DIM);

			// Поле просмотра текста.
		case StyleId.TextView:
			return Style(PairSlot.TextView, 0);
		case StyleId.TextViewActive:
			return Style(PairSlot.TextViewActive, 0);
		case StyleId.TextViewInactive:
			return Style(PairSlot.TextViewInactive, A_DIM);

			// Элемент меню.
		case StyleId.MenuItem:
			return Style(PairSlot.MenuItem, 0);
		case StyleId.MenuItemActive:
			return Style(PairSlot.MenuItemActive, A_BOLD);
		case StyleId.MenuItemInactive:
			return Style(PairSlot.MenuItemInactive, A_DIM);
		
			// Элемент списка.
		case StyleId.ListBoxItem:
			return Style(PairSlot.ListBoxItem, 0);
		case StyleId.ListBoxItemActive:
			return Style(PairSlot.ListBoxItemActive, A_BOLD);
		case StyleId.ListBoxItemInactive:
			return Style(PairSlot.ListBoxItemInactive, A_DIM);
		case StyleId.ListBoxItemSelect:
			return Style(PairSlot.ListBoxItemSelect, 0);
		}
	}
}

final class DarkTheme : ITheme
{
	override void initialize()
	{
		newPair(PairSlot.Normal, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.Muted, COLOR_CYAN, COLOR_BLACK);
		newPair(PairSlot.Accent, COLOR_YELLOW, COLOR_BLACK);

		newPair(PairSlot.WindowBorderActive, COLOR_CYAN, COLOR_BLACK);
		newPair(PairSlot.WindowBorderInactive, COLOR_BLUE, COLOR_BLACK);

		newPair(PairSlot.BorderActive, COLOR_CYAN, COLOR_BLACK);
		newPair(PairSlot.BorderInactive, COLOR_BLUE, COLOR_BLACK);

		newPair(PairSlot.Error, COLOR_RED, COLOR_BLACK);

		newPair(PairSlot.Button, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.ButtonActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.ButtonInactive, COLOR_WHITE, COLOR_BLACK);

		newPair(PairSlot.Checkbox, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.CheckboxActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.CheckboxInactive, COLOR_WHITE, COLOR_BLACK);

		newPair(PairSlot.TextBoxLabel, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.TextBoxLabelInactive, COLOR_CYAN, COLOR_BLACK);

		newPair(PairSlot.TextBoxInput, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.TextBoxInputActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.TextBoxInputInactive, COLOR_WHITE, COLOR_BLACK);

		newPair(PairSlot.TextView, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.TextViewActive, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.TextViewInactive, COLOR_WHITE, COLOR_BLACK);

		newPair(PairSlot.MenuItem, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.MenuItemActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.MenuItemInactive, COLOR_WHITE, COLOR_BLACK);

		newPair(PairSlot.ListBoxItem, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.ListBoxItemActive, COLOR_BLACK, COLOR_CYAN);
		newPair(PairSlot.ListBoxItemInactive, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.ListBoxItemSelect, COLOR_BLACK, COLOR_YELLOW);
	}

	override Style style(StyleId id)
	{
		final switch (id)
		{
			// Фоны.
		case StyleId.WindowBackground:
			return Style(PairSlot.Normal, 0);

			// Текст.
		case StyleId.Text:
			return Style(PairSlot.Normal, 0);
		case StyleId.Muted:
			return Style(PairSlot.Muted, 0);
		case StyleId.Title:
			return Style(PairSlot.Accent, A_BOLD);

			// Рамки окна.
		case StyleId.WindowBorderActive:
			return Style(PairSlot.WindowBorderActive, A_BOLD);
		case StyleId.WindowBorderInactive:
			return Style(PairSlot.WindowBorderInactive, 0);

			// Рамки.
		case StyleId.BorderActive:
			return Style(PairSlot.BorderActive, A_BOLD);
		case StyleId.BorderInactive:
			return Style(PairSlot.BorderInactive, 0);

			// Семантика.
		case StyleId.Error:
			return Style(PairSlot.Error, A_BOLD);
		case StyleId.Accent:
			return Style(PairSlot.Accent, A_BOLD);

			// Кнопки.
		case StyleId.Button:
			return Style(PairSlot.Button, 0);
		case StyleId.ButtonActive:
			return Style(PairSlot.ButtonActive, A_BOLD);
		case StyleId.ButtonInactive:
			return Style(PairSlot.ButtonInactive, 0);

			// Флажок.
		case StyleId.Checkbox:
			return Style(PairSlot.Checkbox, 0);
		case StyleId.CheckboxActive:
			return Style(PairSlot.CheckboxActive, A_BOLD);
		case StyleId.CheckboxInactive:
			return Style(PairSlot.CheckboxInactive, A_DIM);

			// Метка текстового поля.
		case StyleId.TextBoxLabel:
			return Style(PairSlot.TextBoxLabel, 0);
		case StyleId.TextBoxLabelInactive:
			return Style(PairSlot.TextBoxLabelInactive, A_DIM);

			// Текстовое поле.
		case StyleId.TextBoxInput:
			return Style(PairSlot.TextBoxInput, A_UNDERLINE);
		case StyleId.TextBoxInputActive:
			return Style(PairSlot.TextBoxInputActive, A_UNDERLINE | A_BOLD);
		case StyleId.TextBoxInputInactive:
			return Style(PairSlot.TextBoxInputInactive, A_UNDERLINE | A_DIM);

			// Поле просмотра текста.
		case StyleId.TextView:
			return Style(PairSlot.TextView, 0);
		case StyleId.TextViewActive:
			return Style(PairSlot.TextViewActive, 0);
		case StyleId.TextViewInactive:
			return Style(PairSlot.TextViewInactive, A_DIM);

			// Элемент меню.
		case StyleId.MenuItem:
			return Style(PairSlot.MenuItem, 0);
		case StyleId.MenuItemActive:
			return Style(PairSlot.MenuItemActive, A_BOLD);
		case StyleId.MenuItemInactive:
			return Style(PairSlot.MenuItemInactive, A_DIM);

			// Элемент списка.
		case StyleId.ListBoxItem:
			return Style(PairSlot.ListBoxItem, 0);
		case StyleId.ListBoxItemActive:
			return Style(PairSlot.ListBoxItemActive, A_BOLD);
		case StyleId.ListBoxItemInactive:
			return Style(PairSlot.ListBoxItemInactive, A_DIM);
		case StyleId.ListBoxItemSelect:
			return Style(PairSlot.ListBoxItemSelect, 0);
		}
	}
}

final class LightTheme : ITheme
{
	override void initialize()
	{
		newPair(PairSlot.Normal, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.Muted, COLOR_BLUE, COLOR_WHITE);
		newPair(PairSlot.Accent, COLOR_BLUE, COLOR_WHITE);

		newPair(PairSlot.WindowBorderActive, COLOR_BLUE, COLOR_WHITE);
		newPair(PairSlot.WindowBorderInactive, COLOR_BLACK, COLOR_WHITE);

		newPair(PairSlot.BorderActive, COLOR_BLUE, COLOR_WHITE);
		newPair(PairSlot.BorderInactive, COLOR_BLACK, COLOR_WHITE);

		newPair(PairSlot.Error, COLOR_RED, COLOR_WHITE);

		newPair(PairSlot.Button, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.ButtonActive, COLOR_WHITE, COLOR_BLUE);
		newPair(PairSlot.ButtonInactive, COLOR_BLUE, COLOR_WHITE);

		newPair(PairSlot.Checkbox, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.CheckboxActive, COLOR_WHITE, COLOR_BLUE);
		newPair(PairSlot.CheckboxInactive, COLOR_BLUE, COLOR_WHITE);

		newPair(PairSlot.TextBoxLabel, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.TextBoxLabelInactive, COLOR_BLUE, COLOR_WHITE);

		newPair(PairSlot.TextBoxInput, COLOR_BLACK, COLORS > 8 ? COLOR_WHITE : COLOR_CYAN);
		newPair(PairSlot.TextBoxInputActive, COLOR_WHITE, COLOR_BLUE);
		newPair(PairSlot.TextBoxInputInactive, COLOR_BLUE, COLOR_WHITE);

		newPair(PairSlot.TextView, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.TextViewActive, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.TextViewInactive, COLOR_BLACK, COLOR_WHITE);

		newPair(PairSlot.MenuItem, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.MenuItemActive, COLOR_WHITE, COLOR_BLUE);
		newPair(PairSlot.MenuItemInactive, COLOR_BLUE, COLOR_WHITE);

		newPair(PairSlot.ListBoxItem, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.ListBoxItemActive, COLOR_WHITE, COLOR_BLUE);
		newPair(PairSlot.ListBoxItemInactive, COLOR_BLUE, COLOR_WHITE);
		newPair(PairSlot.ListBoxItemSelect, COLOR_BLACK, COLOR_YELLOW);
	}

	override Style style(StyleId id)
	{
		final switch (id)
		{
			// Фоны.
		case StyleId.WindowBackground:
			return Style(PairSlot.Normal, 0);

			// Текст.
		case StyleId.Text:
			return Style(PairSlot.Normal, 0);
		case StyleId.Muted:
			return Style(PairSlot.Muted, 0);
		case StyleId.Title:
			return Style(PairSlot.Accent, A_BOLD);

			// Рамки окна.
		case StyleId.WindowBorderActive:
			return Style(PairSlot.WindowBorderActive, A_BOLD);
		case StyleId.WindowBorderInactive:
			return Style(PairSlot.WindowBorderInactive, 0);

			// Рамки.
		case StyleId.BorderActive:
			return Style(PairSlot.BorderActive, A_BOLD);
		case StyleId.BorderInactive:
			return Style(PairSlot.BorderInactive, 0);

			// Семантика.
		case StyleId.Error:
			return Style(PairSlot.Error, A_BOLD);
		case StyleId.Accent:
			return Style(PairSlot.Accent, A_BOLD);

			// Кнопки.
		case StyleId.Button:
			return Style(PairSlot.Button, 0);
		case StyleId.ButtonActive:
			return Style(PairSlot.ButtonActive, A_BOLD);
		case StyleId.ButtonInactive:
			return Style(PairSlot.ButtonInactive, 0);

			// Флажок.
		case StyleId.Checkbox:
			return Style(PairSlot.Checkbox, 0);
		case StyleId.CheckboxActive:
			return Style(PairSlot.CheckboxActive, A_BOLD);
		case StyleId.CheckboxInactive:
			return Style(PairSlot.CheckboxInactive, A_DIM);

			// Метка текстового поля.
		case StyleId.TextBoxLabel:
			return Style(PairSlot.TextBoxLabel, 0);
		case StyleId.TextBoxLabelInactive:
			return Style(PairSlot.TextBoxLabelInactive, A_DIM);

			// Текстовое поле.
		case StyleId.TextBoxInput:
			return Style(PairSlot.TextBoxInput, A_UNDERLINE);
		case StyleId.TextBoxInputActive:
			return Style(PairSlot.TextBoxInputActive, A_UNDERLINE | A_BOLD);
		case StyleId.TextBoxInputInactive:
			return Style(PairSlot.TextBoxInputInactive, A_UNDERLINE | A_DIM);

			// Поле просмотра текста.
		case StyleId.TextView:
			return Style(PairSlot.TextView, 0);
		case StyleId.TextViewActive:
			return Style(PairSlot.TextViewActive, 0);
		case StyleId.TextViewInactive:
			return Style(PairSlot.TextViewInactive, A_DIM);

			// Элемент меню.
		case StyleId.MenuItem:
			return Style(PairSlot.MenuItem, 0);
		case StyleId.MenuItemActive:
			return Style(PairSlot.MenuItemActive, A_BOLD);
		case StyleId.MenuItemInactive:
			return Style(PairSlot.MenuItemInactive, A_DIM);

			// Элемент списка.
		case StyleId.ListBoxItem:
			return Style(PairSlot.ListBoxItem, 0);
		case StyleId.ListBoxItemActive:
			return Style(PairSlot.ListBoxItemActive, A_BOLD);
		case StyleId.ListBoxItemInactive:
			return Style(PairSlot.ListBoxItemInactive, A_DIM);
		case StyleId.ListBoxItemSelect:
			return Style(PairSlot.ListBoxItemSelect, 0);
		}
	}
}
