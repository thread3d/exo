#!/usr/bin/env python3
"""Measure a served Strata model: prompt processing and decode tok/s, from the engine's own timings.

    python bench.py [port]

Greedy (temperature 0), non-streaming, so the answer is one call and the engine reports
`prompt N tokens = ... read in X ms (P tok/s), M generated in Y ms (D tok/s)`.
"""
import json
import statistics
import sys
import time
import urllib.request

PORT = int(sys.argv[1]) if len(sys.argv) > 1 else 8080
BASE = "http://127.0.0.1:%d" % PORT

FILLER = ("The quick brown fox jumps over the lazy dog, and the dog does not mind at all. "
          "Numbers, punctuation and ordinary prose keep the tokenizer honest here. ")
STORY = ("Write a short, plain story about a lighthouse keeper who finds a strange box on the beach. "
         "About 120 words.")


def ask(text, max_tokens, timeout=3600):
    body = json.dumps({"model": "auto", "messages": [{"role": "user", "content": text}],
                       "max_tokens": max_tokens, "temperature": 0, "stream": False}).encode()
    req = urllib.request.Request(BASE + "/v1/chat/completions", data=body,
                                 headers={"Content-Type": "application/json"})
    t0 = time.time()
    with urllib.request.urlopen(req, timeout=timeout) as r:
        out = json.loads(r.read().decode())
    wall = time.time() - t0
    return out, wall


def short(resp):
    return resp.get("timings") or {}


def run(label, text, max_tokens, repeat=1):
    rows = []
    for _ in range(repeat):
        resp, wall = ask(text, max_tokens)
        t = short(resp)
        rows.append((t, wall, resp))
    t, wall, resp = rows[-1]
    gen = (resp.get("usage") or {}).get("completion_tokens")
    print("%-22s prompt %6d tok | %6s tok/s | decode %5s tok/s | %5s gen tok | %7.1f s wall"
          % (label, t.get("prompt_n", 0), t.get("prompt_per_second", 0) and round(t["prompt_per_second"], 1),
             t.get("predicted_per_second", 0) and round(t["predicted_per_second"], 1), gen, wall))
    sys.stdout.flush()
    return t


def main():
    # a warm-up, so the first measured prompt is not paying for lazy first-touch
    print("warm-up ...")
    run("warm-up", "Say hello in five words.", 24)

    run("short question", "What is the capital of France? One sentence.", 96)
    run("story (120 words)", STORY, 200)
    run("story, repeat", STORY, 200)
    run("~1K-token document", FILLER * 40 + "\n\nIn one sentence: what animal is mentioned?", 64)
    run("~4K-token document", FILLER * 160 + "\n\nIn one sentence: what animal is mentioned?", 64)

    print("\n--- sample answer (greedy, story) ---")
    resp, _ = ask(STORY, 120)
    print(resp["choices"][0]["message"]["content"].strip()[:700])


if __name__ == "__main__":
    main()
