using System;
using System.Diagnostics;
using System.Collections.Concurrent;
using System.Threading;
using System.Runtime.InteropServices;
public static class CapsuleNative {
 [DllImport("user32.dll")] public static extern int GetMessageTime();
 [StructLayout(LayoutKind.Sequential)] public struct RECT {public int Left,Top,Right,Bottom;}
 [DllImport("user32.dll")] public static extern IntPtr GetForegroundWindow();
 [DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr h,out uint id);
 [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h,out RECT r);
 [DllImport("user32.dll")] public static extern bool IsIconic(IntPtr h);
 [DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr h);
 [DllImport("user32.dll")] public static extern uint GetDpiForWindow(IntPtr h);
 [DllImport("user32.dll")] public static extern bool SetProcessDpiAwarenessContext(IntPtr c);
 [DllImport("user32.dll",EntryPoint="GetWindowLongPtrW")] public static extern IntPtr GetWindowLongPtr(IntPtr h,int i);
 [DllImport("user32.dll",EntryPoint="SetWindowLongPtrW")] public static extern IntPtr SetWindowLongPtr(IntPtr h,int i,IntPtr v);
 [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h,IntPtr after,int x,int y,int w,int ht,uint flags);
}
public sealed class CapsuleReader : IDisposable {
 Process process;
 ConcurrentQueue<string> lines=new ConcurrentQueue<string>();
 ConcurrentQueue<string> errors=new ConcurrentQueue<string>();
 public bool Running {get {return process!=null&&!process.HasExited;}}
 public int ProcessId {get {return Running?process.Id:0;}}
 public void Start(string exe,string args) {
  Dispose();
  process=new Process { StartInfo=new ProcessStartInfo(exe,args) {UseShellExecute=false,CreateNoWindow=true,RedirectStandardInput=true,RedirectStandardOutput=true,RedirectStandardError=true,WindowStyle=ProcessWindowStyle.Hidden}};
  process.OutputDataReceived+=(s,e)=>{if(e.Data!=null)lines.Enqueue(e.Data);};
  process.ErrorDataReceived+=(s,e)=>{if(e.Data!=null)errors.Enqueue(e.Data);};
  process.Start();process.BeginOutputReadLine();process.BeginErrorReadLine();
 }
 public bool Read(out string line){return lines.TryDequeue(out line);}
 public bool ReadError(out string line){return errors.TryDequeue(out line);}
 public void Send(string line){if(!Running)throw new InvalidOperationException("Codex App Server is not running");process.StandardInput.WriteLine(line);process.StandardInput.Flush();}
 public void Dispose(){if(process==null)return;try{if(!process.HasExited){process.StandardInput.Close();if(!process.WaitForExit(1200))process.Kill();}}catch{}try{process.Dispose();}catch{}process=null;}
}

// A no-activate WPF Popup can fail to retain mouse capture. While the details
// panel is open, observe only mouse-down coordinates and post a close request
// to our own window. The hook never blocks input or injects into other apps.
public sealed class CapsuleOutsideClick : IDisposable {
 public const int OutsideMessage=0x8015;
 const int WH_MOUSE_LL=14, WM_LBUTTONDOWN=0x0201, WM_RBUTTONDOWN=0x0204,
  WM_MBUTTONDOWN=0x0207, WM_XBUTTONDOWN=0x020B;
 [StructLayout(LayoutKind.Sequential)] struct POINT {public int X,Y;}
 [StructLayout(LayoutKind.Sequential)] struct MSLLHOOKSTRUCT {public POINT Pt;public uint MouseData,Flags,Time;public IntPtr ExtraInfo;}
 delegate IntPtr HookProc(int code,IntPtr message,IntPtr data);
 [DllImport("user32.dll",SetLastError=true)] static extern IntPtr SetWindowsHookEx(int id,HookProc callback,IntPtr module,uint thread);
 [DllImport("user32.dll")] static extern bool UnhookWindowsHookEx(IntPtr hook);
 [DllImport("user32.dll")] static extern IntPtr CallNextHookEx(IntPtr hook,int code,IntPtr message,IntPtr data);
 [DllImport("user32.dll")] static extern bool GetWindowRect(IntPtr window,out CapsuleNative.RECT rect);
 [DllImport("user32.dll",SetLastError=true)] static extern bool PostMessage(IntPtr window,int message,IntPtr wParam,IntPtr lParam);
 [DllImport("kernel32.dll")] static extern IntPtr GetModuleHandle(string name);
 IntPtr hook,capsule,panel;
 HookProc callback;
 int pending,generation;
 public int LastError {get;private set;}
 public int Generation {get {return generation;}}
 public bool Active {get {return hook!=IntPtr.Zero;}}
 public static bool IsOutside(int x,int y,CapsuleNative.RECT trigger,CapsuleNative.RECT details) {
  return !Contains(trigger,x,y) && !Contains(details,x,y);
 }
 static bool Contains(CapsuleNative.RECT r,int x,int y){return x>=r.Left && x<r.Right && y>=r.Top && y<r.Bottom;}
 public bool Start(IntPtr trigger,IntPtr details) {
  Stop(); LastError=0;
  if(trigger==IntPtr.Zero || details==IntPtr.Zero)return false;
  unchecked {generation++;}
  capsule=trigger;panel=details;callback=OnMouse;
  hook=SetWindowsHookEx(WH_MOUSE_LL,callback,GetModuleHandle(null),0);
  if(hook==IntPtr.Zero){LastError=Marshal.GetLastWin32Error();callback=null;}
  return Active;
 }
 IntPtr OnMouse(int code,IntPtr message,IntPtr data) {
  if(code>=0 && Active && Interlocked.CompareExchange(ref pending,0,0)==0) {
   long m=message.ToInt64();
   if(m==WM_LBUTTONDOWN || m==WM_RBUTTONDOWN || m==WM_MBUTTONDOWN || m==WM_XBUTTONDOWN) {
    var point=(MSLLHOOKSTRUCT)Marshal.PtrToStructure(data,typeof(MSLLHOOKSTRUCT));
    CapsuleNative.RECT trigger,details;
    if(GetWindowRect(capsule,out trigger) && GetWindowRect(panel,out details) &&
       IsOutside(point.Pt.X,point.Pt.Y,trigger,details) && Interlocked.Exchange(ref pending,1)==0) {
     if(!PostMessage(capsule,OutsideMessage,(IntPtr)generation,IntPtr.Zero))Interlocked.Exchange(ref pending,0);
    }
   }
  }
  return CallNextHookEx(hook,code,message,data);
 }
 public void Stop(){if(hook!=IntPtr.Zero){UnhookWindowsHookEx(hook);hook=IntPtr.Zero;}callback=null;panel=IntPtr.Zero;Interlocked.Exchange(ref pending,0);}
 public void Dispose(){Stop();}
}
