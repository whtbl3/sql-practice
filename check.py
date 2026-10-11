# /// script
# requires-python = ">=3.9,<3.13"
# dependencies = ["pgserver", "psycopg2-binary"]
# ///
"""Usage:
  uv run check.py FILE               run and compare with -- EXPECTED (visible test)
  uv run check.py FILE -r            run only, print the output (or table states for UPDATE/DELETE)
  uv run check.py FILE -w            re-run every time the file is saved (Ctrl+C to stop); -w -r = watch without comparing
  uv run check.py FILE --submit      visible test + hidden tests in hidden/ (case names and pass/fail only)
  uv run check.py FILE --submit -v   same, and if everything passes, show every hidden case in detail

Row order of a SELECT must match -- EXPECTED by default. If the problem does not require an order
(LeetCode style "return in any order"), add this comment line at the top of the problem file:   -- @order: any
Numbers are compared by value (100 = 100.00); text and dates are compared literally.
Each query has a time limit (default 10 seconds, change with the SQL_TIMEOUT=seconds environment variable).
A header line `-- @forbid: <regex>` makes the problem reject queries matching that pattern (e.g. `-- @forbid: \\bOVER\\s*\\(`).

A problem file has 3 sections (order does not matter to the checker; the layout used is INPUT, EXPECTED, QUERY):
  -- INPUT      input tables as markdown tables (table name on its own line, then the table)
  -- EXPECTED   the expected result table
  -- QUERY      your SQL (SELECT, or UPDATE / DELETE / INSERT; several statements allowed)

A hidden test file hidden/<problem file name> has several blocks, each one a different data set:
  -- CASE <name of the scenario>
  -- INPUT ... -- EXPECTED ...       (no QUERY: the problem's QUERY is used)

SELECT: output is compared with EXPECTED by row order and column names.
UPDATE/DELETE/INSERT: put the table name to check on the line right above the EXPECTED table;
                      that table is compared AFTER the statements run (row order ignored).
Column types are inferred (integer, decimal, date, text). For an empty table or an all-NULL column,
give the type in the header: `amount:int`, `order_date:date`, `name:text`.
"""
import glob, os, re, shutil, sys, tempfile, time
from collections import Counter
from decimal import Decimal
os.environ.setdefault("LANG", "C.UTF-8"); os.environ.setdefault("LC_ALL", "C.UTF-8")
import pgserver, psycopg2

HERE = os.path.dirname(os.path.abspath(__file__))
TIMEOUT = int(os.environ.get("SQL_TIMEOUT", "10"))   # giây

class Fail(Exception): pass

class SQLFail(Fail):
    def __init__(self, msg, tle=False):
        super().__init__(msg); self.tle = tle

USE_COLOR = bool(sys.stdout.isatty() or os.environ.get("FORCE_COLOR")) and not os.environ.get("NO_COLOR")

def paint(s, color):
    """color: 'green' | 'red'. Tự tắt màu khi output không phải terminal (ghi file, pipe)."""
    return f"\033[{32 if color == 'green' else 31}m{s}\033[0m" if USE_COLOR else s

def cells(line):
    return [c.strip() for c in line.strip().strip("|").split("|")]

def parse_tables(block):
    """Trả về [(tên, [cột], [kiểu hoặc None], [dòng])]."""
    out, cur = [], None
    for raw in block.splitlines():
        line = raw.strip()
        if not line: continue
        if line.startswith("|"):
            row = cells(line)
            if all(re.fullmatch(r":?-{2,}:?", c) for c in row): continue
            if cur is None: cur = ["", [], [], []]; out.append(cur)
            if not cur[1]:
                for c in row:
                    n, _, t = c.partition(":"); cur[1].append(n.strip()); cur[2].append(t.strip() or None)
            else:
                cur[3].append([None if c == "NULL" else c for c in row])
        else:
            cur = [line.strip("`# "), [], [], []]; out.append(cur)
    return [tuple(t) for t in out]

def infer(vals):
    v = [x for x in vals if x is not None]
    if v and all(re.fullmatch(r"-?\d+", x) for x in v): return "BIGINT"
    if v and all(re.fullmatch(r"-?\d+\.\d+", x) for x in v): return "NUMERIC"
    if v and all(re.fullmatch(r"\d{4}-\d\d-\d\d", x) for x in v): return "DATE"
    if v and all(re.fullmatch(r"\d{4}-\d\d-\d\d[ T]\d\d:\d\d(:\d\d)?", x) for x in v): return "TIMESTAMP"
    return "TEXT"

def show(cols, rows, marks=None):
    """Bảng ASCII kiểu psql (+----+). marks: True = dòng khớp expected (xanh), False = đỏ."""
    rows = [["NULL" if v is None else str(v) for v in r] for r in rows]
    w = [max(len(x) for x in [c] + [r[i] for r in rows]) for i, c in enumerate(cols)]
    border = "+" + "+".join("-" * (x + 2) for x in w) + "+"
    fmt = lambda r: "| " + " | ".join(v.ljust(w[i]) for i, v in enumerate(r)) + " |"
    out = [border, fmt(cols), border]
    for i, r in enumerate(rows):
        out.append(paint(fmt(r), "green" if marks[i] else "red") if marks else fmt(r))
    out.append(border)
    if not rows: out.append("(0 rows)")
    return "\n".join(out)

def fetch(cur):
    return [d[0] for d in cur.description], [["NULL" if v is None else str(v) for v in r] for r in cur.fetchall()]

def split_sections(text, names):
    parts = re.split(rf"^--\s*({'|'.join(names)})\s*$", text, flags=re.M)
    return {parts[i]: parts[i + 1].strip() for i in range(1, len(parts), 2)}

# ---------------------------------------------------------------- chạy một bộ dữ liệu
def execute(conn, schema, inputs, query):
    """Tạo bảng trong schema riêng, chạy query. Trả về dict kết quả (hoặc {'error': ...})."""
    cur = conn.cursor()
    try:
        cur.execute(f'DROP SCHEMA IF EXISTS "{schema}" CASCADE')
        cur.execute(f'CREATE SCHEMA "{schema}"')
        cur.execute(f'SET search_path TO "{schema}"')
        for name, cols, types, rows in inputs:
            types = [t or infer([r[i] for r in rows]) for i, t in enumerate(types)]
            cur.execute(f'CREATE TABLE "{name}" ({", ".join(f"{c} {t}" for c, t in zip(cols, types))})')
            for r in rows:
                cur.execute(f'INSERT INTO "{name}" VALUES ({", ".join(["%s"] * len(cols))})', r)
        cur.execute(f"SET statement_timeout = '{TIMEOUT}s'")
        cur.execute(query)
        if cur.description is not None:
            cols, rows = fetch(cur)
            return {"dml": False, "cols": cols, "rows": rows}
        tables = {}
        for name, *_ in inputs:
            cur.execute(f'SELECT * FROM "{name}"'); tables[name] = fetch(cur)
        return {"dml": True, "tables": tables}
    except psycopg2.Error as e:
        conn.rollback()
        msg = (e.pgerror or str(e)).strip()
        if "statement timeout" in msg:
            return {"error": f"The query ran longer than {TIMEOUT}s. Check for a JOIN missing its condition, runaway recursion, or an overly heavy query.", "tle": True}
        return {"error": msg}

NUM = re.compile(r"-?\d+(\.\d+)?")

def canon(cell):
    """Số so theo GIÁ TRỊ: 100, 100.0, 100.00 là một. Chữ giữ nguyên."""
    return format(Decimal(cell).normalize(), "f") if NUM.fullmatch(cell) else cell

def ckey(row):
    return tuple(canon(c) for c in row)

def compare(res, exp, order_any=False):
    """So kết quả với bảng expected đầu tiên. order_any=True: không xét thứ tự dòng."""
    ename, ecols, _, erows = exp
    erows = [["NULL" if v is None else v for v in r] for r in erows]
    unordered = res["dml"] or order_any                         # UPDATE/DELETE luôn không xét thứ tự
    if res["dml"]:
        if ename not in res["tables"]:
            raise Fail(f"Table '{ename}' in -- EXPECTED is not in -- INPUT.")
        cols, got = res["tables"][ename]
    else:
        cols, got = res["cols"], res["rows"]
    if unordered:
        left, marks = Counter(map(ckey, erows)), []
        for r in got:
            marks.append(left[ckey(r)] > 0)
            if left[ckey(r)] > 0: left[ckey(r)] -= 1
    else:                                                      # so đúng vị trí từng dòng
        marks = [i < len(erows) and ckey(r) == ckey(erows[i]) for i, r in enumerate(got)]
    return dict(cols=cols, got=got, marks=marks, ecols=ecols, erows=erows, ename=ename, dml=res["dml"], unordered=unordered,
                names_ok=[c.lower() for c in cols] == [c.lower() for c in ecols],
                data_ok=all(marks) and len(got) == len(erows))

# ---------------------------------------------------------------- test nhìn thấy
def report_visible(res, exp_tables, run_only, order_any=False):
    if run_only or not exp_tables:
        if res["dml"]:
            print("Done. Table states after execution:")
            for n, (c, g) in res["tables"].items(): print(f"\n{n}\n{show(c, g)}")
        else:
            print("Output:\n" + show(res["cols"], res["rows"]))
        return True
    if res["dml"] and not exp_tables[0][0]:
        raise Fail("For UPDATE/DELETE problems, put the table name to check on the line right above the table in -- EXPECTED.")
    c = compare(res, exp_tables[0], order_any)
    title = f"Table {c['ename']} after execution:" if c["dml"] else "Output:"
    print(title + "\n" + show(c["cols"], c["got"], c["marks"]))
    if not c["names_ok"]:
        print(paint(f"\n✘ Wrong Answer: column names differ. output={c['cols']}  expected={c['ecols']}", "red"))
    if not c["data_ok"]:
        got, erows = c["got"], c["erows"]
        if c["unordered"]:
            print(paint("\n✘ Wrong Answer (row order ignored)", "red"))
            g, e = Counter(map(ckey, got)), Counter(map(ckey, erows))
            for r in (g - e): print(paint(f"  extra row (not expected): {list(r)}", "red"))
            for r in (e - g): print(paint(f"  missing row (expected)  : {list(r)}", "red"))
        else:
            print(paint("\n✘ Wrong Answer", "red"))
            for i in range(max(len(got), len(erows))):
                a = got[i] if i < len(got) else "(missing row)"
                b = erows[i] if i < len(erows) else "(extra row)"
                if (a if isinstance(a, str) else ckey(a)) != (b if isinstance(b, str) else ckey(b)): print(paint(f"  row {i+1}: output={a}  expected={b}", "red"))
    if c["names_ok"] and c["data_ok"]:
        print(paint("\n✔ Accepted", "green")); return True
    print("\nExpected Output:\n" + show(c["ecols"], c["erows"]))
    return False

# ---------------------------------------------------------------- test ẩn
def run_hidden(conn, path, query, verbose, order_any=False):
    found = glob.glob(os.path.join(HERE, "hidden", "**", os.path.basename(path)), recursive=True)
    hp = found[0] if found else None
    if not hp:
        print("\n(no hidden tests for this problem)"); return True
    parts = re.split(r"^--\s*CASE\s*(.*)$", open(hp, encoding="utf-8").read(), flags=re.M)
    cases = [(parts[i].strip(), parts[i + 1]) for i in range(1, len(parts), 2)]
    print(f"\nHidden tests ({len(cases)} cases):")
    results = []
    for k, (name, body) in enumerate(cases, 1):          # chạy hết các bộ trước, in sau
        sec = split_sections(body, ["INPUT", "EXPECTED"])
        inputs, exp = parse_tables(sec.get("INPUT", "")), parse_tables(sec.get("EXPECTED", ""))
        res = execute(conn, f"hidden{k}", inputs, query)
        if "error" in res:
            ok, why, detail = False, ("Time Limit Exceeded" if res.get("tle") else "Runtime Error"), res["error"]
        else:
            detail = compare(res, exp[0], order_any)
            ok = detail["names_ok"] and detail["data_ok"]
            why = "Wrong Answer (column names)" if not detail["names_ok"] else "Wrong Answer"
        results.append((k, name, inputs, ok, why, detail))

    passed = sum(r[3] for r in results)
    all_ok = passed == len(cases)
    show_all = verbose and all_ok                         # chỉ -v và đạt hết mới mở chi tiết
    for k, name, inputs, ok, why, detail in results:
        print(f"  Hidden test {k}/{len(cases)} ({name}): " + (paint("✔", "green") if ok else paint(f"✘ {why}", "red")))
        if show_all:
            for n, cols, _, rows in inputs: print(f"\n    INPUT {n}\n" + indent(show(cols, rows)))
            if isinstance(detail, dict):
                print("\n    Output:\n" + indent(show(detail["cols"], detail["got"], detail["marks"])))
                print("\n    Expected Output:\n" + indent(show(detail["ecols"], detail["erows"])))
            else:
                print("\n    " + detail)
            print()
    msg = f"Hidden tests: {passed}/{len(cases)} passed"
    print("\n" + paint(("✔ " if all_ok else "✘ ") + msg, "green" if all_ok else "red"))
    if all_ok and not verbose:
        print("(all passed: use `q N hv` to review the hidden test cases)")
    return all_ok

def indent(s): return "\n".join("    " + l for l in s.splitlines())

# ---------------------------------------------------------------- điều phối
def run_file(path, run_only, submit=False, verbose=False):
    text = open(path, encoding="utf-8").read()
    order_any = bool(re.search(r"^--\s*@order:\s*any\b", text, flags=re.M))
    sec = split_sections(text, ["INPUT", "QUERY", "EXPECTED"])
    query = sec.get("QUERY", "")
    if not re.sub(r"--.*", "", query).strip():
        raise Fail("No statement in the -- QUERY section yet. Write your query and run again.")
    for rx in re.findall(r"^--\s*@forbid:\s*(.+?)\s*$", text, flags=re.M):     # từ khóa bị cấm trong đề này
        if re.search(rx, re.sub(r"--.*", "", query), flags=re.I):
            raise Fail(f"This problem forbids the pattern /{rx}/ (see the header of the problem file).")
    inputs = parse_tables(sec.get("INPUT", ""))
    exp_tables = [] if run_only else parse_tables(sec.get("EXPECTED", ""))

    lines = text.splitlines()                      # dòng đầu của query nằm ở dòng nào của file
    h = next(i for i, l in enumerate(lines) if re.match(r"^--\s*QUERY\s*$", l))
    j = h + 1
    while j < len(lines) and not lines[j].strip(): j += 1
    qstart = j + 1                                 # số dòng (tính từ 1) của dòng đầu tiên trong query

    tmp = tempfile.mkdtemp()
    srv = pgserver.get_server(tmp, cleanup_mode="delete")
    try:
        conn = psycopg2.connect(srv.get_uri())
        res = execute(conn, "visible", inputs, query)
        if "error" in res:
            msg = res["error"]
            m = re.search(r"LINE (\d+):", msg)
            if m: msg += f"\n\n=> line {qstart + int(m.group(1)) - 1} of {os.path.basename(path)}"
            raise SQLFail(msg, res.get("tle", False))
        ok = report_visible(res, exp_tables, run_only, order_any)
        if submit and not run_only:
            if ok: ok = run_hidden(conn, path, query, verbose, order_any)
            else: print("\nPass the visible test first, then run the hidden tests.")
        return ok
    finally:
        srv.cleanup(); shutil.rmtree(tmp, ignore_errors=True)

def attempt(path, run_only, submit=False, verbose=False):
    try:
        return run_file(path, run_only, submit, verbose)
    except SQLFail as e:
        print(paint("✘ " + ("Time Limit Exceeded" if e.tle else "Runtime Error"), "red") + "\n\n" + str(e)); return False
    except Fail as e:
        print(e); return False

if __name__ == "__main__":
    sys.stdout.reconfigure(line_buffering=True)
    args = sys.argv[1:]
    flags = {a for a in args if a.startswith("-")}
    files = [a for a in args if not a.startswith("-")]
    if len(files) != 1: sys.exit(__doc__)
    path, run_only = files[0], bool(flags & {"-r", "--run"})
    submit, verbose = bool(flags & {"--submit"}), bool(flags & {"-v", "--verbose"})
    if flags & {"-w", "--watch"}:
        last = None
        print(f"Watching {path} (Ctrl+C to stop)...")
        try:
            while True:
                m = os.path.getmtime(path)
                if m != last:
                    last = m
                    print("\033[2J\033[H", end="")                    # xóa màn hình
                    print(f"[{time.strftime('%H:%M:%S')}] {path}\n")
                    attempt(path, run_only, submit, verbose)
                    print("\n(waiting for you to save the file...)")
                time.sleep(0.5)
        except KeyboardInterrupt:
            print("\nStopped.")
    else:
        sys.exit(0 if attempt(path, run_only, submit, verbose) else 1)
