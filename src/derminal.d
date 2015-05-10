module derminal;

import glib.Idle;

import vte.Terminal;

final class Derminal : Terminal {
	GPid pid;
	Idle idle;
	
	this(string folder) {
		super();
		setScrollbackLines(2048);
		setMouseAutohide(true);
		
		// Idle in order to get all callback ready before launching the terminal.
		idle = new Idle({
			// So it can be garbage collected.
			idle = null;
			
			// Start terminal.
			spawnSync(VtePtyFlags.DEFAULT, folder, [Terminal.getUserShell()], [], cast(GSpawnFlags) 0, null, null, pid, null);
			
			return false;
		});
	}
	
	string getCurrentFolder() {
		import std.string;
		return format("/proc/%d/cwd", pid);
	}
}

