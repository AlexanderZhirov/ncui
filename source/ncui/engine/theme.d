module ncui.engine.theme;

import deimos.ncurses;

import ncui.lib.checks;

/**
 * Идентификаторы стилей, которыми пользуется UI.
 */
enum StyleId
{
	// Фон всего экрана.
	ScreenBackground,
	// Фон окон.
	WindowBackground,
	// Фон виджетов.
	WidgetBackground,
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
	// Границы.
	BorderActive = 4,
	BorderInactive = 5,
	// Ошибки
	Error = 6,
	// Кнопки.
	Button = 7,
	ButtonActive = 8,
	ButtonInactive = 9,
	// Флажок.
	Checkbox = 10,
	CheckboxActive = 11,
	CheckboxInactive = 12,
	// Метка текстового поля.
	TextBoxLabel = 13,
	TextBoxLabelInactive = 14,
	// Текстовое поле.
	TextBoxInput = 15,
	TextBoxInputActive = 16,
	TextBoxInputInactive = 17,
	// Поле просмотра текста.
	TextView = 18,
	TextViewActive = 19,
	TextViewInactive = 20,
	// Пункт меню.
	MenuItem = 21,
	MenuItemActive = 22,
	MenuItemInactive = 23,
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
 * ThemeManager — единая точка доступа к текущей теме.
 */
final class ThemeManager
{
private:
	ITheme _theme;

public:
	this(ITheme theme = null)
	{
		ncuiExpect!has_colors(true);
		ncuiNotErr!start_color();
		ncuiNotErr!use_default_colors();

		_theme = theme is null ? new DefaultTheme() : theme;

		_theme.initialize();
	}

	int attr(StyleId id)
	{
		return style(id).attr;
	}

	Style style(StyleId id)
	{
		return _theme.style(id);
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
	}

	override Style style(StyleId id)
	{
		final switch (id)
		{
			// Фоны.
		case StyleId.ScreenBackground:
			return Style(PairSlot.Normal, 0);
		case StyleId.WindowBackground:
			return Style(PairSlot.Normal, 0);
		case StyleId.WidgetBackground:
			return Style(PairSlot.Normal, 0);

			// Текст.
		case StyleId.Text:
			return Style(PairSlot.Normal, 0);
		case StyleId.Muted:
			return Style(PairSlot.Muted, 0);
		case StyleId.Title:
			return Style(PairSlot.Accent, A_BOLD);

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

			// Пункт меню.
		case StyleId.MenuItem:
			return Style(PairSlot.MenuItem, 0);
		case StyleId.MenuItemActive:
			return Style(PairSlot.MenuItemActive, A_BOLD);
		case StyleId.MenuItemInactive:
			return Style(PairSlot.MenuItemInactive, A_DIM);
		}
	}
}

void newPair(short slot, short color, short attrs)
{
	ncuiNotErr!init_pair(slot, color, attrs);
}

final class DarkTheme : ITheme
{
	override void initialize()
	{
		newPair(PairSlot.Normal, COLOR_WHITE, COLOR_BLACK);
		newPair(PairSlot.Muted, COLOR_CYAN, COLOR_BLACK);
		newPair(PairSlot.Accent, COLOR_YELLOW, COLOR_BLACK);

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
	}

	override Style style(StyleId id)
	{
		final switch (id)
		{
			// Фоны.
		case StyleId.ScreenBackground:
			return Style(PairSlot.Normal, 0);
		case StyleId.WindowBackground:
			return Style(PairSlot.Normal, 0);
		case StyleId.WidgetBackground:
			return Style(PairSlot.Normal, 0);

			// Текст.
		case StyleId.Text:
			return Style(PairSlot.Normal, 0);
		case StyleId.Muted:
			return Style(PairSlot.Muted, 0);
		case StyleId.Title:
			return Style(PairSlot.Accent, A_BOLD);

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

			// Пункт меню.
		case StyleId.MenuItem:
			return Style(PairSlot.MenuItem, 0);
		case StyleId.MenuItemActive:
			return Style(PairSlot.MenuItemActive, A_BOLD);
		case StyleId.MenuItemInactive:
			return Style(PairSlot.MenuItemInactive, A_DIM);
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

		newPair(PairSlot.TextBoxInput, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.TextBoxInputActive, COLOR_WHITE, COLOR_BLUE);
		newPair(PairSlot.TextBoxInputInactive, COLOR_BLUE, COLOR_WHITE);

		newPair(PairSlot.TextView, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.TextViewActive, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.TextViewInactive, COLOR_BLACK, COLOR_WHITE);

		newPair(PairSlot.MenuItem, COLOR_BLACK, COLOR_WHITE);
		newPair(PairSlot.MenuItemActive, COLOR_WHITE, COLOR_BLUE);
		newPair(PairSlot.MenuItemInactive, COLOR_BLUE, COLOR_WHITE);
	}

	override Style style(StyleId id)
	{
		final switch (id)
		{
			// Фоны.
		case StyleId.ScreenBackground:
			return Style(PairSlot.Normal, 0);
		case StyleId.WindowBackground:
			return Style(PairSlot.Normal, 0);
		case StyleId.WidgetBackground:
			return Style(PairSlot.Normal, 0);

			// Текст.
		case StyleId.Text:
			return Style(PairSlot.Normal, 0);
		case StyleId.Muted:
			return Style(PairSlot.Muted, 0);
		case StyleId.Title:
			return Style(PairSlot.Accent, A_BOLD);

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

			// Пункт меню.
		case StyleId.MenuItem:
			return Style(PairSlot.MenuItem, 0);
		case StyleId.MenuItemActive:
			return Style(PairSlot.MenuItemActive, A_BOLD);
		case StyleId.MenuItemInactive:
			return Style(PairSlot.MenuItemInactive, A_DIM);
		}
	}
}
