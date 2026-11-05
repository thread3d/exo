#!/usr/bin/env python3
"""setconfig.py - size the Strata run config for a card with its own memory.

    python setconfig.py <config.json> --context 4096 --reserve-mib 2560 [--no-mtp]

The first request on this machine froze it: the setup had written Apple-Silicon defaults (64 expert-cache slots,
64 K context) onto an 8 GB Radeon, so the card had 0 MiB free and the driver paged GPU memory.  These are the
settings that leave the card room: a cache sized by the engine against a reserve, and a context whose KV fits.
"""
import json
import os
import sys

path = sys.argv[1]
argv = sys.argv[2:]
ctx = int(argv[argv.index("--context") + 1]) if "--context" in argv else 8192
reserve = argv[argv.index("--reserve-mib") + 1] if "--reserve-mib" in argv else "2048"
droptp = "--no-mtp" in argv

c = json.loads(open(path, encoding="utf-8").read())
args = c["args"]


def set_flag(name, value=None):
    global args
    if name in args:
        i = args.index(name)
        if value is None:
            del args[i:i + 2]
        else:
            args[i + 1] = value
    elif value is not None:
        args += [name, value]


set_flag("--expert-cache", "auto")
set_flag("--vram-reserve-mib", reserve)
set_flag("--max-context", str(ctx))
if droptp:
    # one token per step: no draft layer, no verify window, fewer buffers on a card with little to spare
    set_flag("--mtp")
    set_flag("--spec")

env = {**c.get("env", {})}
env.pop("STRATA_METAL_WIRE_BUFFERS", None)   # the mlock wiring stays off: it made the freeze worse
env["STRATA_METAL_PROMPT_GEMM"] = "0"         # MetalPerformancePrimitives is macOS 26: no prompt GEMM on Metal 2
env["STRATA_METAL_PROMPT"] = "window"          # prompts run through the decode window instead
c["env"] = env

open(path, "w", encoding="utf-8").write(json.dumps(c, indent=1))
print("args:", " ".join(args))
print("env :", env)
print("exists:", os.path.exists(path))
