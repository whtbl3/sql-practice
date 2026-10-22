# /// script
# requires-python = ">=3.9,<3.13"
# dependencies = ["pgserver", "psycopg2-binary", "pandas"]
# ///
"""Usage:
  uv run check.py FILE               run and compare with -- EXPECTED (visible test)
  uv run check.py FILE -r            run only, print the output (or table states for UPDATE/DELETE)
  uv run check.py FILE -w            re-run every time the file is saved (Ctrl+C to stop); -w -r = watch without comparing
  uv run check.py FILE --submit      visible test + hidden tests in hidden/ (case names and pass/fail only)
  uv run check.py FILE --submit -v   same, and if everything passes, show every hidden case in detail
  uv run check.py FILE.sql --new-py  create FILE.py: the same problem, to be solved with pandas

Pandas problems (FILE.py): the problem text (INPUT, EXPECTED, headers) sits in the module docstring, in the
same format as a .sql file. Define solve(<table>, ...) with one parameter per input table (named after the
table); each one is a DataFrame and solve() returns the result DataFrame. Types: int -> Int64 (nullable),
decimal -> float64, date/timestamp -> datetime64, text -> object (NULL = None/NaN/NaT). Hidden tests are
hidden/<name>.py if it exists, otherwise hidden/<name>.sql, so a pandas version reuses the SQL hidden tests.

Row order of a SELECT must match -- EXPECTED by default. If the problem does not require an order
(LeetCode style "return in any order"), add this comment line at the top of the problem file:   -- @order: any
Numbers are compared by value (100 = 100.00); text and dates are compared literally.
Each query has a time limit (default 10 seconds, change with the SQL_TIMEOUT=seconds environment variable).
A header line `-- @forbid: <regex>` makes the problem reject queries matching that pattern (e.g. `-- @forbid: \\bOVER\\s*\\(`).

A problem file has 3 sections (order does not matter to the checker; the layout used is INPUT, EXPECTED, QUERY):
  -- INPUT      input tables as markdown tables (table name on its own line, then the table)
  -- EXPECTED   the expected result table
  -- QUERY      your SQL (SELECT, or UPDATE / DELETE / INSERT; several statements allowed)
and optionally, for function / procedure / trigger problems:
  -- CALL       statements written by the problem, run right AFTER your QUERY (e.g. SELECT * FROM fn(2);
                CALL proc(1, 2);). Its result (or the table states) is what gets compared. A hidden case
                may have its own -- CALL; otherwise the problem's CALL is used.
  EXPECTED may be the single line `ERROR: <text>`: the statements must then fail with an error whose
  message contains <text> (case-insensitive), e.g. a procedure that must RAISE EXCEPTION.
  RAISE NOTICE messages from the visible test are printed above the output.

A hidden test file hidden/<problem file name> has several blocks, each one a different data set:
  -- CASE <name of the scenario>
  -- INPUT ... -- EXPECTED ...       (no QUERY: the problem's QUERY is used)

SELECT: output is compared with EXPECTED by row order and column names.
UPDATE/DELETE/INSERT: put the table name to check on the line right above the EXPECTED table;
                      that table is compared AFTER the statements run (row order ignored).
Column types are inferred (integer, decimal, date, text). For an empty table or an all-NULL column,
give the type in the header: `amount:int`, `order_date:date`, `name:text`.
"""
import ast, glob, inspect, os, re, shutil, signal, sys, tempfile, time, traceback
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
def execute(conn, schema, inputs, query, call=""):
    """Tạo bảng trong schema riêng, chạy query rồi call (nếu có). Trả về dict kết quả (hoặc {'error': ...})."""
    cur = conn.cursor()
    phase = "setup"
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
        del conn.notices[:]
        phase = "query"; cur.execute(query)
        if re.sub(r"--.*", "", call).strip():
            phase = "call"; cur.execute(call)
        notices = [n.strip() for n in conn.notices]
        if cur.description is not None:
            cols, rows = fetch(cur)
            return {"dml": False, "cols": cols, "rows": rows, "notices": notices}
        tables = {}
        for name, *_ in inputs:
            cur.execute(f'SELECT * FROM "{name}"'); tables[name] = fetch(cur)
        return {"dml": True, "tables": tables, "notices": notices}
    except psycopg2.Error as e:
        conn.rollback()
        msg = (e.pgerror or str(e)).strip()
        if "statement timeout" in msg:
            return {"error": f"The query ran longer than {TIMEOUT}s. Check for a JOIN missing its condition, runaway recursion, or an overly heavy query.", "tle": True}
        return {"error": msg, "phase": phase}

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

# ---------------------------------------------------------------- pandas
class _Timeout(Exception): pass

def _alarm(*_): raise _Timeout()

def py_error(path, e):
    """Thông báo lỗi Python, kèm dòng gây lỗi trong file bài (bỏ qua các frame của pandas)."""
    msg = "".join(traceback.format_exception_only(type(e), e)).strip()
    frames = [f for f in traceback.extract_tb(e.__traceback__) if f.filename == path]
    if frames: msg += f"\n\n=> line {frames[-1].lineno} of {os.path.basename(path)}: {frames[-1].line}"
    return msg

def to_frame(cols, types, rows):
    import pandas as pd
    df = pd.DataFrame(rows, columns=cols, dtype=object)
    for i, c in enumerate(cols):
        t = (types[i] or infer([r[i] for r in rows])).upper()
        if t in ("INT", "INTEGER", "BIGINT", "SMALLINT"):
            df[c] = pd.array([None if v is None else int(v) for v in df[c]], dtype="Int64")
        elif t in ("NUMERIC", "DECIMAL", "FLOAT", "REAL"):
            df[c] = pd.to_numeric(df[c]).astype("float64")
        elif t in ("DATE", "TIMESTAMP"):
            df[c] = pd.to_datetime(df[c])
    return df

def frame_rows(df):
    """DataFrame -> (cột, dòng dạng chuỗi) như fetch(). Cột datetime toàn nửa đêm in dạng ngày, như DATE của Postgres."""
    import pandas as pd
    rows = [[] for _ in range(len(df))]
    for i in range(df.shape[1]):
        vals = df.iloc[:, i].tolist()
        stamps = [v for v in vals if isinstance(v, pd.Timestamp) and not pd.isna(v)]
        fmt = "%Y-%m-%d" if all(v == v.normalize() for v in stamps) else "%Y-%m-%d %H:%M:%S"
        for r, v in zip(rows, vals):
            if pd.api.types.is_scalar(v) and pd.isna(v): r.append("NULL")
            elif isinstance(v, pd.Timestamp): r.append(v.strftime(fmt))
            else: r.append(str(v))
    return [str(c) for c in df.columns], rows

def load_solve(path, text):
    ns = {"__name__": "solution", "__file__": path}
    try:
        tree = ast.parse(text, path)
        exec(compile(tree, path, "exec"), ns)
    except SyntaxError as e:
        raise SQLFail(f"SyntaxError: {e.msg}\n\n=> line {e.lineno} of {os.path.basename(path)}")
    except Exception as e:
        raise SQLFail(py_error(path, e))
    if not callable(ns.get("solve")):
        raise Fail("Define a function solve(...) that returns a DataFrame.")
    return ast.get_docstring(tree) or "", ns["solve"]

def execute_py(solve, path, inputs):
    """Tạo DataFrame cho từng bảng input, gọi solve(). Trả về dict kết quả như execute()."""
    import pandas as pd
    dfs = {name: to_frame(cols, types, rows) for name, cols, types, rows in inputs}
    params = list(inspect.signature(solve).parameters)
    unknown = [p for p in params if p not in dfs]
    if unknown:
        return {"error": f"solve() has parameters {unknown} that are not input tables. Input tables: {list(dfs)}."}
    signal.signal(signal.SIGALRM, _alarm); signal.alarm(TIMEOUT)
    try:
        out = solve(**{p: dfs[p] for p in params})
    except _Timeout:
        return {"error": f"solve() ran longer than {TIMEOUT}s. Look for a merge on the wrong key (row explosion) or a slow Python loop.", "tle": True}
    except Exception as e:
        return {"error": py_error(path, e)}
    finally:
        signal.alarm(0)
    if isinstance(out, pd.Series):
        return {"error": "solve() returned a Series. Return a DataFrame (e.g. s.to_frame() or s.reset_index())."}
    if not isinstance(out, pd.DataFrame):
        return {"error": f"solve() must return a DataFrame (got {type(out).__name__})."}
    if any(n is not None for n in out.index.names):
        return {"error": f"The result has a named index {list(out.index.names)}. Call .reset_index() so it becomes a column."}
    cols, rows = frame_rows(out)
    return {"dml": False, "cols": cols, "rows": rows}

def new_py(sql_path):
    """Tạo bản pandas <tên>.py cạnh file .sql: copy đề (trừ QUERY) vào docstring, thêm khung solve()."""
    py_path = sql_path[:-4] + ".py"
    if os.path.exists(py_path): return py_path
    text = open(sql_path, encoding="utf-8").read()
    spec = re.split(r"^--\s*QUERY\s*$", text, flags=re.M)[0].rstrip()
    names = [t[0] for t in parse_tables(split_sections(text, ["INPUT", "QUERY", "EXPECTED"]).get("INPUT", ""))]
    if not names or any(not n.isidentifier() for n in names):
        raise Fail(f"Cannot make a pandas version: input table names {names} are not usable as parameters.")
    if any(t[0] for t in parse_tables(split_sections(text, ["INPUT", "QUERY", "EXPECTED"]).get("EXPECTED", ""))):
        raise Fail("Cannot make a pandas version of an UPDATE/DELETE/INSERT problem.")
    args = ", ".join(f"{n}: pd.DataFrame" for n in names)
    with open(py_path, "w", encoding="utf-8") as f:
        f.write(f'r"""\n{spec}\n"""\nimport pandas as pd\n\n\ndef solve({args}) -> pd.DataFrame:\n    # write your pandas code here\n    ...\n')
    return py_path

def expected_error(block):
    """EXPECTED dạng `ERROR: <chuỗi>` -> chuỗi phải có trong thông báo lỗi; không phải dạng đó -> None."""
    m = re.match(r"\s*ERROR:\s*(.+)", block or "")
    return m.group(1).strip() if m else None

def error_matches(res, want):
    return "error" in res and want.lower() in res["error"].lower()

# ---------------------------------------------------------------- test nhìn thấy
def report_error_expected(res, want):
    if error_matches(res, want):
        print("Error raised:\n\n" + res["error"] + "\n" + paint("\n✔ Accepted (the expected error was raised)", "green")); return True
    if "error" in res:
        print(res["error"] + "\n" + paint(f"\n✘ Wrong Answer: an error was raised, but its message does not contain '{want}'", "red"))
    else:
        if res["dml"]:
            for n, (c, g) in res["tables"].items(): print(f"{n}\n{show(c, g)}\n")
        else:
            print("Output:\n" + show(res["cols"], res["rows"]))
        print(paint(f"\n✘ Wrong Answer: expected an error containing '{want}', but the statements succeeded", "red"))
    return False

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
def hidden_file(path):
    """hidden/**/<tên>.py hoặc .sql cùng tên: bản pandas dùng lại test ẩn của bản SQL."""
    stem, ext = os.path.splitext(os.path.basename(path))
    for e in dict.fromkeys([ext, ".sql"]):
        found = glob.glob(os.path.join(HERE, "hidden", "**", stem + e), recursive=True)
        if found: return found[0]

def run_hidden(run, path, verbose, order_any=False):
    """run(tên, inputs) -> dict kết quả như execute()."""
    hp = hidden_file(path)
    if not hp:
        print("\n(no hidden tests for this problem)"); return True
    parts = re.split(r"^--\s*CASE\s*(.*)$", open(hp, encoding="utf-8").read(), flags=re.M)
    cases = [(parts[i].strip(), parts[i + 1]) for i in range(1, len(parts), 2)]
    print(f"\nHidden tests ({len(cases)} cases):")
    results = []
    for k, (name, body) in enumerate(cases, 1):          # chạy hết các bộ trước, in sau
        sec = split_sections(body, ["INPUT", "EXPECTED", "CALL"])
        inputs, exp = parse_tables(sec.get("INPUT", "")), parse_tables(sec.get("EXPECTED", ""))
        res, want = run(f"hidden{k}", inputs, sec.get("CALL")), expected_error(sec.get("EXPECTED"))
        if want is not None:
            ok, why = error_matches(res, want), "Wrong Answer (expected an error)"
            detail = res.get("error") or f"The statements succeeded; expected an error containing '{want}'."
        elif "error" in res:
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
def judge(run, path, inputs, exp_tables, run_only, submit, verbose, order_any, locate=lambda m: m, want=None):
    res = run("visible", inputs)
    for n in res.get("notices", []): print(n)
    if res.get("notices"): print()
    if want is not None and not run_only:
        ok = report_error_expected(res, want)
    elif "error" in res: raise SQLFail(locate(res), res.get("tle", False))
    else: ok = report_visible(res, exp_tables, run_only, order_any)
    if submit and not run_only:
        if ok: ok = run_hidden(run, path, verbose, order_any)
        else: print("\nPass the visible test first, then run the hidden tests.")
    return ok

def run_file(path, run_only, submit=False, verbose=False):
    text = open(path, encoding="utf-8").read()
    if path.endswith(".py"):
        spec, solve = load_solve(path, text)
        order_any = bool(re.search(r"^--\s*@order:\s*any\b", spec, flags=re.M))
        sec = split_sections(spec, ["INPUT", "QUERY", "EXPECTED"])
        inputs = parse_tables(sec.get("INPUT", ""))
        exp_tables = [] if run_only else parse_tables(sec.get("EXPECTED", ""))
        return judge(lambda _, inp, call=None: execute_py(solve, path, inp), path, inputs, exp_tables, run_only, submit, verbose, order_any,
                     lambda res: res["error"])
    order_any = bool(re.search(r"^--\s*@order:\s*any\b", text, flags=re.M))
    sec = split_sections(text, ["INPUT", "QUERY", "EXPECTED", "CALL"])
    query, call = sec.get("QUERY", ""), sec.get("CALL", "")
    want = None if run_only else expected_error(sec.get("EXPECTED"))
    if not re.sub(r"--.*", "", query).strip():
        raise Fail("No statement in the -- QUERY section yet. Write your query and run again.")
    for rx in re.findall(r"^--\s*@forbid:\s*(.+?)\s*$", text, flags=re.M):     # từ khóa bị cấm trong đề này
        if re.search(rx, re.sub(r"--.*", "", query), flags=re.I):
            raise Fail(f"This problem forbids the pattern /{rx}/ (see the header of the problem file).")
    inputs = parse_tables(sec.get("INPUT", ""))
    exp_tables = [] if run_only or want is not None else parse_tables(sec.get("EXPECTED", ""))

    lines = text.splitlines()                      # dòng đầu của query nằm ở dòng nào của file
    h = next(i for i, l in enumerate(lines) if re.match(r"^--\s*QUERY\s*$", l))
    j = h + 1
    while j < len(lines) and not lines[j].strip(): j += 1
    qstart = j + 1                                 # số dòng (tính từ 1) của dòng đầu tiên trong query

    tmp = tempfile.mkdtemp()
    srv = pgserver.get_server(tmp, cleanup_mode="delete")
    try:
        conn = psycopg2.connect(srv.get_uri())
        def locate(res):
            msg, name = res["error"], os.path.basename(path)
            m = re.search(r"PL/pgSQL function (\w+)\(.*?\) line (\d+)", msg)     # lỗi trong thân hàm: đếm từ dòng có $$
            d = m and re.search(rf"CREATE\s+(?:OR\s+REPLACE\s+)?(?:FUNCTION|PROCEDURE)\s+(?:\w+\.)?{m.group(1)}\s*\(.*?(\$\w*\$)",
                                query, flags=re.I | re.S)
            if d: return msg + f"\n\n=> line {qstart + query[:d.start(1)].count(chr(10)) + int(m.group(2)) - 1} of {name}"
            if res.get("phase") == "call": return msg + "\n\n=> raised while running the problem's -- CALL section (after your QUERY)"
            m = re.search(r"LINE (\d+):", msg)
            return msg + (f"\n\n=> line {qstart + int(m.group(1)) - 1} of {name}" if m else "")
        return judge(lambda schema, inp, c=None: execute(conn, schema, inp, query, call if c is None else c), path, inputs,
                     exp_tables, run_only, submit, verbose, order_any, locate, want)
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
    if "--new-py" in flags:
        try: print(new_py(files[0]))
        except Fail as e: sys.exit(str(e))
        sys.exit(0)
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
