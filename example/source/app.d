import ncui;

import simple;

void main()
{
	setLogLevel(LogLevel.info);

	auto config = SessionConfig(InputMode.raw, Cursor.hidden, Echo.off, Keypad.on);
	NCUI ncui = new NCUI(config);
	auto window = new Simple();
	ncui.run(window);
}
