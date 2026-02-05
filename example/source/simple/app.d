module simple.app;

import ncui;

import password;

import deimos.ncurses;

final class Simple : ScreenBase
{
private:
	TextBox textBox1;
public:
	override Window ensureWindow(ScreenContext context)
	{
		int height = getmaxy(context.session.root());
		int width = getmaxx(context.session.root());

		return new Window(height, width, 0, 0);
	}

	override void layout(Window window, ScreenContext context)
	{
		auto text = context.data.get!string;

		_window.border();
		_window.put(1, 2, text);
	}

	override void build(Window window, ScreenContext context, WidgetContainer ui)
	{
		auto okBtn = new Button(3, 2, "OK", () => ScreenAction.push(new Password()));
		auto cancelBtn = new Button(3, okBtn.width + 3, "Cancel", () => ScreenAction.pop(ScreenResult.none()));

		textBox1 = new TextBox(5, 12, 30, true, "Пароль");
		auto textBox2 = new TextBox(6, 9, 30, false, "Кириллица", "Простой тест", r"^[А-Яа-я]$");
		auto textBox3 = new TextBox(7, 10, 30, false, "Латиница", string.init, r"^[A-Za-z]$");
		auto textBox4 = new TextBox(8, 2, 30, false, "Латиница + цифры", string.init, r"^[a-zA-Z0-9]$");

		auto disableOk = new Checkbox(4, 2, "Показать символы", false, (checked) {
			textBox1.hideText(!checked);
		});

		import std.file : readText;

		string text;

		try
		{
			text = readText("example/text");
		}
		catch (Exception e)
		{
			warning(e.msg);
		}

		auto textview = new TextView(10, 2, 50, 6, text);

		textview.append("Append text 1.");
		textview.append("Append text 2.");

		auto menu = new Menu(16, 2, 50, 6,
			[
				MenuLabel("Один", "Первый элемент"),
				MenuLabel("Два", "Второй элемент"),
				MenuLabel("Три", "Третий элемент"),
				MenuLabel("Четыре", "Четвертый элемент")
			],
			(index, label) {
				textBox1.setText(label);
				textview.append(label);
				return ScreenAction.none();
			}
		);

		_ui.add(okBtn);
		_ui.add(cancelBtn);
		_ui.add(disableOk);
		_ui.add(textBox1);
		_ui.add(textBox2);
		_ui.add(textBox3);
		_ui.add(textBox4);
		_ui.add(textview);
		_ui.add(menu);
	}

	override ScreenAction onChildResult(ScreenContext context, ScreenResult child)
	{
		if (child.kind == ScreenKind.Ok && child.has!string)
		{
			textBox1.setText(child.get!string);
			return ScreenAction.none();
		}

		return ScreenAction.none();
	}

	override ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		if (event.status == ERR)
		{
			return ScreenAction.quit(ScreenResult.none());
		}

		if (event.isChar)
		{
			if (event.ch == 27)
			{
				return ScreenAction.quit(ScreenResult.none());
			}
		}

		return ScreenAction.none();
	}
}
