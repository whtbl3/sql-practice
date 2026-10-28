#!/usr/bin/env python3
"""Daily spaced-repetition review (Leitner boxes). Called by `q review`.

  q review              build today's set in review/ (grades yesterday's set first); later the same day: show it
  q review <k> [mode]   work on file k of today's set (modes as for problems: w, c, h, hv, s)
  q review check        submit every file of today's set now (report only, the schedule is not changed)
  q review stats        show every card: box, next review date, last result
  q review set <n>      change how many problems a day (default 3)

Only problems you have already solved (your own query under -- QUERY in problems/) are reviewed.
When a new set is built, the previous set is graded with the hidden tests:
  passed  -> next box, so the next review comes later: 1, 2, 4, 7, 15, 30, 60 days
  failed  -> back to box 0, due again tomorrow
  empty   -> unchanged, and it opens the next day's set
State lives in review/.state.json; review/ is not tracked by git.
"""
import datetime, glob, json, os, random, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
REVIEW = os.path.join(HERE, "review")
STATE = os.path.join(REVIEW, ".state.json")
INTERVALS = [1, 2, 4, 7, 15, 30, 60]          # days until the next review, by box
PLACEHOLDER = "-- write your query here"
TODAY = datetime.date.fromisoformat(os.environ["REVIEW_TODAY"]) if os.environ.get("REVIEW_TODAY") else datetime.date.today()


def load():
    try:
        with open(STATE, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return {"per_day": 3, "cards": {}, "session": None}


def save(st):
    os.makedirs(REVIEW, exist_ok=True)
    with open(STATE, "w", encoding="utf-8") as f:
        json.dump(st, f, indent=2, ensure_ascii=False)


def query_part(text):
    """Everything after the -- QUERY line (always the last section of a problem file)."""
    i = text.find("\n-- QUERY")
    if i < 0:
        return ""
    rest = text[i + 1:]
    return rest.split("\n", 1)[1] if "\n" in rest else ""


def has_own_query(text):
    body = [l for l in query_part(text).splitlines() if l.strip() and not l.strip().startswith("--")]
    return bool(body)


def blank_copy(text):
    i = text.find("\n-- QUERY")
    return text[: i + 1] + "-- QUERY\n" + PLACEHOLDER + "\n"


def title(src):
    head = open(os.path.join(HERE, src), encoding="utf-8").read().split("-- INPUT")[0]
    m = re.search(r"^-- Problem ([^:]+): (.*?)\s+\[(\w+)\]", head, re.M)
    return f"{m.group(1)}  {m.group(2)}  [{m.group(3)}]" if m else src


def grade(path):
    """'pass' | 'fail' | 'empty' for one review file."""
    text = open(path, encoding="utf-8").read()
    if not has_own_query(text):
        return "empty"
    out = subprocess.run(["uv", "run", "-q", "check.py", path, "--submit"], cwd=HERE,
                         capture_output=True, text=True).stdout
    out = re.sub(r"\x1b\[[0-9;]*m", "", out)
    return "pass" if "Accepted" in out and "✘" not in out else "fail"


def apply(card, result):
    if result == "pass":
        card["box"] = min(card["box"] + 1, len(INTERVALS) - 1)
        card["due"] = str(TODAY + datetime.timedelta(days=INTERVALS[card["box"]]))
    elif result == "fail":
        card["box"] = 0
        card["lapses"] = card.get("lapses", 0) + 1
        card["due"] = str(TODAY + datetime.timedelta(days=1))
    if result != "empty":
        card["reviews"] = card.get("reviews", 0) + 1
        card["last"] = f"{TODAY} {result}"


def sync_pool(st):
    """Every problem you have solved becomes a card (due today the first time)."""
    for f in sorted(glob.glob(os.path.join(HERE, "problems", "*", "*.sql"))):
        src = os.path.relpath(f, HERE)
        if src not in st["cards"] and has_own_query(open(f, encoding="utf-8").read()):
            st["cards"][src] = {"box": 0, "due": str(TODAY), "reviews": 0}


def show(st):
    s = st["session"]
    print(f"Review {s['date']}: {len(s['files'])} problem(s)\n")
    for k, it in enumerate(s["files"], 1):
        card = st["cards"][it["src"]]
        print(f"  {k}. {title(it['src'])}")
        print(f"     {it['file']}   (box {card['box']}, reviewed {card.get('reviews', 0)}x)")
    print("\n  q review <k>        watch file k, print the output on every save")
    print("  q review <k> h      submit file k (visible + hidden tests)")
    print("  q review <k> s      show the reference solution")
    print("  q review check      submit the whole set now")


def build(st):
    s = st["session"]
    if s and s["date"] == str(TODAY):
        show(st); return
    skipped = []
    if s:  # grade the previous set
        print(f"Grading the set of {s['date']} ...")
        for it in s["files"]:
            path = os.path.join(HERE, it["file"])
            res = grade(path) if os.path.exists(path) else "empty"
            apply(st["cards"][it["src"]], res)
            if res == "empty":
                skipped.append(it["src"])
            mark = {"pass": "✔ pass ", "fail": "✘ fail ", "empty": "· empty"}[res]
            nxt = st["cards"][it["src"]]["due"]
            print(f"  {mark}  {title(it['src'])}   -> next review {nxt}")
        print()
    sync_pool(st)
    if not st["cards"]:
        print("No solved problems yet: solve some problems first, then run `q review` again."); save(st); return
    # due cards first (oldest due date, lowest box), then top up with the cards due soonest
    # ties are shuffled with the date as seed, so the first days do not all come from the same group
    rng = random.Random(str(TODAY))
    items = list(st["cards"].items()); rng.shuffle(items)
    order = sorted(items, key=lambda kv: (kv[1]["due"], kv[1]["box"]))
    # problems left empty yesterday come back first
    picked = (skipped + [src for src, _ in order if src not in skipped])[: st["per_day"]]
    os.makedirs(REVIEW, exist_ok=True)
    for old in glob.glob(os.path.join(REVIEW, "*.sql")):
        os.remove(old)
    files = []
    for k, src in enumerate(picked, 1):
        dst = os.path.join("review", os.path.basename(src))
        with open(os.path.join(HERE, dst), "w", encoding="utf-8") as f:
            f.write(f"-- Review #{k} ({TODAY}): q review {k} [c|h|hv|s]\n")
            f.write(blank_copy(open(os.path.join(HERE, src), encoding="utf-8").read()))
        files.append({"src": src, "file": dst})
    st["session"] = {"date": str(TODAY), "files": files}
    save(st)
    show(st)


def check(st):
    s = st["session"]
    if not s:
        print("No review set yet: run `q review` first."); return
    for k, it in enumerate(s["files"], 1):
        res = grade(os.path.join(HERE, it["file"]))
        print(f"  {k}. {res:<5}  {title(it['src'])}")


def stats(st):
    sync_pool(st); save(st)
    rows = sorted(st["cards"].items(), key=lambda kv: (kv[1]["due"], kv[0]))
    due_now = sum(1 for _, c in rows if c["due"] <= str(TODAY))
    print(f"{len(rows)} cards, {due_now} due today or earlier, {st['per_day']} per day\n")
    print(f"  {'next review':<12} {'box':<4} {'reviews':<8} {'last':<16} problem")
    for src, c in rows:
        print(f"  {c['due']:<12} {c['box']:<4} {c.get('reviews', 0):<8} {c.get('last', '-'):<16} {src}")


def path_of(st, k, solution=False):
    s = st["session"]
    if not s or not (1 <= k <= len(s["files"])):
        sys.exit(f"No review file {k}: run `q review` to see today's set.")
    it = s["files"][k - 1]
    return it["src"].replace("problems/", "solutions/", 1) if solution else it["file"]


def main(argv):
    st = load()
    if not argv:
        build(st)
    elif argv[0] == "check":
        check(st)
    elif argv[0] == "stats":
        stats(st)
    elif argv[0] == "set" and len(argv) == 2 and argv[1].isdigit() and int(argv[1]) > 0:
        st["per_day"] = int(argv[1]); save(st)
        print(f"{st['per_day']} problem(s) a day from the next set on.")
    elif argv[0] in ("path", "solution") and len(argv) == 2 and argv[1].isdigit():
        print(path_of(st, int(argv[1]), solution=argv[0] == "solution"))
    else:
        sys.exit(__doc__)


if __name__ == "__main__":
    main(sys.argv[1:])
