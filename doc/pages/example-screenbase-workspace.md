# Пример ScreenBase + Workspace

Композиция двух подходов: `ScreenBase` используется как главный экран (меню/хаб), а `WorkspaceScreen` открывается как дочерний экран через `ScreenAction.push(...)` и возвращает результат через `ScreenResult.ok(...)`.

## Поведение

Главный экран (`ScreenBase`):

- `Open workspace` — открывает `WorkspaceScreen` поверх текущего.
- при возврате результата (`onChildResult`) обновляет поле `Last result`.

Дочерний экран (`WorkspaceScreen`):

- активное окно содержит форму и возвращает строку по `OK`;
- `Esc/q` закрывает дочерний экран с `ScreenResult.cancel()`.

## Код

```d
import ncui;
import ncui.widgets.widget;
import ncui.engine.theme : LightTheme;
import deimos.ncurses;

/// Дочерний WorkspaceScreen: редактирование значения в двухоконном режиме.
final class EditorFormBody : IViewBody, ICursorOwner
{
private:
	WidgetContainer _ui;
	TextBox _value;
	Button _ok;
	Button _cancel;

public:
	this()
	{
		_ui = new WidgetContainer();

		_value = new TextBox(2, 2, 28, false, "Value", "default");

		_ok = new Button(5, 2, "OK", () {
			return ScreenAction.pop(ScreenResult.ok(_value.text()));
		});

		_cancel = new Button(5, _ok.width + 3, "Cancel", () {
			return ScreenAction.pop(ScreenResult.cancel());
		});

		_ui.add(_value);
		_ui.add(_ok);
		_ui.add(_cancel);
	}

	override void render(Window w, ScreenContext context, bool active)
	{
		_ui.setActive(active);

		const int borderAttr = context.theme.attr(active ? StyleId.BorderActive : StyleId.BorderInactive);
		if (borderAttr != 0) wattron(w.handle(), borderAttr);
		scope (exit) { if (borderAttr != 0) wattroff(w.handle(), borderAttr); }

		w.border();
		w.putAttr(0, 2, " EDITOR ", context.theme.attr(StyleId.Title));

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

final class EditorHelpBody : IViewBody
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
		w.put(y++, 2, "OK               -> return Value");
		w.put(y++, 2, "Esc/q            -> cancel");
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		return ScreenAction.none();
	}

	override void close()
	{
	}
}

final class EditorWorkspaceScreen : WorkspaceScreen
{
	override void build(ScreenContext context, Workspace ws)
	{
		const int H = getmaxy(context.session.root());
		const int W = getmaxx(context.session.root());

		const int leftW = (W * 2) / 3;
		const int rightW = W - leftW;

		auto leftWin  = new Window(H, leftW, 0, 0);
		auto rightWin = new Window(H, rightW, 0, leftW);

		ws.add(new View(leftWin,  new EditorFormBody(), true));
		ws.add(new View(rightWin, new EditorHelpBody(), false));
	}

	override ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		if (event.status == ERR)
		{
			return ScreenAction.pop(ScreenResult.cancel());
		}

		if (event.isChar && (event.ch == 27 || event.ch == 'q' || event.ch == 'Q'))
		{
			return ScreenAction.pop(ScreenResult.cancel());
		}

		return ScreenAction.none();
	}
}

/// Главный экран ScreenBase: открывает WorkspaceScreen и принимает результат.
final class MainScreen : ScreenBase
{
private:
	TextBox _lastResult;
public:
	override Window ensureWindow(ScreenContext context)
	{
		const int H = getmaxy(context.session.root());
		const int W = getmaxx(context.session.root());
		return new Window(H, W, 0, 0);
	}

	override void layout(Window window, ScreenContext context)
	{
		_window.border();
		_window.putAttr(0, 2, " MAIN ", context.theme.attr(StyleId.Title));

		_window.put(2, 2, "Open workspace -> push EditorWorkspaceScreen");
		_window.put(3, 2, "Last result    -> updated in onChildResult");
		_window.put(4, 2, "Esc/q          -> quit");
	}

	override void build(Window window, ScreenContext context, WidgetContainer ui)
	{
		auto open = new Button(6, 2, "Open workspace", () {
			return ScreenAction.push(new EditorWorkspaceScreen());
		});

		auto quit = new Button(6, open.width + 3, "Quit", () {
			return ScreenAction.quit(ScreenResult.cancel());
		});

		_lastResult = new TextBox(8, 2, 40, false, "Last result", "");

		ui.add(open);
		ui.add(quit);
		ui.add(_lastResult);
	}

	override ScreenAction onChildResult(ScreenContext context, ScreenResult child)
	{
		if (child.kind == ScreenKind.Ok && child.has!string)
		{
			_lastResult.setText(child.get!string);
		}

		return ScreenAction.none();
	}

	override ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		if (event.status == ERR)
		{
			return ScreenAction.quit(ScreenResult.cancel());
		}

		if (event.isChar && (event.ch == 27 || event.ch == 'q' || event.ch == 'Q'))
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

	app.run(new MainScreen());
}
```
