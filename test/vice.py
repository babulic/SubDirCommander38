import os, socket, subprocess, time, re

class Vice:
    def __init__(self, d8=None, d9=None, port=6510, warp=True, extra=None, truedrive=True):
        subprocess.run(["pkill", "-f", "x64sc"], capture_output=True)
        subprocess.run(["pkill", "-f", "Xvfb :.* -screen 0 1024x768x24 -nolisten tcp -auth /tmp/xvfb-run"], capture_output=True)
        time.sleep(1)
        self.port = port
        args = ["xvfb-run", "-a", "-s", "-screen 0 1024x768x24", "x64sc",
                "-default", "-silent", "-sounddev", "dummy",
                "-remotemonitor", "-remotemonitoraddress", f"ip4://127.0.0.1:{port}",
                "-ntsc" if False else "-pal"]
        if warp:
            args.append("-warp")
        if d8:
            args += ["-8", d8]
        if d9:
            args += ["-9", d9, "-drive9type", "1541"]
        if truedrive:
            args += ["-drive8truedrive", "-drive9truedrive"]
        if extra:
            args += extra
        self.proc = subprocess.Popen(args, stdout=open("/tmp/t/vice.log", "w"), stderr=subprocess.STDOUT)
        self.sock = None
        for _ in range(200):
            try:
                self.sock = socket.create_connection(("127.0.0.1", port), timeout=2)
                break
            except OSError:
                time.sleep(0.1)
        if not self.sock:
            raise RuntimeError("no monitor")
        self.sock.settimeout(5)
        self._drain(1.0)
        self.cmd("x", expect=False)

    def _drain(self, wait=0.3):
        out = b""
        self.sock.settimeout(wait)
        try:
            while True:
                d = self.sock.recv(65536)
                if not d:
                    break
                out += d
        except socket.timeout:
            pass
        self.sock.settimeout(5)
        return out.decode("latin1")

    def cmd(self, c, expect=True, wait=0.4, until=rb"\(C:\$[0-9a-f]{4}\) $"):
        self.sock.sendall((c + "\n").encode("latin1"))
        if not expect:
            time.sleep(0.05)
            return ""
        out = b""
        t0 = time.time()
        self.sock.settimeout(0.05)
        while time.time() - t0 < wait + 3:
            try:
                d = self.sock.recv(65536)
                if d:
                    out += d
                    if re.search(until, out, re.S):
                        break
            except socket.timeout:
                pass
        self.sock.settimeout(5)
        return out.decode("latin1")

    def enter(self):
        # any command stops the CPU and enters the monitor
        return self.cmd("r", wait=0.3, until=rb"STOPWATCH.*\n.*\n\(C:\$[0-9a-f]{4}\) $")

    def go(self):
        self.cmd("x", expect=False)

    def mem(self, start, end):
        for attempt in range(5):
            self.enter()
            txt = self.cmd(f"m {start:04x} {end:04x}", wait=0.6,
                           until=rb">C:.*\n\(C:\$[0-9a-f]{4}\) $")
            self.go()
            data = {}
            for line in txt.splitlines():
                m = re.match(r">C:([0-9a-f]{4})\s+((?:[0-9a-f]{2}\s+)+)", line.strip() + " ")
                if m:
                    a = int(m.group(1), 16)
                    for i, h in enumerate(m.group(2).split()[:16]):
                        if a + i <= end:
                            data[a + i] = int(h, 16)
            if all(a in data for a in range(start, end + 1)):
                return bytes(data[a] for a in range(start, end + 1))
            self.lastbad = txt
            time.sleep(0.2)
            self._drain(0.5)
        raise RuntimeError(f"mem read failed {start:04x}: {self.lastbad[-300:]!r}")

    def line(self):
        b = self.mem(0x39, 0x3A)
        return b[0] + 256 * b[1]

    def wait_line(self, lines, timeout=60):
        if isinstance(lines, int):
            lines = (lines,)
        t0 = time.time()
        while time.time() - t0 < timeout:
            if self.line() in lines:
                return True
            time.sleep(0.2)
        return False

    def key(self, k, at=5170, timeout=60):
        """Send one key once the program sits in its key wait (default BASIC line 5170)."""
        if at is not None:
            if not self.wait_line(at, timeout):
                raise RuntimeError(f"not at line {at}, at {self.line()}")
            time.sleep(0.15)
        self.enter()
        self.cmd(f"> 0277 {k:02x}", wait=0.15)
        self.cmd("> 00c6 01", wait=0.15)
        self.go()
        time.sleep(0.4)
        if at is not None:
            self.wait_line(at, timeout)
            time.sleep(0.2)

    def poke(self, addr, vals):
        self.enter()
        self.cmd(f"> {addr:04x} " + " ".join(f"{v:02x}" for v in vals), wait=0.2)
        self.go()

    def keys(self, petscii, gap=0.6):
        # feed up to 9 chars at a time through the keyboard buffer
        for i in range(0, len(petscii), 8):
            chunk = petscii[i:i + 8]
            for _ in range(100):
                n = self.mem(0xC6, 0xC6)[0]
                if n == 0:
                    break
                time.sleep(0.1)
            self.enter()
            self.cmd(f"> 0277 " + " ".join(f"{c:02x}" for c in chunk), wait=0.15)
            self.cmd(f"> 00c6 {len(chunk):02x}", wait=0.15)
            self.go()
            time.sleep(gap)

    def screen(self):
        raw = self.mem(0x0400, 0x07E7)
        lines = []
        for r in range(25):
            s = ""
            for c in range(40):
                b = raw[r * 40 + c]
                rev = b & 0x80
                b &= 0x7F
                if b == 0:
                    ch = "@"
                elif 1 <= b <= 26:
                    ch = chr(ord("a") + b - 1)
                elif 0x41 <= b <= 0x5A:
                    ch = chr(b)
                elif 0x20 <= b <= 0x3F:
                    ch = chr(b)
                elif b == 0x1E:
                    ch = "^"
                elif b == 0x1F:
                    ch = "_"
                elif b == 0x1C:
                    ch = "#"
                else:
                    ch = "~"
                s += ch
            lines.append(s)
        return lines

    def rev_rows(self):
        raw = self.mem(0x0400, 0x07E7)
        return [sum(1 for c in range(27) if raw[r * 40 + c] & 0x80) for r in range(25)]

    def show(self, title=""):
        print("=" * 10, title)
        rv = self.rev_rows()
        for i, l in enumerate(self.screen()):
            mark = "*" if rv[i] > 20 else " "
            print(f"{i:2d}{mark}|{l}|")

    def shot(self, path):
        self.enter()
        self.cmd(f'screenshot "{path}" 2', wait=1.0)
        self.go()

    def wait_text(self, text, timeout=60):
        t0 = time.time()
        while time.time() - t0 < timeout:
            if any(text in l for l in self.screen()):
                return True
            time.sleep(0.5)
        return False

    def quit(self):
        try:
            self.enter()
            self.cmd("quit", expect=False)
        except Exception:
            pass
        time.sleep(0.5)
        try:
            self.proc.terminate()
            self.proc.wait(5)
        except Exception:
            self.proc.kill()
        subprocess.run(["pkill", "-f", "x64sc"], capture_output=True)


def pet(s):
    """ASCII-ish to PETSCII for typing in lowercase mode: a-z -> 0x41.., A-Z -> 0xC1.."""
    out = []
    for ch in s:
        o = ord(ch)
        if "a" <= ch <= "z":
            out.append(o - 32)
        elif "A" <= ch <= "Z":
            out.append(o + 0x80)
        elif ch == "\n":
            out.append(13)
        else:
            out.append(o)
    return out

DOWN, UP, RIGHT, LEFT, RET = 0x11, 0x91, 0x1D, 0x9D, 0x0D

NAME38 = [0xD3] + pet('ub') + [0xC4] + pet('ir') + [0xC3] + pet('ommand.38')
NAME37 = [0xD3] + pet('ub') + [0xC4] + pet('ir') + [0xC3] + pet('ommand.37')

def start(d8, name=NAME38, d9=None, drive=None, list_line=5170, warp=True):
    v = Vice(d8=d8, d9=d9, warp=warp)
    time.sleep(3)
    v.keys(pet('load"') + name + pet('",8\n'))
    v.wait_text("ready.", 120); time.sleep(1)
    v.keys(pet('run\n'))
    v.wait_line((5007, list_line), 60)
    time.sleep(0.5)
    if v.line() == 5007:
        v.keys(([drive] if drive else []) + [RET])
        v.wait_line(list_line, 120)
    elif drive and drive != ord('8'):
        v.key(ord('1'), at=list_line)
        v.wait_line(5007, 60); time.sleep(0.5)
        v.keys([drive, RET])
        v.wait_line(list_line, 120)
    time.sleep(0.5)
    return v

def labels(path="/tmp/t/sdc38.lbl"):
    out = {}
    for l in open(path):
        m = re.match(r'(\w+)\s*=\s*\$([0-9a-f]+)', l)
        if m:
            out[m.group(1)] = int(m.group(2), 16)
    return out

class MLVice(Vice):
    """Vice session driving the ML commander: waits on the CPU sitting in getkey/GETIN."""
    def setlabels(self, lab):
        self.lab = lab

    def pc(self):
        t = self.enter()
        self.go()
        m = re.search(r"\.;([0-9a-f]{4}) ", t)
        return int(m.group(1), 16) if m else -1

    def idle(self, timeout=120):
        g = self.lab["getkey"]
        t0 = time.time()
        hits = 0
        while time.time() - t0 < timeout:
            p = self.pc()
            if g <= p <= g + 6 or 0xF13E <= p <= 0xF15F or 0xE5B4 <= p <= 0xE5CA:
                hits += 1
                if hits >= 2 and self.mem(0xC6, 0xC6)[0] == 0:
                    return True
            else:
                hits = 0
            time.sleep(0.15)
        return False

    def mkey(self, k, timeout=120):
        if not self.idle(timeout):
            raise RuntimeError("not idle, pc=%04x" % self.pc())
        self.enter()
        self.cmd(f"> 0277 {k:02x}", wait=0.15)
        self.cmd("> 00c6 01", wait=0.15)
        self.go()
        time.sleep(0.3)
        self.idle(timeout)

    def mtype(self, keys, timeout=120):
        for k in keys:
            self.mkey(k, timeout)

NAMEML = [0x25, 0xD3] + pet('ub') + [0xC4] + pet('ir') + [0xC3] + pet('ommand38')

def mlstart(d8, d9=None, drive=None, name=NAMEML):
    v = MLVice(d8=d8, d9=d9)
    v.setlabels(labels())
    time.sleep(3)
    v.keys(pet('load"') + name + pet('",8\n'))
    v.wait_text("ready.", 120); time.sleep(1)
    v.keys(pet('run\n'))
    time.sleep(1)
    v.idle(60)
    if drive:
        v.mkey(drive)
    v.mkey(RET)
    v.idle(120)
    return v
