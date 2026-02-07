module workspace.app;

import ncui;

import deimos.ncurses;
import simple;

final class FormBody : ViewBody, ICursorOwner
{
private:
	WidgetContainer _ui;

	TextBox _name;
	TextBox _pass;
	Checkbox _showPass;
	Checkbox _enableOk;
	Button _ok;
	Menu _menu;

public:
	this(HelpBody help)
	{
		_ui = new WidgetContainer();

		_name = new TextBox(2, 2, 24, false, "Name");
		_pass = new TextBox(3, 2, 24, true,  "Password");

		_showPass = new Checkbox(5, 2, "Show password", false,
			(checked)
			{
				_pass.hideText(!checked);
			}
		);

		_ok = new Button(7, 2, "OK",
			() {
				const string value = _name.text() ~ ":" ~ _pass.text();
				return ScreenAction.quit(ScreenResult.ok(value));
			}
		);

		_enableOk = new Checkbox(6, 2, "Enable OK", true,
			(checked)
			{
				_ok.setEnabled(checked);
			}
		);

		auto labels = [
			MenuLabel("Статус", "Показать статус"),
			MenuLabel("Справка", "Показать справку"),
			MenuLabel("О программе", "Показать информацию"),
		];

		_menu = new Menu(9, 2, 40, 10, labels, (idx, label) {
			help.setText(label);
			return ScreenAction.none();
		});

		auto items = [
			"Строка один.",
			"Две строки.",
			"Третья строка по счету.",
			"Четвертая строка — немного длиннее предыдущих.",
			"Пятая строка уже начинает напоминать полноценное предложение с законченной мыслью.",
			"Шестая строка — это уже что-то среднее между короткой и длинной строкой.",
			"Седьмая строка — чуть удлиненная, чтобы проверить, как будет выглядеть текст в поле.",
			"Восьмая строка — еще один пример, демонстрирующий разную длину текста.",
			"Девятая строка — снова среднего размера, но с дополнительными словами.",
			"Десятая строка — уже ближе к длинным, содержит больше информации.",
			"Одиннадцатая строка — продолжение серии, чтобы было видно, как текст заполняет пространство.",
			"Двенадцатая строка — снова добавляет разнообразия в длину.",
			"Тринадцатая строка — чуть больше среднего размера.",
			"Четырнадцатая строка — достаточно длинная, чтобы вызвать перенос при узком окне.",
			"Пятнадцатая строка — эксперимент с количеством слов.",
			"Шестнадцатая строка — не самая короткая, но и не самая длинная.",
			"Семнадцатая строка — добавляет еще немного текста.",
			"Восемнадцатая строка — почти как предыдущая, но с изменением окончания.",
			"Девятнадцатая строка — близка к максимуму, чтобы проверить границы.",
			"Двадцатая строка — финальная, самая длинная, с множеством слов и пробелов."
		];

		auto list = new ListBox(
			20, 2, 60, 10,
			items,
			(size_t index, string value) {
				help.setText(value);
				return ScreenAction.none();
			},
			true,
			true,
			false
		);

		_ui.add(_name);
		_ui.add(_pass);
		_ui.add(_showPass);
		_ui.add(_enableOk);
		_ui.add(_ok);
		_ui.add(_menu);
		_ui.add(list);
	}

	override void render(Window w, ScreenContext context, bool active)
	{
		_ui.setActive(active);

		const int borderAttr = context.theme.attr(active ? StyleId.WindowBorderActive : StyleId.WindowBorderInactive);
		if (borderAttr != 0) wattron(w.handle(), borderAttr);
		scope (exit) { if (borderAttr != 0) wattroff(w.handle(), borderAttr); }

		w.border(WindowBorder.top | WindowBorder.left | WindowBorder.bottom);
		w.putAttr(0, 2, " FORM ", context.theme.attr(StyleId.Title));

		w.put(1, 2, "Tab: next widget");

		_ui.render(w, context);
	}

	override void placeCursor(ScreenContext context)
	{
		_ui.applyCursor(context);
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		return _ui.handle(context, event);
	}

	override void close()
	{
		_ui.close();
	}
}

final class HelpBody : ViewBody, ICursorOwner
{
private:
	WidgetContainer _ui;
	TextView _tv;

public:
	this()
	{
		_ui = new WidgetContainer();
		_tv = new TextView(8, 2, 50, 10, "Выберите пункт меню слева.", true, true);
		_ui.add(_tv);
	}

	override void render(Window w, ScreenContext context, bool active)
	{
		_ui.setActive(active);

		const int borderAttr = context.theme.attr(active ? StyleId.WindowBorderActive : StyleId.WindowBorderInactive);
		if (borderAttr != 0) wattron(w.handle(), borderAttr);
		scope (exit) { if (borderAttr != 0) wattroff(w.handle(), borderAttr); }

		w.border(WindowBorder.top | WindowBorder.right | WindowBorder.bottom);
		w.putAttr(0, 2, " HELP ", context.theme.attr(StyleId.Title));

		int y = 2;
		w.put(y++, 2, "Shift+Left / Shift+Right  -> switch window");
		w.put(y++, 2, "Tab                      -> switch widget (inside window)");
		w.put(y++, 2, "q / Esc                  -> quit");
		w.put(y++, 2, "OK button                -> returns Name:Password");

		_ui.render(w, context);
	}

	void setText(string s)
	{
		_tv.append(s);
	}

	override void placeCursor(ScreenContext context)
	{
		_ui.applyCursor(context);
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (event.isEnter)
		{
			return ScreenAction.push(new Simple());
		}

		return _ui.handle(context, event);
	}

	override void close()
	{
		_ui.close();
	}
}

final class DemoScreen : WorkspaceScreen
{
	override void build(ScreenContext context, Workspace ws)
	{
		const int H = getmaxy(context.session.root());
		const int W = getmaxx(context.session.root());

		const int leftW = W / 2;
		const int rightW = W - leftW;

		auto leftWin  = new Window(H, leftW, 0, 0);
		auto rightWin = new Window(H, rightW, 0, leftW);

		auto right = new HelpBody();
		auto left  = new FormBody(right);

		auto helpBody = new View(rightWin, right);
		auto formBody = new View(leftWin,  left);

		LocalTheme tFormBody = formBody.localTheme(context);
		tFormBody.set(StyleId.WindowBackground, COLOR_CYAN, COLOR_YELLOW);
		tFormBody.set(StyleId.WindowBorderActive, COLOR_RED, COLOR_YELLOW);
		tFormBody.set(StyleId.WindowBorderInactive, COLOR_BLACK, COLOR_YELLOW);
		tFormBody.set(StyleId.BorderActive, COLOR_BLUE, COLOR_YELLOW);
		tFormBody.set(StyleId.BorderInactive, COLOR_BLACK, COLOR_YELLOW);
		tFormBody.set(StyleId.Title, COLOR_BLACK, COLOR_YELLOW, A_BOLD);
		tFormBody.set(StyleId.ListBoxItem, COLOR_BLACK, COLOR_YELLOW, 0);
		tFormBody.set(StyleId.ListBoxItemActive, COLOR_BLACK, COLOR_BLUE, A_BOLD);
		tFormBody.set(StyleId.ListBoxItemInactive, COLOR_BLACK, COLOR_YELLOW, A_DIM);
		tFormBody.set(StyleId.ListBoxItemSelect, COLOR_BLACK, COLOR_WHITE, 0);
		tFormBody.set(StyleId.Button, COLOR_BLACK, COLOR_YELLOW);
		tFormBody.set(StyleId.ButtonActive, COLOR_WHITE, COLOR_BLUE, A_BOLD);
		tFormBody.set(StyleId.ButtonInactive, COLOR_BLACK, COLOR_YELLOW, A_DIM);
		tFormBody.set(StyleId.Checkbox, COLOR_BLACK, COLOR_YELLOW);
		tFormBody.set(StyleId.CheckboxActive, COLOR_WHITE, COLOR_BLUE, A_BOLD);
		tFormBody.set(StyleId.CheckboxInactive, COLOR_BLACK, COLOR_YELLOW, A_DIM);
		tFormBody.set(StyleId.MenuItem, COLOR_BLACK, COLOR_YELLOW);
		tFormBody.set(StyleId.MenuItemActive, COLOR_WHITE, COLOR_BLUE, A_BOLD);
		tFormBody.set(StyleId.MenuItemInactive, COLOR_BLACK, COLOR_YELLOW, A_DIM);
		tFormBody.set(StyleId.TextBoxInput, COLOR_BLACK, COLOR_YELLOW, A_UNDERLINE);
		tFormBody.set(StyleId.TextBoxInputActive, COLOR_WHITE, COLOR_BLUE, A_BOLD | A_UNDERLINE);
		tFormBody.set(StyleId.TextBoxInputInactive, COLOR_BLUE, COLOR_YELLOW, A_DIM | A_UNDERLINE);
		tFormBody.set(StyleId.TextBoxLabel, COLOR_BLACK, COLOR_YELLOW);
		tFormBody.set(StyleId.TextBoxLabelInactive, COLOR_BLUE, COLOR_YELLOW, A_DIM);

		LocalTheme tHelpBody = helpBody.localTheme(context);
		tHelpBody.set(StyleId.WindowBackground, COLOR_WHITE, COLOR_BLUE);
		tHelpBody.set(StyleId.WindowBorderActive, COLOR_RED, COLOR_BLUE);
		tHelpBody.set(StyleId.WindowBorderInactive, COLOR_WHITE, COLOR_BLUE);
		tHelpBody.set(StyleId.Title, COLOR_WHITE, COLOR_BLUE, A_BOLD);
		tHelpBody.set(StyleId.BorderActive, COLOR_BLACK, COLOR_BLUE);
		tHelpBody.set(StyleId.BorderInactive, COLOR_WHITE, COLOR_BLUE);
		tHelpBody.set(StyleId.TextView, COLOR_WHITE, COLOR_BLUE);
		tHelpBody.set(StyleId.TextViewActive, COLOR_WHITE, COLOR_BLUE, A_BOLD);
		tHelpBody.set(StyleId.TextViewInactive, COLOR_WHITE, COLOR_BLUE, A_DIM);
		

		ws.add(formBody);
		ws.add(helpBody);
	}

	override ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		if (event.isChar && (event.ch == 'q' || event.ch == 'Q' || event.ch == 27))
		{
			return ScreenAction.quit(ScreenResult.cancel());
		}

		return ScreenAction.none();
	}
}
