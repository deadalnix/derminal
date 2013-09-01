module window;

import derminal;

import gdk.Event;
import gdk.Keysyms;
import gtk.Widget;

import gtk.AccelGroup;
import gtk.Button;
import gtk.CssProvider;
import gtk.HBox;
import gtk.Label;
import gtk.MainWindow;
import gtk.Notebook;

import glib.Str;
import glib.Util;

import gobject.Value;

final class DerminalMainWindow : MainWindow {
	Derminal term;
	Notebook tabs;
	
	this() {
		super("Derminal");
		setDecorated(true);
		setDefaultIconName("utilities-terminal");
		
		tabs = new Notebook();
		tabs.addOnPageAdded(&addTab);
		tabs.addOnPageRemoved(&removeTab);
		tabs.addOnSwitchPage(&switchTab);
		tabs.setShowTabs(false);
		tabs.setScrollable(true);
		tabs.setShowBorder(false);
		
		addDerminal();
		
		addOnKeyPress(&onKeyPress);
		add(tabs);
		
		showAll();
	}
	
	public bool onKeyPress(Event event, Widget widget) {
		auto key = event.key;
		auto modifier = key.state & AccelGroup.acceleratorGetDefaultModMask();
		
		// Do nothing for ctrl+super
		if((modifier & GdkModifierType.SUPER_MASK) &&
		   (modifier & GdkModifierType.CONTROL_MASK)) {
			return false;
		}
		
		auto shiftless = modifier & ~GdkModifierType.SHIFT_MASK;
		if(shiftless == GdkModifierType.CONTROL_MASK) {
			switch(key.keyval) with(GdkKeysyms) {
				case GDK_ISO_Left_Tab :
					auto n = tabs.getCurrentPage();
					n = (n - 1) % tabs.getNPages();
					tabs.setCurrentPage(n);
					break;
				
				case GDK_Tab :
					auto n = tabs.getCurrentPage();
					n = (n + 1) % tabs.getNPages();
					tabs.setCurrentPage(n);
					break;
				
				default :
					break;
			}
		}
		
		// Do nothing for non letters.
		if((key.keyval < GdkKeysyms.GDK_a || key.keyval > GdkKeysyms.GDK_z) &&
		   (key.keyval < GdkKeysyms.GDK_A || key.keyval > GdkKeysyms.GDK_Z)) {
			return false;
		}
		
		// Swap ctrl and super
		if((modifier & GdkModifierType.SUPER_MASK) ||
		   (modifier & GdkModifierType.CONTROL_MASK)) {
			key.state ^= (GdkModifierType.SUPER_MASK | GdkModifierType.CONTROL_MASK);
		}
		
		// handle ctrl + letters
		if(modifier != GdkModifierType.CONTROL_MASK) {
			return false;
		}
		
		switch(key.keyval) with(GdkKeysyms) {
			case GDK_c :
				term.copyClipboard();
				break;
			
			case GDK_t :
				addDerminal(term.getCurrentFolder());
				break;
			
			case GDK_v :
				term.pasteClipboard();
				break;
			
			default:
				break;
		}
		
		return true;
	}
	
	auto addDerminal(string folder = ".") {
		auto t = term = new Derminal(folder);
		auto l = new TabLabel(tabs, t);
		
		t.showAll();
		
		auto n = tabs.appendPage(t, l);
		tabs.setTabReorderable(t, true);
		tabs.setCurrentPage(n);
		
		tabs.childSetProperty(t, "tab-expand", new Value(true));
		tabs.childSetProperty(t, "tab-fill", new Value(true));
		
		t.grabFocus();
		
		t.addOnWindowTitleChanged((t) {
			auto title = term.getWindowTitle();
			if(title) {
				l.setTitle(title);
				if(t is term) {
					setTitle(title);
				}
			}
			
			tabs.showAll();
		});
		
		t.addOnChildExited((t) {
			auto n = tabs.pageNum(t);
			tabs.removePage(n);
		});
	}
	
	void addTab(Widget p, uint n, Notebook tabs) {
		if(tabs.getNPages() == 2) {
			tabs.setShowTabs(true);
		}
	}
	
	void removeTab(Widget p, uint n, Notebook tabs) {
		// Don't wait for the GC to stop the vte.
		.destroy(p);
		
		switch(tabs.getNPages()) {
			case 0:
				import gtk.Main;
				Main.quit();
				return;
			
			case 1:
				tabs.setShowTabs(false);
				break;
			
			default:
				break;
		}
	}
	
	void switchTab(Widget p, uint n, Notebook tabs) {
		term = cast(Derminal) p;
		assert(term);
		
		reHint();
		
		auto title = term.getWindowTitle();
		if(title) {
			setTitle(title);
		}
	}
	
	void reHint() {
		// TODO: cache and refresh only when needed.
		int cw = cast(int) term.getCharWidth();
		int ch = cast(int) term.getCharHeight();
		
		GtkBorder *inner_border;
		
		import gtkc.gtk;
		gtk_widget_style_get(term.getWidgetStruct(), Str.toStringz("inner-border"), &inner_border, null);
		
		GdkGeometry hints;
		hints.baseWidth = inner_border.left + inner_border.right;
		hints.baseHeight = inner_border.top + inner_border.bottom;
		
		gtk_border_free (inner_border);
		
		hints.widthInc = cw;
		hints.heightInc = ch;
		
		hints.minWidth = 4 * cw;
		hints.minHeight = ch;
		
		setGeometryHints(term, hints, GdkWindowHints.HINT_RESIZE_INC | GdkWindowHints.HINT_MIN_SIZE | GdkWindowHints.HINT_BASE_SIZE);
	}
}

final class TabLabel : HBox {
	private Notebook tabs;
	
	private Label l;
	
	private static CssProvider _provider;
	@property provider() {
		if(_provider is null) {
			auto style = "* {\n"
				"-GtkButton-default-border : 0;\n"
				"-GtkButton-default-outside-border : 0;\n"
				"-GtkButton-inner-border: 0;\n"
				"-GtkWidget-focus-line-width : 0;\n"
				"-GtkWidget-focus-padding : 0;\n"
				"padding: 0;\n"
			"}";
			
			_provider = new CssProvider();
			_provider.loadFromData(style);
		}
		
		return _provider;
	}
	
	this(Notebook tabs, Derminal t) {
		super(false, 5);
		
		this.tabs = tabs;
		
		l = new Label("Derminal");
		l.setAlignment(0, 0.5);
		l.setPadding(0, 0);
		l.setEllipsize(PangoEllipsizeMode.END);
		l.setSingleLineMode(true);
		
		packStart(l, true, true, 0);
		
		Button.setIconSize(GtkIconSize.MENU);
		auto b = new Button(StockID.CLOSE, (b) {
			auto n = tabs.pageNum(t);
			// t.destroy();
			tabs.removePage(n);
		}, true);
		b.setRelief(ReliefStyle.NONE);
		b.setFocusOnClick(false);
		
		b.getStyleContext().addProvider(provider, 600);
		b.setTooltipText("Close");
		
		int w, h;
		import gtk.IconSize;
		IconSize.lookupForSettings(b.getSettings(), GtkIconSize.MENU, w, h);
		b.setSizeRequest(w + 2, h + 2);
		
		packStart(b, false, false, 0);
		
		showAll();
	}
	
	void setTitle(string title) {
		setTooltipText(title);
		l.setText(title);
	}
}

