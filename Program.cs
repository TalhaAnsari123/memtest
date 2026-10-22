using System.Runtime.InteropServices;

// Usage: Awake.exe [idleSeconds] [--no-nudge]
//   idleSeconds  how long you must be idle before it nudges the mouse (default 60)
//   --no-nudge   only keep the display/system awake, never touch the mouse

var idleThreshold = TimeSpan.FromSeconds(
    args.Length > 0 && int.TryParse(args[0], out var secs) ? secs : 60);
var nudge = !args.Contains("--no-nudge");

// Keep the system and display awake for as long as this process runs.
// Windows clears this automatically when the thread exits.
Native.SetThreadExecutionState(
    Native.ES_CONTINUOUS | Native.ES_SYSTEM_REQUIRED | Native.ES_DISPLAY_REQUIRED);

Console.WriteLine($"Running. Nudge: {(nudge ? $"after {idleThreshold.TotalSeconds:0}s idle" : "off")}. Ctrl+C to stop.");

while (true)
{
    // Only act when you've actually been idle, so it never fights real input.
    if (nudge && Native.IdleTime() >= idleThreshold)
        Native.NudgeMouse();

    Thread.Sleep(TimeSpan.FromSeconds(5));
}

static class Native
{
    public const uint ES_CONTINUOUS       = 0x80000000;
    public const uint ES_SYSTEM_REQUIRED  = 0x00000001;
    public const uint ES_DISPLAY_REQUIRED = 0x00000002;

    const uint INPUT_MOUSE = 0;
    const uint MOUSEEVENTF_MOVE = 0x0001;

    [DllImport("kernel32.dll")]
    public static extern uint SetThreadExecutionState(uint esFlags);

    [DllImport("user32.dll")]
    static extern bool GetLastInputInfo(ref LASTINPUTINFO plii);

    [DllImport("user32.dll", SetLastError = true)]
    static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);

    public static TimeSpan IdleTime()
    {
        var info = new LASTINPUTINFO { cbSize = (uint)Marshal.SizeOf<LASTINPUTINFO>() };
        if (!GetLastInputInfo(ref info)) return TimeSpan.Zero;
        var idleMs = unchecked((uint)Environment.TickCount - info.dwTime);
        return TimeSpan.FromMilliseconds(idleMs);
    }

    // Moves the cursor 1px right then 1px back: resets the idle timer,
    // cursor ends where it started.
    public static void NudgeMouse()
    {
        var inputs = new[]
        {
            Move(1, 0),
            Move(-1, 0),
        };
        SendInput((uint)inputs.Length, inputs, Marshal.SizeOf<INPUT>());
    }

    static INPUT Move(int dx, int dy) => new()
    {
        type = INPUT_MOUSE,
        mi = new MOUSEINPUT { dx = dx, dy = dy, dwFlags = MOUSEEVENTF_MOVE }
    };

    [StructLayout(LayoutKind.Sequential)]
    struct LASTINPUTINFO
    {
        public uint cbSize;
        public uint dwTime;
    }

    // MOUSEINPUT is the largest member of the native INPUT union,
    // so this sequential layout matches the native size on x86 and x64.
    [StructLayout(LayoutKind.Sequential)]
    struct INPUT
    {
        public uint type;
        public MOUSEINPUT mi;
    }

    [StructLayout(LayoutKind.Sequential)]
    struct MOUSEINPUT
    {
        public int dx;
        public int dy;
        public uint mouseData;
        public uint dwFlags;
        public uint time;
        public IntPtr dwExtraInfo;
    }
}
