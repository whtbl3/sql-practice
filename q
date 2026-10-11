#!/usr/bin/env bash
# q                      list every group and problem
# q <group>              list one group (a unique prefix is enough: q to, q is, q dm)
# q <group> <n>          watch the file, print the output on every save   (main workflow)
# q <group> <n> c        run once and compare with EXPECTED (visible test)
# q <group> <n> h        submit: visible test + hidden tests (case names and pass/fail only)
# q <group> <n> hv       like h; if everything passes, show every hidden case in detail
# q <group> <n> s        show the reference solution and its result (including hidden tests)
# q verify               run every reference solution against every test (health check)
cd "$(dirname "$(readlink -f "$0")")" || exit 1

list() {  # $1 = group name or empty
python3 - "$1" <<'PY'
import glob, os, re, sys
want = sys.argv[1]
for g in sorted(os.listdir("problems")):
    if want and g != want: continue
    files = sorted(glob.glob(f"problems/{g}/*.sql"))
    print(f"\n{g}  ({len(files)})")
    for f in files:
        head = open(f, encoding="utf-8").read().split("-- INPUT")[0]
        m = re.search(r"^-- Problem [^:]+: (.*?)\s+\[(\w+)\]", head, re.M)
        pat = re.search(r"^-- Pattern: (.*)$", head, re.M)
        n = os.path.basename(f).split("_")[0]
        print(f"  {n}  {m.group(2):<7} {m.group(1):<48} {pat.group(1) if pat else ''}")
PY
}

resolve_group() {  # exact name or unique prefix
  local cands=() d
  for d in problems/*/; do d=$(basename "$d"); [ "$d" = "$1" ] && { echo "$d"; return; }; [[ "$d" == "$1"* ]] && cands+=("$d"); done
  if [ ${#cands[@]} -eq 1 ]; then echo "${cands[0]}"
  else echo "Unknown or ambiguous group '$1'. Groups: $(ls problems | tr '\n' ' ')" >&2; return 1; fi
}

[ -z "$1" ] && { list ""; exit; }

if [ "$1" = verify ]; then
  fail=0
  for f in solutions/*/*.sql; do
    out=$(uv run check.py "$f" --submit 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    if echo "$out" | grep -q "Accepted" && ! echo "$out" | grep -q "✘"; then printf "  ok    %s  %s\n" "$f" "$(echo "$out" | grep -o 'Hidden tests: [0-9/]* passed')"
    else printf "  FAIL  %s\n" "$f"; fail=1; fi
  done
  [ $fail -eq 0 ] && echo "All reference solutions pass." || echo "Some reference solutions FAIL."; exit $fail
fi

g=$(resolve_group "$1") || exit 1
[ -z "$2" ] && { list "$g"; exit; }
case "$2" in ''|*[!0-9]*) echo "Usage: q <group> <number> [c|h|hv|s]" >&2; exit 1;; esac

n=$(printf "%02d" "$((10#$2))"); mode="${3:-w}"
dir=problems; [ "$mode" = s ] && dir=solutions
f=$(ls "$dir/$g/${n}"_*.sql 2>/dev/null | head -1)
[ -n "$f" ] || { echo "No problem $g $n"; exit 1; }

case "$mode" in
  w)  exec uv run check.py "$f" -w -r ;;
  c)  uv run check.py "$f" ;;
  h)  uv run check.py "$f" --submit ;;
  hv) uv run check.py "$f" --submit -v ;;
  s)  echo "--- Reference solution ---"; sed -n '/^-- QUERY/,$p' "$f" | sed '1d'
      echo "--- Result ---"; uv run check.py "$f" --submit ;;
  *)  echo "Invalid mode: $mode (w, c, h, hv, s)"; exit 1 ;;
esac
