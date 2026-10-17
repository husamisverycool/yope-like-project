# BLOCKED values

Generated. These may not ship; release builds fail to compile if code uses any of them.

| item | surface | why |
|---|---|---|
| token `camera.overnight.layout.stackCards` | camera.overnight | Lapse's stack is measurable only as a whole (bounding box including its glow), so its cards and fan inside size.global.circleButtonLarge cannot be traced; until a capture closes it the leading slot stays empty in 9 AM mode (the library circle is hidden). Smallest capture: one raw screenshot of Lapse's stack and a 60 fps recording of its shutter press up to the stack update. |
