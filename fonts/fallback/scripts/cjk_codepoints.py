# Code points kept in the CJK fallback subset: every Han character of GB 2312, Big5, JIS X 0208 and KS X 1001
# (the national standard sets names are written in), all Hangul syllables and jamo, kana, Bopomofo, CJK
# punctuation and full-width forms.
import sys
cps=set()
def two_byte(codec, lead, trail):
    for a in lead:
        for b in trail:
            try:
                ch=bytes([a,b]).decode(codec)
            except Exception:
                continue
            if len(ch)==1: cps.add(ord(ch))
two_byte('gb2312', range(0xA1,0xF8), range(0xA1,0xFF))
two_byte('euc_jp', range(0xA1,0xF5), range(0xA1,0xFF))
two_byte('euc_kr', range(0xA1,0xFE), range(0xA1,0xFF))
two_byte('big5', range(0xA1,0xFA), list(range(0x40,0x7F))+list(range(0xA1,0xFF)))
han=[c for c in cps if 0x3400<=c<=0x9FFF or 0xF900<=c<=0xFAFF or 0x20000<=c<=0x2FFFF]
keep=set(han)
ranges=[(0x1100,0x11FF),(0x3130,0x318F),(0xA960,0xA97F),(0xAC00,0xD7A3),(0xD7B0,0xD7FF),  # Hangul
        (0x3040,0x30FF),(0x31F0,0x31FF),(0x3100,0x312F),(0x31A0,0x31BF),  # kana, bopomofo
        (0x3000,0x303F),(0xFF00,0xFFEF),(0x3200,0x32FF),(0x3300,0x33FF)]  # punctuation, full-width, enclosed
for a,b in ranges: keep.update(range(a,b+1))
print(len(han), len(keep), file=sys.stderr)
print(','.join('U+%04X'%c for c in sorted(keep)))
