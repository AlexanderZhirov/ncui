module workspace.app;

import ncui;

import deimos.ncurses;
import simple;

final class FormBody : IViewBody, ICursorOwner
{
private:
	WidgetContainer _ui;

	TextBox _name;
	TextBox _pass;
	Checkbox _showPass;
	Checkbox _enableOk;
	Button _ok;

public:
	this()
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

		_ui.add(_name);
		_ui.add(_pass);
		_ui.add(_showPass);
		_ui.add(_enableOk);
		_ui.add(_ok);
	}

	override void render(Window w, ScreenContext context, bool active)
	{
		_ui.setActive(active);

		const int borderAttr = context.theme.attr(active ? StyleId.BorderActive : StyleId.BorderInactive);
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

final class HelpBody : IViewBody
{
	override void render(Window w, ScreenContext context, bool active)
	{
		const int borderAttr = context.theme.attr(active ? StyleId.BorderActive : StyleId.BorderInactive);
		if (borderAttr != 0) wattron(w.handle(), borderAttr);
		scope (exit) { if (borderAttr != 0) wattroff(w.handle(), borderAttr); }

		w.border(WindowBorder.top | WindowBorder.right | WindowBorder.bottom);
		w.putAttr(0, 2, " HELP ", context.theme.attr(StyleId.Title));

		int y = 2;
		w.put(y++, 2, "Shift+Left / Shift+Right  -> switch window");
		w.put(y++, 2, "Tab                      -> switch widget (inside window)");
		w.put(y++, 2, "q / Esc                  -> quit");
		w.put(y++, 2, "OK button                -> returns Name:Password");
	}

	override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		if (event.isEnter)
		{
			return ScreenAction.push(new Simple());
		}

		return ScreenAction.none();
	}

	override void close()
	{

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

		ws.add(new View(leftWin,  new FormBody(), true));
		ws.add(new View(rightWin, new HelpBody(), true));
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
