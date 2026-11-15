# Testing

| Layer | Runs on | Command (host) |
|---|---|---|
| DCL smoke test (8 checks) | IA64, x86-64, Alpha | `tools/test.sh <node>` |
| GNU make's own test suite (`tests/run_make_tests.pl`) | needs Perl and a POSIX shell: not run | |

`tools/test.sh` runs `[.VMSPORT]TEST_SMOKE.COM` against the freshly built `MAKE.EXE`
(a batch job on the Alpha) and saves the output to `out/smoke-<node>.log`. The checks:
version banner; a DCL recipe makes a target and a second run finds it up to date; `-n`;
functions and a command-line variable in a recipe; a pattern rule with `$<` and `$@`; the
error statuses for a failing recipe and a missing makefile.

## Current results (make 4.4.1)

| Suite | IA64 | x86-64 | Alpha |
|---|---|---|---|
| DCL smoke test | 8/8 | 8/8 | 8/8 |
| Kit install, smoke test of the installed image, remove | clean | clean | not run (vms2 kit only built; installing changes the system) |

## Alpha (V8.4-2L2, VSI C V7.4-002)

- **Build:** upstream's `makefile.com` compiles the 35 sources and links in about 2.5 minutes.
  VSI C reports warnings only (`UNDEFENUM` for `variable_origin`, one `PTRMISMATCH` on `lstat`,
  `MISSINGRETURN` in `exec_command` and `unload_file`), and the linker repeats them as
  `%LINK-W-WRNERS`; the image links and runs.
- **Float:** patch 0006 compiles with `/FLOAT=IEEE_FLOAT/IEEE_MODE=DENORM_RESULTS` on Alpha
  only. make's floating point is limited to `-l` (load limit, unsupported on VMS) and
  `atof`. By hand, `make -l 2.5 -f x` parses the limit and runs the recipe.
- **Not run:** GNU make's upstream suite needs Perl and a POSIX shell. The Alpha has neither
  (no Perl, no GNV), so only the DCL smoke test was run there. `-j` is unsupported on VMS
  (make says so and resets to `-j1`).
