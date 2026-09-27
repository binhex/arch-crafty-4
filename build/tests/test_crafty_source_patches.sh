#!/usr/bin/env bash
# Regression tests for the Crafty source patch step in build/root/install.sh.
#
# Covers binhex/arch-crafty-4#12 (Files tab HTTP 500 caused by a symlinked
# server directory) and the related backup exclusion mismatch.
# Upstream reference: https://gitlab.com/crafty-controller/crafty-4/-/issues/752
#
# Usage:
#   bash build/tests/test_crafty_source_patches.sh
#
# Environment overrides:
#   INSTALL_SH=/path/to/install.sh   test an alternate build script
#   CRAFTY_SRC=/path/to/crafty-4     patch a real checkout instead of fixtures
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
INSTALL_SH="${INSTALL_SH:-${REPO_ROOT}/build/root/install.sh}"
CRAFTY_SRC="${CRAFTY_SRC:-}"
TEST_TMP="$(mktemp -d)"
trap 'rm -rf "${TEST_TMP}"' EXIT

FILES_REL="app/classes/web/routes/api/servers/server/files.py"
HELPERS_REL="app/classes/helpers/file_helpers.py"

UNPATCHED_COMPARE="PurePath(raw_path), PurePath(server_path)"
PATCHED_COMPARE="PurePath(raw_path), PurePath(Path(server_path).resolve())"
UNPATCHED_BACKUP="path_to_zip: Path = Path(path_to_zip)"
PATCHED_BACKUP="path_to_zip: Path = Path(path_to_zip).resolve()"

FAILURES=0

pass() {
  echo "[PASS] $*"
}

fail() {
  echo "[FAIL] $*"
  FAILURES=$((FAILURES + 1))
}

count_occurrences() {
  local pattern="${1}"
  local file="${2}"
  local count
  count="$(grep -o -F "${pattern}" "${file}" | wc -l || true)"
  printf '%s' "${count}"
}

extract_patch_block() {
  local install_sh="${1}"
  awk '
    /^# crafty source patches$/ { in_block = 1 }
    in_block {
      print
      if ($0 ~ /^sed -i/ && $0 ~ /crafty_helpers_py_replace/) exit
    }
  ' "${install_sh}"
}

write_synthetic_fixture() {
  local fixture_root="${1}"
  mkdir -p "${fixture_root}/app/classes/web/routes/api/servers/server" "${fixture_root}/app/classes/helpers"
  cat > "${fixture_root}/${FILES_REL}" <<'EOF'
from pathlib import Path, PurePath


def relative_child(raw_path, server_path):
    return PurePath.relative_to(
        PurePath(raw_path), PurePath(server_path)
    )


def relative_child_again(raw_path, server_path):
    return PurePath.relative_to(
        PurePath(raw_path), PurePath(server_path)
    )
EOF
  cat > "${fixture_root}/${HELPERS_REL}" <<'EOF'
from pathlib import Path


def excluded_matches(path_to_zip, excluded_dirs):
    ex_replace = [
        Path(str(Path(path_to_zip, p))).resolve().as_posix()
        for p in excluded_dirs
    ]
    path_to_zip: Path = Path(path_to_zip)
    return [
        str(item)
        for item in path_to_zip.rglob("*")
        if any(item.is_relative_to(entry) for entry in ex_replace)
    ]
EOF
}

make_source_fixture() {
  local fixture_root="${1}"
  if [[ -n "${CRAFTY_SRC}" ]]; then
    if [[ ! -f "${CRAFTY_SRC}/${FILES_REL}" || ! -f "${CRAFTY_SRC}/${HELPERS_REL}" ]]; then
      fail "CRAFTY_SRC='${CRAFTY_SRC}' does not contain the expected Crafty source files"
      return 1
    fi
    mkdir -p "${fixture_root}/app/classes/web/routes/api/servers/server" "${fixture_root}/app/classes/helpers"
    cp "${CRAFTY_SRC}/${FILES_REL}" "${fixture_root}/${FILES_REL}"
    cp "${CRAFTY_SRC}/${HELPERS_REL}" "${fixture_root}/${HELPERS_REL}"
  else
    write_synthetic_fixture "${fixture_root}"
  fi
}

run_from_block() {
  local block_file="${1}"
  local target_root="${2}"
  local wrapper="${TEST_TMP}/run_patch.sh"
  {
    echo "set -e"
    printf 'install_path=%q\n' "${target_root}"
    cat "${block_file}"
  } > "${wrapper}"
  bash "${wrapper}"
}

echo "== symlink path semantics (root cause) =="
SERVER_ID="test-server"
REAL_ROOT="${TEST_TMP}/config/crafty/servers"
OPT_ROOT="${TEST_TMP}/opt/crafty/servers"
mkdir -p "${REAL_ROOT}/${SERVER_ID}/config" "${TEST_TMP}/opt/crafty"
printf 'motd=hi\n' > "${REAL_ROOT}/${SERVER_ID}/config/server.properties"
ln -s "${REAL_ROOT}" "${OPT_ROOT}"
STORED="${OPT_ROOT}/${SERVER_ID}"
RAW="$(realpath "${STORED}/config/server.properties")"
if [[ "${RAW}" == "${STORED}/"* ]]; then
  fail "symlink mismatch not reproduced: '${RAW}' unexpectedly under '${STORED}'"
else
  pass "bug reproduced: resolved child is not under the stored path"
fi
STORED_RESOLVED="$(realpath "${STORED}")"
if [[ "${RAW}" == "${STORED_RESOLVED}/"* ]]; then
  pass "fix semantics confirmed: canonical stored path matches the resolved child"
else
  fail "canonical stored path '${STORED_RESOLVED}' still does not match '${RAW}'"
fi

echo
echo "== install.sh syntax =="
if bash -n "${INSTALL_SH}"; then
  pass "bash -n ${INSTALL_SH}"
else
  fail "bash -n ${INSTALL_SH}"
fi

echo
echo "== patch block =="
BLOCK_FILE="${TEST_TMP}/patch_block.sh"
if [[ ! -f "${INSTALL_SH}" ]]; then
  fail "install script not found: ${INSTALL_SH}"
elif ! extract_patch_block "${INSTALL_SH}" > "${BLOCK_FILE}" || [[ ! -s "${BLOCK_FILE}" ]]; then
  fail "patch block not found in ${INSTALL_SH} (production fix missing)"
else
  pass "patch block found in ${INSTALL_SH}"

  # Refuse to execute anything that spilled past the patch step: an unbounded
  # extraction could otherwise run the rest of install.sh (pacman, chown, ...).
  if grep -qE 'python\.sh|pacman|chmod|chown|cleanup\.sh|refresh\.sh|init\.sh' "${BLOCK_FILE}"; then
    fail "extracted patch block contains unexpected build commands; refusing to run it"
    echo
    echo "${FAILURES} test(s) failed."
    exit 1
  fi
  pass "extracted patch block is bounded to the patch step"
  if tail -n 1 "${BLOCK_FILE}" | grep -qF 'crafty_helpers_py_replace'; then
    pass "patch block ends at the backup exclusion patch step"
  else
    fail "patch block does not end at the expected step"
  fi

  FIXTURE="${TEST_TMP}/fixture"
  if make_source_fixture "${FIXTURE}"; then
    pristine_files="$(count_occurrences "${UNPATCHED_COMPARE}" "${FIXTURE}/${FILES_REL}")"
    pristine_backup="$(count_occurrences "${UNPATCHED_BACKUP}" "${FIXTURE}/${HELPERS_REL}")"
    if [[ "${pristine_files}" -eq 2 ]]; then
      pass "fixture has 2 upstream Files API comparison sites"
    else
      fail "fixture has ${pristine_files} upstream comparison sites, expected 2"
    fi
    if [[ "${pristine_backup}" -eq 1 ]]; then
      pass "fixture has 1 upstream backup exclusion site"
    else
      fail "fixture has ${pristine_backup} upstream backup sites, expected 1"
    fi

    if run_from_block "${BLOCK_FILE}" "${FIXTURE}" > "${TEST_TMP}/patch.log" 2>&1; then
      patched_files="$(count_occurrences "${PATCHED_COMPARE}" "${FIXTURE}/${FILES_REL}")"
      patched_backup="$(count_occurrences "${PATCHED_BACKUP}" "${FIXTURE}/${HELPERS_REL}")"
      if [[ "${patched_files}" -eq 2 ]]; then
        pass "patch resolved server_path at both Files API comparison sites"
      else
        fail "patch produced ${patched_files} resolved comparison sites, expected 2"
      fi
      if [[ "${patched_backup}" -eq 1 ]]; then
        pass "patch resolved path_to_zip at the backup exclusion site"
      else
        fail "patch produced ${patched_backup} resolved backup sites, expected 1"
      fi
      if command -v python3 >/dev/null 2>&1; then
        if python3 -m py_compile "${FIXTURE}/${FILES_REL}" "${FIXTURE}/${HELPERS_REL}" 2>/dev/null; then
          pass "patched sources are valid Python"
        else
          fail "patched sources failed python3 -m py_compile"
        fi
      else
        echo "[SKIP] python3 unavailable, skipping syntax compilation"
      fi
    else
      fail "patch block failed against the fixture"
      cat "${TEST_TMP}/patch.log"
    fi

    echo
    echo "== guard (upstream drift) =="
    DRIFT="${TEST_TMP}/drift"
    mkdir -p "${DRIFT}/app/classes/web/routes/api/servers/server" "${DRIFT}/app/classes/helpers"
    printf 'from pathlib import Path, PurePath\n\n\ndef single(raw_path, server_path):\n    return PurePath.relative_to(\n        PurePath(raw_path), PurePath(server_path)\n    )\n' > "${DRIFT}/${FILES_REL}"
    printf 'from pathlib import Path\n\n\ndef keep(path_to_zip):\n    return path_to_zip\n' > "${DRIFT}/${HELPERS_REL}"
    if run_from_block "${BLOCK_FILE}" "${DRIFT}" > "${TEST_TMP}/drift.log" 2>&1; then
      fail "guard did not fail the build when Files API pattern was missing"
    elif grep -qF '[crit]' "${TEST_TMP}/drift.log"; then
      pass "guard failed the build loudly when Files API pattern was missing"
    else
      fail "guard failed without a [crit] message"
    fi

    if run_from_block "${BLOCK_FILE}" "${FIXTURE}" > "${TEST_TMP}/rerun.log" 2>&1; then
      fail "guard did not fail the build when source was already patched"
    elif grep -qF 'already contains the crafty server path patch' "${TEST_TMP}/rerun.log"; then
      pass "guard failed the build loudly when source was already patched"
    else
      fail "already-patched guard failed without the expected message"
    fi

    HELPERS_DRIFT="${TEST_TMP}/helpers_drift"
    write_synthetic_fixture "${HELPERS_DRIFT}"
    printf 'from pathlib import Path\n\n\ndef keep(path_to_zip):\n    return path_to_zip\n' > "${HELPERS_DRIFT}/${HELPERS_REL}"
    if run_from_block "${BLOCK_FILE}" "${HELPERS_DRIFT}" > "${TEST_TMP}/helpers_drift.log" 2>&1; then
      fail "guard did not fail the build when backup exclusion pattern was missing"
    elif grep -qF 'Expected 1 crafty backup exclude patch match' "${TEST_TMP}/helpers_drift.log"; then
      pass "guard failed the build loudly when backup exclusion pattern was missing"
    else
      fail "backup exclusion guard failed without the expected message"
    fi

    IMPORT_DRIFT="${TEST_TMP}/import_drift"
    mkdir -p "${IMPORT_DRIFT}/app/classes/web/routes/api/servers/server" "${IMPORT_DRIFT}/app/classes/helpers"
    printf 'from pathlib import PurePath\n\n\ndef a(raw_path, server_path):\n    return PurePath.relative_to(\n        PurePath(raw_path), PurePath(server_path)\n    )\n\n\ndef b(raw_path, server_path):\n    return PurePath.relative_to(\n        PurePath(raw_path), PurePath(server_path)\n    )\n' > "${IMPORT_DRIFT}/${FILES_REL}"
    printf 'from pathlib import Path\n\n\ndef keep(path_to_zip):\n    path_to_zip: Path = Path(path_to_zip)\n    return path_to_zip\n' > "${IMPORT_DRIFT}/${HELPERS_REL}"
    if run_from_block "${BLOCK_FILE}" "${IMPORT_DRIFT}" > "${TEST_TMP}/import_drift.log" 2>&1; then
      fail "guard did not fail the build when the Path import was missing"
    elif grep -qF 'Expected Path import' "${TEST_TMP}/import_drift.log"; then
      pass "guard failed the build loudly when the Path import was missing"
    else
      fail "import guard failed without the expected message"
    fi

    ALIAS_DRIFT="${TEST_TMP}/alias_drift"
    mkdir -p "${ALIAS_DRIFT}/app/classes/web/routes/api/servers/server" "${ALIAS_DRIFT}/app/classes/helpers"
    printf 'from pathlib import PurePath, Path as P\n\n\ndef a(raw_path, server_path):\n    return PurePath.relative_to(\n        PurePath(raw_path), PurePath(server_path)\n    )\n' > "${ALIAS_DRIFT}/${FILES_REL}"
    printf 'from pathlib import Path\n\n\ndef keep(path_to_zip):\n    path_to_zip: Path = Path(path_to_zip)\n    return path_to_zip\n' > "${ALIAS_DRIFT}/${HELPERS_REL}"
    if run_from_block "${BLOCK_FILE}" "${ALIAS_DRIFT}" > "${TEST_TMP}/alias_drift.log" 2>&1; then
      fail "guard did not fail the build when Path was imported under an alias"
    elif grep -qF 'Expected Path import' "${TEST_TMP}/alias_drift.log"; then
      pass "guard failed the build loudly when Path was imported under an alias"
    else
      fail "alias guard failed without the expected message"
    fi

    MISSING_FILE="${TEST_TMP}/missing_file"
    write_synthetic_fixture "${MISSING_FILE}"
    rm -f "${MISSING_FILE}/${FILES_REL}"
    if run_from_block "${BLOCK_FILE}" "${MISSING_FILE}" > "${TEST_TMP}/missing_file.log" 2>&1; then
      fail "guard did not fail the build when a target file was missing"
    elif grep -qF 'Expected file' "${TEST_TMP}/missing_file.log"; then
      pass "guard failed the build loudly when a target file was missing"
    else
      fail "file guard failed without the expected message"
    fi
  fi
fi

echo
if [[ "${FAILURES}" -eq 0 ]]; then
  echo "All tests passed."
  exit 0
fi
echo "${FAILURES} test(s) failed."
exit 1
