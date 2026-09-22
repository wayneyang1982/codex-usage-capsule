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
        public uint Dpi;
        public DateTime Captured;
        public bool Projected;
    }
    [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr h, out Rect r);
    [DllImport("user32.dll")] static extern uint GetDpiForWindow(IntPtr h);
    static readonly object gate = new object();
    static Snapshot latest;
    static int busy;
    static DateTime next = DateTime.MinValue;
    // The title-bar menu is left-anchored. A recent verified Help position may
    // follow moves and roomy resizes while UIA catches up. Near the caption
    // controls or a responsive layout breakpoint, wait for fresh UIA instead.
    public static Snapshot Project(Snapshot anchor, Rect host, uint dpi, DateTime now) {
        if (anchor == null || (now - anchor.Captured).TotalSeconds > 30 ||
            (now - anchor.Captured).TotalSeconds < -1 || anchor.Dpi != dpi) return null;
        bool changed = anchor.Host.Left != host.Left || anchor.Host.Top != host.Top ||
            anchor.Host.Right != host.Right || anchor.Host.Bottom != host.Bottom;
        bool resized = anchor.Host.Right - anchor.Host.Left != host.Right - host.Left ||
            anchor.Host.Bottom - anchor.Host.Top != host.Bottom - host.Top;
        if (resized) {
            double minWidth = anchor.Right - anchor.Host.Left + 220.0 * dpi / 96.0;
            if (anchor.Host.Right - anchor.Host.Left < minWidth ||
                host.Right - host.Left < minWidth) return null;
        }
        double right = anchor.Right + host.Left - anchor.Host.Left;
        double centerY = anchor.CenterY + host.Top - anchor.Host.Top;
        if (right <= host.Left || right >= host.Right ||
            centerY <= host.Top || centerY >= host.Top + 120.0 * Math.Max(96u, dpi) / 96.0) return null;
        return new Snapshot { Handle = anchor.Handle, Host = host, Right = right,
            CenterY = centerY, Dpi = dpi, Captured = anchor.Captured,
            Projected = changed };
    }
    public static Snapshot Read(IntPtr handle, int left, int top, int right, int bottom, uint dpi) {
        Snapshot anchor;
        lock (gate) { anchor = latest != null && latest.Handle == handle ? latest : null; }
        return Project(anchor, new Rect { Left = left, Top = top, Right = right, Bottom = bottom },
            dpi, DateTime.UtcNow);
    }
    public static void Request(IntPtr handle) {
        if (DateTime.UtcNow < next || Interlocked.CompareExchange(ref busy, 1, 0) != 0) return;
        next = DateTime.UtcNow.AddMilliseconds(750);
        ThreadPool.QueueUserWorkItem(delegate {
            Snapshot result = null;
            try {
                Rect before, after;
                if (!GetWindowRect(handle, out before)) return;
                var beforeDpi = Math.Max(96u, GetDpiForWindow(handle));
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
                    var maxBottom = before.Top + 58.0 * beforeDpi / 96.0;
                    var captionLeft = before.Right - 150.0 * beforeDpi / 96.0;
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
                var afterDpi = Math.Max(96u, GetDpiForWindow(handle));
                if (before.Left != after.Left || before.Top != after.Top ||
                    before.Right != after.Right || before.Bottom != after.Bottom ||
                    beforeDpi != afterDpi) return;
                if (bounds.IsEmpty || bounds.Width <= 0 || bounds.Top < after.Top ||
                    bounds.Bottom > after.Top + 120.0 * afterDpi / 96.0 ||
                    bounds.Right >= after.Right - 150.0 * afterDpi / 96.0) return;
                result = new Snapshot { Handle = handle, Host = after, Right = bounds.Right,
                    CenterY = bounds.Top + bounds.Height / 2, Dpi = afterDpi,
                    Captured = DateTime.UtcNow };
            } catch { }
            finally {
                // A transient UIA failure during a drag must not erase the last
                // verified anchor. Read() will reject it if size/DPI/age differ.
                if (result != null) lock (gate) { latest = result; }
                Interlocked.Exchange(ref busy, 0);
            }
        });
    }
}
