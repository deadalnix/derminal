module derminal;

import vte.Terminal;

final class Derminal : Terminal {
	GPid pid;
	
	this(string folder) {
		super();
		setScrollbackLines(2048);
		setMouseAutohide(true);
		
		forkCommandFull(VtePtyFlags.DEFAULT, folder, [Terminal.getUserShell()], [], cast(GSpawnFlags) 0, null, null, pid);
	}
	
	string getCurrentFolder() {
		import std.string;
		return format("/proc/%d/cwd", pid);
	}
}

