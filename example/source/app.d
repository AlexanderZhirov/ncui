import ncui;

import std.stdio : writeln;

void main()
{
	auto config = SessionConfig(InputMode.raw, Cursor.normal, Echo.on, Keypad.on);
	Session session;
	try {
		session = new Session(config);
	} catch (Exception e) {
		writeln("Не удалось инициализировать сессию:\n\t", e.msg);
		return;
	}
	
	try {
		session.close();
	} catch (Exception e) {
		writeln("Не удалось закрыть сессию:\n\t", e.msg);
		return;
	}

	writeln("OK");
}
