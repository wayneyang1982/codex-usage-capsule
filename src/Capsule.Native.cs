using System;
using System.Diagnostics;
using System.Collections.Concurrent;
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
