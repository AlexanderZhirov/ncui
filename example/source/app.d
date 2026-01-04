import ncui;

import std.stdio : writeln;

void main()
{
	auto config = SessionConfig(InputMode.raw, Cursor.normal, Echo.on);
	auto session = new Session(config);
	session.close();
}
