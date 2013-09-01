module main;

import window;

import gtk.Main;

void main(string[] args) {
	Main.init(args);
	new DerminalMainWindow();
	Main.run();
}

