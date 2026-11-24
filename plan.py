#!/usr/bin/env python3
"""Study plan by priority. Called by `q plan`.

  q plan          every tier in study order, ✓ = solved (your own query under -- QUERY), and the next problem to do
  q plan S        one tier only (S, A, B or C)
  q plan todo     only the problems not solved yet

The order and the tiers live in priority.txt.
"""
import glob, os, re, sys

HERE = os.path.dirname(os.path.abspath(__file__))
TIERS = {
    "S": "gần như phỏng vấn nào cũng hỏi, phải tự viết trong 5 phút",
    "A": "hay gặp ở vòng 2 / công ty làm dữ liệu nhiều",
    "B": "analytics chuyên sâu (product, growth, analytics engineer)",
    "C": "nâng cao / data engineer, làm sau cùng",
}


def load_priority():
    """[(tier, 'group/nn')] in study order."""
    out = []
    with open(os.path.join(HERE, "priority.txt"), encoding="utf-8") as f:
        for line in f:
            line = line.split("#", 1)[0].strip()
            if line:
                tier, key = line.split()
                out.append((tier, key))
    return out


def problem_files():
    """{'group/nn': path} for every problem."""
    res = {}
    for f in glob.glob(os.path.join(HERE, "problems", "*", "*.sql")):
        g = os.path.basename(os.path.dirname(f))
        res[f"{g}/{os.path.basename(f).split('_')[0]}"] = f
    return res


def solved(path):
    text = open(path, encoding="utf-8").read()
    i = text.find("\n-- QUERY")
    body = text[i + 1:].split("\n", 1)[1] if i >= 0 and "\n" in text[i + 1:] else ""
    return any(l.strip() and not l.strip().startswith("--") for l in body.splitlines())


def title(path):
    head = open(path, encoding="utf-8").read().split("-- INPUT")[0]
    m = re.search(r"^-- Problem [^:]+: (.*?)\s+\[(\w+)\]", head, re.M)
    return (m.group(1), m.group(2)) if m else (os.path.basename(path), "?")


def main(args):
    want = args[0].upper() if args and args[0].upper() in TIERS else None
    todo_only = bool(args) and args[0].lower() == "todo"
    files = problem_files()
    prio = load_priority()
    listed = {k for _, k in prio}
    missing = sorted(set(files) - listed)
    unknown = [k for _, k in prio if k not in files]

    nxt = None
    for tier in TIERS:
        rows = [k for t, k in prio if t == tier and k in files]
        done = sum(solved(files[k]) for k in rows)
        if want and tier != want:
            continue
        print(f"\n{tier}  {done}/{len(rows)}  {TIERS[tier]}")
        for k in rows:
            ok = solved(files[k])
            if not ok and nxt is None:
                nxt = k
            if todo_only and ok:
                continue
            name, level = title(files[k])
            mark = "✓" if ok else " "
            arrow = "  <- làm tiếp" if k == nxt and not ok else ""
            print(f"  {mark} {k:<14} {level:<7} {name}{arrow}")

    if nxt is None and not want:
        print("\nĐã làm hết mọi bài trong lộ trình.")
    elif nxt:
        g, n = nxt.split("/")
        print(f"\nBài tiếp theo: q {g} {int(n)}")
    if missing:
        print(f"\nChưa xếp hạng (thêm vào priority.txt): {', '.join(missing)}")
    if unknown:
        print(f"\nCó trong priority.txt nhưng không có file đề: {', '.join(unknown)}")


if __name__ == "__main__":
    main(sys.argv[1:])
