"""Checks every quote in data/quotes.json against its source, again.

    python tools/verify_quotes.py

Needs the network (the offline gate is V20 in validate.py). Sources are
cached outside the repository, in the system temp directory.

- Qur'an: each ayah's excerpt must appear in Pickthall's text from Tanzil.
- Greek and Roman: each excerpt must appear in the Project Gutenberg text
  named in verifiedAt. Only the first letter's case may differ: an excerpt
  that starts mid-sentence may be capitalised.
- Hadith: the text is the meaning in plain English, so only the reference is
  checked — the collection's hadith with that standard number must exist in
  the open dataset named in verifiedAt.
"""
import json
import os
import re
import sys
import tempfile
import urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(tempfile.gettempdir(), "keller-twelve-quote-sources")
os.makedirs(CACHE, exist_ok=True)


def fetch(url, name):
    path = os.path.join(CACHE, name)
    if not os.path.exists(path):
        req = urllib.request.Request(url, headers={"User-Agent": "keller-twelve"})
        with urllib.request.urlopen(req, timeout=60) as r, open(path, "wb") as f:
            f.write(r.read())
    with open(path, encoding="utf-8") as f:
        return f.read()


def norm(s):
    return re.sub(r"\s+", " ", s).strip()


quotes = json.load(open(os.path.join(ROOT, "data", "quotes.json"),
                        encoding="utf-8"))["quotes"]
failures = []

ayat = {}
for line in fetch("https://tanzil.net/trans/en.pickthall",
                  "pickthall.txt").splitlines():
    parts = line.split("|", 2)
    if len(parts) == 3 and parts[0].isdigit():
        ayat[f"{parts[0]}:{parts[1]}"] = norm(parts[2])

for q in quotes:
    qid, text, att = q["id"], q["text"], q["attribution"]
    trad = q["tradition"]
    if trad == "quran":
        m = re.fullmatch(r"Qur’an (\d+):(\d+)(?:–(\d+))?", att)
        if not m:
            failures.append(f"{qid}: cannot read {att!r}")
            continue
        surah, first = int(m.group(1)), int(m.group(2))
        last = int(m.group(3) or first)
        lines = text.split("\n")
        refs = [f"{surah}:{a}" for a in range(first, last + 1)]
        if len(lines) != len(refs):
            failures.append(f"{qid}: {len(lines)} lines for {len(refs)} ayat")
            continue
        for ref, line in zip(refs, lines):
            if norm(line.strip("… ")) not in ayat.get(ref, ""):
                failures.append(f"{qid}: not in Pickthall {ref}: {line!r}")
    elif trad in ("greek", "roman"):
        m = re.search(r"gutenberg\.org/ebooks/(\d+)", q.get("verifiedAt", ""))
        if not m:
            failures.append(f"{qid}: no Gutenberg source")
            continue
        n = m.group(1)
        book = norm(fetch(
            f"https://www.gutenberg.org/cache/epub/{n}/pg{n}.txt", f"{n}.txt"))
        core = norm(text.strip("… "))
        if core not in book and (core[0].lower() + core[1:]) not in book:
            failures.append(f"{qid}: not in Gutenberg #{n}: {core[:50]!r}")
    elif trad == "hadith":
        m = re.fullmatch(r"(Sahih al-Bukhari|Sahih Muslim) (\d+)", att)
        if not m:
            failures.append(f"{qid}: cannot read {att!r}")
            continue
        url = q["verifiedAt"]
        d = json.loads(fetch(url, url.rsplit("/", 2)[-2] + "-"
                             + url.rsplit("/", 1)[-1]))
        h = d["hadiths"][0]
        number = str(h.get("arabicnumber") or h.get("hadithnumber"))
        if number.split(".")[0] != m.group(2):
            failures.append(f"{qid}: {url} is number {number}, not {m.group(2)}")

if failures:
    print(f"FAILED: {len(failures)}")
    for f in failures:
        print("  X", f)
    sys.exit(1)
print(f"All {len(quotes)} quotes match their sources.")
