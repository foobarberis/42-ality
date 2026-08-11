#!/bin/sh
set -u

bin=$1
tmp=_build/e2e.$$
pid=

cleanup() {
  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
  fi
  rm -rf "$tmp"
}

fail() {
  echo "[e2e] FAIL: $1" >&2
  exit 1
}

check_failure() {
  name=$1
  expected=$2
  shift 2
  if "$bin" "$@" </dev/null >"$tmp/output" 2>&1; then
    fail "$name exited successfully"
  fi
  if ! grep -q "$expected" "$tmp/output"; then
    fail "$name did not report $expected"
  fi
  echo "[e2e] OK: $name"
}

trap cleanup EXIT HUP INT TERM
mkdir -p "$tmp/directory"
cat >"$tmp/malformed.gmr" <<'GRAMMAR'
this is not a grammar
GRAMMAR
cat >"$tmp/invalid.gmr" <<'GRAMMAR'
#input
a;A
#combos
B;Invalid Move
GRAMMAR
cat >"$tmp/unreadable.gmr" <<'GRAMMAR'
#input
a;A
#combos
A;Move
GRAMMAR
chmod 000 "$tmp/unreadable.gmr"

check_failure "no arguments" "usage: ft_ality"
check_failure "extra arguments" "usage: ft_ality" res/subject.gmr extra
check_failure "missing file" "Error: cannot read grammar file" "$tmp/missing.gmr"
check_failure "directory path" "Error: cannot read grammar file" "$tmp/directory"
if [ ! -r "$tmp/unreadable.gmr" ]; then
  check_failure "unreadable file" "Error: cannot read grammar file" \
    "$tmp/unreadable.gmr"
else
  echo "[e2e] SKIP: unreadable file (current user bypasses file permissions)"
fi
chmod 600 "$tmp/unreadable.gmr"
check_failure "malformed grammar" "Error:" "$tmp/malformed.gmr"
check_failure "semantically invalid grammar" "Error:" "$tmp/invalid.gmr"
check_failure "valid grammar without a terminal" "interactive terminal required" \
  res/common_prefix.gmr

if ! command -v script >/dev/null 2>&1; then
  fail "script is required to send terminal input"
fi

if ! printf 'qw\004' | script -qec "$bin res/common_prefix.gmr" /dev/null \
  >"$tmp/common-prefix.out" 2>&1; then
  fail "common-prefix grammar did not accept terminal input"
fi
if ! grep -q "Move B !!" "$tmp/common-prefix.out"; then
  fail "common-prefix continuation did not recognize the longer move"
fi
if grep -q "Move A !!" "$tmp/common-prefix.out"; then
  fail "common-prefix continuation printed the shorter move"
fi
echo "[e2e] OK: common-prefix continuation selects only the longer move"

if ! { printf q; sleep 0.5; printf '\004'; } | \
  script -qec "$bin res/common_prefix.gmr" /dev/null \
  >"$tmp/common-prefix-timeout.out" 2>&1; then
  fail "common-prefix grammar did not accept delayed terminal input"
fi
if ! grep -q "Move A !!" "$tmp/common-prefix-timeout.out"; then
  fail "common-prefix timeout did not commit the shorter move"
fi
echo "[e2e] OK: common-prefix timeout commits the shorter move"

normal_command="before=\$(stty -g); $bin res/common_prefix.gmr; status=\$?; after=\$(stty -g); [ \"\$before\" = \"\$after\" ] && exit \$status; exit 1"
if ! printf '\004' | script -qec "$normal_command" /dev/null \
  >"$tmp/restore-normal.out" 2>&1; then
  fail "terminal settings were not restored after normal quit"
fi
echo "[e2e] OK: terminal settings are restored after normal quit"

signal_command="before=\$(stty -g); $bin res/common_prefix.gmr < /dev/tty & child=\$!; sleep 0.2; kill -TERM \$child; wait \$child; status=\$?; after=\$(stty -g); [ \"\$before\" = \"\$after\" ] && [ \$status -eq 143 ]"
if ! script -qec "$signal_command" /dev/null >"$tmp/restore-signal.out" 2>&1; then
  fail "terminal settings were not restored after interruption"
fi
echo "[e2e] OK: terminal settings are restored after interruption"
