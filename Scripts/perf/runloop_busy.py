#!/usr/bin/env python3
"""Main-run-loop busy intervals from an xctrace `runloop-events` export.

Apple's hang definition: the busy portion of the main run loop, i.e. the time between the END of
one `waiting_for_events` period and the START of the next. xctrace XML de-duplicates values with
id/ref, so every element is resolved through an id table first.

usage: runloop_busy.py <runloop-events.xml> [min-ms]
"""
import sys
import xml.etree.ElementTree as ET

path = sys.argv[1]
min_ms = float(sys.argv[2]) if len(sys.argv) > 2 else 8.0

root = ET.parse(path).getroot()
ids = {}


def resolve(el):
    ref = el.get("ref")
    if ref is not None:
        return ids[ref]
    if el.get("id") is not None:
        ids[el.get("id")] = el
    return el


events = []  # (t_ns, START|END) for the main run loop's waiting_for_events
for row in root.iter("row"):
    t = kind = phase = None
    is_main = None
    for child in row:
        el = resolve(child)
        for sub in el.iter():
            if sub.get("id") is not None:
                ids[sub.get("id")] = sub
        tag = el.tag
        if tag == "event-time" and t is None:
            t = int(el.text)
        elif tag == "short-string" and kind is None:
            kind = el.text
        elif tag == "kdebug-func" and phase is None:
            phase = el.get("fmt")
        elif tag == "boolean" and is_main is None:
            is_main = el.text == "1"
    if t is not None and kind == "waiting_for_events" and is_main:
        events.append((t, phase))

events.sort()
busy = []
last_end = None
for t, phase in events:
    if phase == "END":
        last_end = t
    elif phase == "START" and last_end is not None:
        busy.append((last_end, (t - last_end) / 1e6))
        last_end = None

print(f"main run-loop busy intervals: {len(busy)}")
for label, lo in (("> 250 ms (Apple: tools report a hang)", 250), ("> 100 ms (Apple: no longer instant)", 100),
                  ("> 50 ms", 50), ("> 16.7 ms (one 60 Hz frame)", 16.7)):
    print(f"  {label}: {sum(1 for _, d in busy if d > lo)}")
print(f"\nintervals >= {min_ms} ms, in time order:")
for start, d in busy:
    if d >= min_ms:
        print(f"  t={start / 1e9:8.3f}s  busy={d:7.1f} ms")
