"""Minimal D64 reader/writer for 35-track 1541 images."""
SPT = [0] + [21]*17 + [19]*7 + [18]*6 + [17]*5

def off(t, s):
    return (sum(SPT[1:t]) + s) * 256

class D64:
    def __init__(self, path):
        self.path = path
        self.d = bytearray(open(path, "rb").read())
        assert len(self.d) == 174848, len(self.d)

    def sec(self, t, s):
        o = off(t, s)
        return self.d[o:o+256]

    def setsec(self, t, s, b):
        o = off(t, s)
        assert len(b) == 256
        self.d[o:o+256] = b

    def entries(self):
        t, s = 18, 1
        out = []
        seen = set()
        while t:
            if (t, s) in seen: break
            seen.add((t, s))
            b = self.sec(t, s)
            for i in range(8):
                e = b[i*32:(i+1)*32]
                out.append(((t, s, i), e))
            t, s = b[0], b[1]
        return out

    def find(self, name_bytes):
        for loc, e in self.entries():
            if e[2] & 0x07 and e[2] & 0x80:
                nm = bytes(e[5:21]).rstrip(b"\xa0")
                if nm == name_bytes:
                    return loc, e
        return None, None

    def chain(self, t, s):
        blocks = []
        seen = set()
        while t:
            if (t, s) in seen: raise ValueError("loop")
            seen.add((t, s))
            blocks.append((t, s))
            b = self.sec(t, s)
            t, s = b[0], b[1]
        return blocks

    def read(self, name_bytes):
        loc, e = self.find(name_bytes)
        if not loc: return None
        out = bytearray()
        t, s = e[3], e[4]
        while t:
            b = self.sec(t, s)
            if b[0] == 0:
                out += b[2:b[1]+1]
            else:
                out += b[2:]
            t, s = b[0], b[1]
        return bytes(out)

    def save(self):
        open(self.path, "wb").write(self.d)

def name_str(b):
    s = ""
    for c in b:
        if c == 0xA0: break
        if 0x41 <= c <= 0x5A: s += chr(c+32)
        elif 0xC1 <= c <= 0xDA: s += chr(c-0x80)
        elif 0x20 <= c < 0x7F: s += chr(c)
        else: s += "{%02x}" % c
    return s
