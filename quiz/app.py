"""Quiz trắc nghiệm phỏng vấn SQL.

Chạy:  q quiz      (hoặc: uv run --with streamlit --with pyyaml streamlit run quiz/app.py)
Câu hỏi nằm trong quiz/questions.yaml (định dạng ghi ở đầu file đó).
Lịch sử làm bài lưu ở quiz/history.json (chỉ trên máy này, không commit).
"""
import json, random, time
from collections import defaultdict
from pathlib import Path

import streamlit as st
import yaml

HERE = Path(__file__).parent
QUESTIONS = HERE / "questions.yaml"
HISTORY = HERE / "history.json"
LEVELS = ["Easy", "Medium", "Hard"]

st.set_page_config(page_title="SQL Interview Quiz", page_icon="🧠", layout="centered")

# ---------------------------------------------------------------- dữ liệu
@st.cache_data
def load_questions(mtime):
    """mtime chỉ để cache tự làm mới khi sửa file câu hỏi."""
    qs = yaml.safe_load(QUESTIONS.read_text(encoding="utf-8"))
    errors, seen = [], set()
    for q in qs:
        q["answer"] = sorted(q["answer"] if isinstance(q["answer"], list) else [q["answer"]])
        if q["id"] in seen: errors.append(f"id trùng: {q['id']}")
        seen.add(q["id"])
        if any(not 0 <= a < len(q["options"]) for a in q["answer"]): errors.append(f"{q['id']}: answer ngoài phạm vi options")
        if q.get("level") not in LEVELS: errors.append(f"{q['id']}: level phải là một trong {LEVELS}")
    return qs, errors

def load_history():
    try: return json.loads(HISTORY.read_text(encoding="utf-8"))
    except (OSError, ValueError): return {}

def save_history(h):
    try: HISTORY.write_text(json.dumps(h, ensure_ascii=False, indent=1), encoding="utf-8")
    except OSError: pass

def record(qid, ok):
    h = st.session_state.history
    e = h.setdefault(qid, {"right": 0, "wrong": 0})
    e["right" if ok else "wrong"] += 1
    e["last_ok"], e["last"] = ok, time.strftime("%Y-%m-%d %H:%M")
    save_history(h)

questions, errors = load_questions(QUESTIONS.stat().st_mtime)
by_id = {q["id"]: q for q in questions}
ss = st.session_state
ss.setdefault("history", load_history())
ss.setdefault("deck", [])            # danh sách id của lượt làm hiện tại
ss.setdefault("perm", {})            # id -> thứ tự hiển thị các lựa chọn
ss.setdefault("answers", {})         # id -> danh sách chỉ số (gốc) đã chọn
ss.setdefault("checked", set())      # id đã bấm "Kiểm tra" (chế độ luyện tập)
ss.setdefault("pos", 0)
ss.setdefault("finished", False)
ss.setdefault("deck_no", 0)

if errors:
    st.error("Lỗi trong questions.yaml:\n\n" + "\n".join(f"- {e}" for e in errors)); st.stop()

# ---------------------------------------------------------------- sidebar
topics = sorted({q["topic"] for q in questions})
with st.sidebar:
    st.header("Thiết lập")
    sel_topics = st.multiselect("Chủ đề", topics, default=topics)
    sel_levels = st.multiselect("Mức độ", LEVELS, default=LEVELS)
    source = st.radio("Nguồn câu hỏi", ["Tất cả", "Chưa làm", "Đã từng sai"], horizontal=True)
    mode = st.radio("Chế độ", ["Luyện tập", "Thi thử"], horizontal=True,
                    help="Luyện tập: xem đáp án ngay sau mỗi câu. Thi thử: chấm điểm khi nộp bài.")
    hist = ss.history
    pool = [q for q in questions if q["topic"] in sel_topics and q["level"] in sel_levels
            and (source == "Tất cả" or (source == "Chưa làm" and q["id"] not in hist)
                 or (source == "Đã từng sai" and hist.get(q["id"], {}).get("wrong", 0) > 0))]
    n = st.slider("Số câu", 1, max(1, len(pool)), min(10, max(1, len(pool))), disabled=not pool)
    st.caption(f"{len(pool)} câu phù hợp")
    if st.button("Bắt đầu lượt mới", type="primary", disabled=not pool, width="stretch"):
        deck = random.sample(pool, n)
        ss.deck = [q["id"] for q in deck]
        ss.perm = {q["id"]: random.sample(range(len(q["options"])), len(q["options"])) for q in deck}
        ss.answers, ss.checked, ss.pos, ss.finished, ss.mode = {}, set(), 0, False, mode
        ss.deck_no += 1
        st.rerun()

    st.divider()
    done = [hist[q["id"]] for q in questions if q["id"] in hist]
    right = sum(e["right"] for e in done); total = right + sum(e["wrong"] for e in done)
    st.metric("Đã làm", f"{len(done)}/{len(questions)} câu", f"{right / total:.0%} đúng" if total else None, delta_color="off")
    if hist and st.button("Xóa lịch sử", width="stretch"):
        ss.history = {}; save_history({}); st.rerun()

# ---------------------------------------------------------------- một câu hỏi
def is_correct(q, chosen):
    return sorted(chosen) == q["answer"]

def show_feedback(q, chosen):
    if is_correct(q, chosen): st.success("Chính xác!")
    else:
        right = "\n".join(f"- {q['options'][i]}" for i in q["answer"])
        st.error(f"Chưa đúng. Đáp án đúng:\n\n{right}")
    st.markdown(q["explain"])
    if q.get("ref"): st.caption(f"Đọc thêm: `{q['ref']}`")

def ask(q, locked):
    """Vẽ câu hỏi và các lựa chọn; trả về danh sách chỉ số gốc đã chọn."""
    st.markdown(f"**{q['topic']}** · {q['level']}")
    st.markdown(f"#### {q['question']}")
    if q.get("code"): st.code(q["code"].rstrip(), language="sql")
    order, prev = ss.perm[q["id"]], ss.answers.get(q["id"], [])
    key = f"{ss.deck_no}-{q['id']}"
    if len(q["answer"]) > 1:
        st.caption("Chọn **tất cả** đáp án đúng")
        chosen = [i for i in order
                  if st.checkbox(q["options"][i], value=i in prev, key=f"{key}-{i}", disabled=locked)]
    else:
        pick = st.radio("Chọn một đáp án", order, format_func=lambda i: q["options"][i],
                        index=order.index(prev[0]) if prev else None, key=key, disabled=locked,
                        label_visibility="collapsed")
        chosen = [] if pick is None else [pick]
    if not locked: ss.answers[q["id"]] = chosen
    return chosen

# ---------------------------------------------------------------- màn hình
st.title("🧠 SQL Interview Quiz")

if not ss.deck:
    st.markdown(f"""
Bộ câu hỏi trắc nghiệm luyện phỏng vấn SQL: **{len(questions)} câu**, {len(topics)} chủ đề.
Chọn chủ đề, mức độ và chế độ ở thanh bên trái rồi bấm **Bắt đầu lượt mới**.

- **Luyện tập**: trả lời xong bấm *Kiểm tra* để xem đáp án và giải thích ngay.
- **Thi thử**: làm hết rồi *Nộp bài*, xem điểm theo từng chủ đề và các câu sai.
- Nguồn **Đã từng sai**: chỉ ôn lại các câu bạn từng trả lời sai.
""")
    counts = defaultdict(lambda: defaultdict(int))
    for q in questions: counts[q["topic"]][q["level"]] += 1
    st.dataframe([{"Chủ đề": t, **{l: counts[t][l] for l in LEVELS}} for t in topics],
                 hide_index=True, width="stretch")
    st.stop()

deck = [by_id[i] for i in ss.deck if i in by_id]
practice = ss.get("mode", mode) == "Luyện tập"

if ss.finished:
    results = [(q, ss.answers.get(q["id"], [])) for q in deck]
    score = sum(is_correct(q, a) for q, a in results)
    st.subheader(f"Kết quả: {score}/{len(deck)} ({score / len(deck):.0%})")
    st.progress(score / len(deck))
    per = defaultdict(lambda: [0, 0])
    for q, a in results:
        per[q["topic"]][0] += is_correct(q, a); per[q["topic"]][1] += 1
    st.dataframe([{"Chủ đề": t, "Đúng": r, "Tổng": n_, "Tỷ lệ": f"{r / n_:.0%}"} for t, (r, n_) in sorted(per.items())],
                 hide_index=True, width="stretch")
    wrong = [(q, a) for q, a in results if not is_correct(q, a)]
    if wrong:
        st.markdown("### Các câu cần xem lại")
        for q, a in wrong:
            with st.expander(q["question"].strip().splitlines()[0]):
                if q.get("code"): st.code(q["code"].rstrip(), language="sql")
                st.markdown("**Bạn chọn:** " + (", ".join(q["options"][i] for i in a) if a else "_(bỏ trống)_"))
                show_feedback(q, a)
        if st.button("Làm lại các câu sai", type="primary"):
            ss.deck = [q["id"] for q, _ in wrong]
            ss.answers, ss.checked, ss.pos, ss.finished = {}, set(), 0, False
            ss.deck_no += 1
            st.rerun()
    else:
        st.balloons(); st.success("Đúng hết! Thử thêm câu Hard hoặc chủ đề khác.")
    st.stop()

q = deck[ss.pos]
st.progress((ss.pos + 1) / len(deck), text=f"Câu {ss.pos + 1}/{len(deck)} · {'Luyện tập' if practice else 'Thi thử'}")
locked = practice and q["id"] in ss.checked
chosen = ask(q, locked)
last = ss.pos == len(deck) - 1

def go(delta):
    ss.pos += delta

def finish():
    if not practice:                                   # thi thử: chấm và ghi lịch sử khi nộp
        for d in deck: record(d["id"], is_correct(d, ss.answers.get(d["id"], [])))
    ss.finished = True

if practice:
    if not locked:
        if st.button("Kiểm tra", type="primary", disabled=not chosen):
            ss.checked.add(q["id"]); record(q["id"], is_correct(q, chosen)); st.rerun()
    else:
        show_feedback(q, chosen)
        st.button("Xem kết quả" if last else "Câu tiếp theo →", type="primary", on_click=finish if last else go, args=() if last else (1,))
else:
    c1, c2, c3 = st.columns(3)
    c1.button("← Câu trước", disabled=ss.pos == 0, on_click=go, args=(-1,), width="stretch")
    c2.button("Câu tiếp theo →", disabled=last, on_click=go, args=(1,), width="stretch")
    blank = sum(1 for d in deck if not ss.answers.get(d["id"]))
    c3.button("Nộp bài" + (f" ({blank} câu trống)" if blank else ""), type="primary", on_click=finish, width="stretch")
