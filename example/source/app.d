import ncui;
import ncui.engine.theme;

import simple;

void main()
{
	setLogLevel(LogLevel.info, LogType.file, "/tmp/example.log");

	auto config = SessionConfig(InputMode.raw, Cursor.hidden, Echo.off, Keypad.on);
	NCUI ncui = new NCUI(config, new LightTheme());

	Simple screen = new Simple();

	try
	{
		ncui.run(screen);
	}
	catch (Exception e)
	{
		ncui.stop();
		info(e.msg);
	}
}
