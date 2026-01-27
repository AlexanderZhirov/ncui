module ncui.engine.workspacescreen;

// import ncui.core.session;
import ncui.core.event;
import ncui.core.ncwin;
import ncui.core.window;
import ncui.engine.action;
import ncui.engine.screen;
import ncui.engine.workspace;

abstract class WorkspaceScreen : IScreen, IIdleScreen
{
protected:
	Workspace _workspace;
	bool _built;

	this()
	{
		_workspace = new Workspace();
	}

	void build(ScreenContext context, Workspace workspace);

	ScreenAction handleGlobal(ScreenContext context, KeyEvent event)
	{
		return ScreenAction.none();
	}

	ScreenAction idleTick(ScreenContext context)
	{
		return ScreenAction.none();
	}

public:
	override NCWin inputWindow()
	{
		return _workspace.inputWindow();
	}

	final override void onHide(ScreenContext context)
	{
		_workspace.setWorkspaceActive(false);
		_workspace.render(context);
	}

	final override ScreenAction onShow(ScreenContext context)
	{
		if (!_built)
		{
			build(context, _workspace);
			_built = true;
		}

		_workspace.setWorkspaceActive(true);
		_workspace.render(context);

		return ScreenAction.none();
	}

	final override ScreenAction onTick(ScreenContext context)
	{
		auto action = idleTick(context);
		if (action.kind != ActionKind.None)
		{
			return action;
		}

		auto workspaceAction = _workspace.tick(context);
		if (workspaceAction.kind != ActionKind.None)
		{
			return workspaceAction;
		}

		_workspace.render(context);
		return ScreenAction.none();
	}


	override ScreenAction onChildResult(ScreenContext context, ScreenResult child)
	{
		return ScreenAction.none();
	}

	final override ScreenAction handle(ScreenContext context, KeyEvent event)
	{
		auto result = handleGlobal(context, event);

		if (result.kind != ActionKind.None)
		{
			return result;
		}

		if (_workspace.handleSwitcher(event))
		{
			_workspace.render(context);
			return ScreenAction.none();
		}

		auto active = _workspace.handleActive(context, event);

		if (active.kind != ActionKind.None)
		{
			return active;
		}

		_workspace.render(context);

		return ScreenAction.none();
	}

	override void close()
	{
		_workspace.close();
		_built = false;
	}

	~this()
	{
		close();
	}
}
