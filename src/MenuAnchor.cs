using System;
using System.Threading;
using System.Runtime.InteropServices;
using System.Windows.Automation;

// Read UI Automation off the WPF dispatcher: an unresponsive host must not
// block the tray or quota reader. Bounds are physical screen pixels.
public static class PaceMenuAnchor {
    [StructLayout(LayoutKind.Sequential)]
    public struct Rect { public int Left, Top, Right, Bottom; }
    public sealed class Snapshot {
        public IntPtr Handle;
        public Rect Host;
        public double Right, CenterY;
        public DateTime Captured;
    }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr h);
    static readonly object gate = new object();
    static Snapshot latest;
    static int busy;
    static DateTime next = DateTime.MinValue;
    public static Snapshot Read(IntPtr handle) {
        lock (gate) { return latest != null && latest.Handle == handle ? latest : null; }
    }
    public static void Request(IntPtr handle) {
        if (DateTime.UtcNow < next || Interlocked.CompareExchange(ref busy, 1, 0) != 0) return;
        next = DateTime.UtcNow.AddMilliseconds(750);
        ThreadPool.QueueUserWorkItem(delegate {
            Snapshot result = null;
            try {
                Rect before, after;
                if (!GetWindowRect(handle, out before)) return;
                var root = AutomationElement.FromHandle(handle);
                var menuCondition = new PropertyCondition(AutomationElement.ControlTypeProperty, ControlType.MenuItem);
                var knownNames = new [] { "Help", "\u5e2e\u52a9", "Ayuda", "Hilfe", "Aide", "Aiuto", "Ajuda", "\u30d8\u30eb\u30d7", "\ub3c4\uc6c0\ub9d0", "\u0421\u043f\u0440\u0430\u0432\u043a\u0430" };
                AutomationElement help = null;
                foreach (var name in knownNames) {
                    help = root.FindFirst(TreeScope.Descendants, new AndCondition(menuCondition,
                        new PropertyCondition(AutomationElement.NameProperty, name)));
                    if (help != null && !help.Current.IsOffscreen) break;
                    help = null;
                }
                // Unknown locale: choose the right-most visible top-row MenuItem,
                // but stay clear of the native caption buttons.
                if (help == null) {
                    var dpi = Math.Max(96u, GetDpiForWindow(handle));
                    var maxBottom = before.Top + 58.0 * dpi / 96.0;
                    var captionLeft = before.Right - 150.0 * dpi / 96.0;
                    var items = root.FindAll(TreeScope.Descendants, menuCondition);
                    double rightMost = double.MinValue;
                    foreach (AutomationElement item in items) {
                        try {
                            if (item.Current.IsOffscreen) continue;
                            var r = item.Current.BoundingRectangle;
                            if (r.IsEmpty || r.Width <= 0 || r.Top < before.Top || r.Bottom > maxBottom || r.Right >= captionLeft) continue;
                            if (r.Right > rightMost) { rightMost = r.Right; help = item; }
                        } catch { }
                    }
                }
                if (help == null || help.Current.IsOffscreen) return;
                var bounds = help.Current.BoundingRectangle;
                if (!GetWindowRect(handle, out after)) return;
                if (before.Left != after.Left || before.Top != after.Top ||
                    before.Right != after.Right || before.Bottom != after.Bottom) return;
                if (bounds.IsEmpty || bounds.Width <= 0 || bounds.Top < after.Top ||
                    bounds.Bottom > after.Top + 120 || bounds.Right > after.Right) return;
                result = new Snapshot { Handle = handle, Host = after, Right = bounds.Right,
                    CenterY = bounds.Top + bounds.Height / 2, Captured = DateTime.UtcNow };
            } catch { }
            finally {
                lock (gate) { latest = result; }
                Interlocked.Exchange(ref busy, 0);
            }
        });
    }
}
