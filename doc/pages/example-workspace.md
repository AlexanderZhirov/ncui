# Пример Workspace

Минимальный экран на `WorkspaceScreen`: два окна (`View`), одно активное и фокусируемое (форма), второе информационное (`focusable=false`).

## Поведение

- `Shift+Left / Shift+Right` — переключение окна (между `View`).
- `Tab` — переключение виджетов внутри активного окна.
- `Enter` — активация кнопок/чекбоксов.
- `q` / `Esc` — завершение приложения.

## Код

```d
import ncui;
import ncui.widgets.widget;
import ncui.engine.theme : LightTheme;
import deimos.ncurses;

/// Тело окна с формой. Фокус и курсор делегируются контейнеру виджетов.
final class FormBody : IViewBody, ICursorOwner
{
private:
	WidgetContainer _ui;

	TextBox _name;
	TextBox _pass;
	Checkbox _show;
	Button _ok;

public:
	this()
	{
		_ui = new WidgetContainer();

		_name = new TextBox(2, 2, 24, false, "Name");
		_pass = new TextBox(3, 2, 24, true,  "Password");

		_show = new Checkbox(5, 2, "Show password", false, (checked) {
			_pass.hideText(!checked);
		});

		_ok = new Button(7, 2, "OK", () {
			const string value = _name.text() ~ ":" ~ _pass.text();
			return ScreenAction.quit(ScreenResult.ok(value));
		});

		_ui.add(_name);
		_ui.add(_pass);
		_ui.add(_show);
		_ui.add(_ok);
	}

	override void render(Window w, ScreenContext context, bool active)
	{
		_ui.setActive(active);

		const int borderAttr = context.theme.attr(active ? StyleId.BorderActive : StyleId.BorderInactive);
		if (borderAttr != 0) wattron(w.handle(), borderAttr);
		scope (exit) { if (borderAttr != 0) wattroff(w.handle(), borderAttr); }

		w.border();
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

/// Тело окна справки. Окно не участвует в переключении фокуса окон.
final class HelpBody : IViewBody
{
	override void render(Window w, ScreenContext context, bool active)
	{
		const int borderAttr = context.theme.attr(active ? StyleId.BorderActive : StyleId.BorderInactive);
		if (borderAttr != 0) wattron(w.handle(), borderAttr);
		scope (exit) { if (borderAttr != 0) wattroff(w.handle(), borderAttr); }

		w.putAttr(0, 2, " HELP ", context.theme.attr(StyleId.Title));

		int y = 2;
		w.put(y++, 2, "Shift+Left/Right -> switch window");
		w.put(y++, 2, "Tab              -> switch widget");
		w.put(y++, 2, "q/Esc            -> quit");
		w.put(y++, 2, "OK               -> quit with Name:Password");
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		return ScreenAction.none();
	}

	override void close()
	{
	}
}

/// Экран из двух окон: форма + справка.
final class DemoWorkspaceScreen : WorkspaceScreen
{
	override void build(ScreenContext context, Workspace ws)
	{
		const int H = getmaxy(context.session.root());
		const int W = getmaxx(context.session.root());

		const int leftW = W / 2;
		const int rightW = W - leftW;

		auto leftWin  = new Window(H, leftW, 0, 0);
		auto rightWin = new Window(H, rightW, 0, leftW);

		ws.add(new View(leftWin,  new FormBody(), true));
		ws.add(new View(rightWin, new HelpBody(), false));
	}

	override ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		if (event.isChar && (event.ch == 'q' || event.ch == 'Q' || event.ch == 27))
		{
			return ScreenAction.quit(ScreenResult.cancel());
		}

		if (event.status == ERR)
		{
			return ScreenAction.quit(ScreenResult.cancel());
		}

		return ScreenAction.none();
	}
}

void main()
{
	auto config = SessionConfig(InputMode.raw, Cursor.normal, Echo.off, Keypad.on);
	auto app = new NCUI(config, new LightTheme());

	app.run(new DemoWorkspaceScreen());
}
```
