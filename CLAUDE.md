# CLAUDE.md

Guidance for working in this repository: GNU make for OpenVMS (IA64 and x86-64), built
with **make's own upstream VMS port** (`makefile.com`, `src/config.h-vms`, `src/vms*.c` in
the release tarball), wrapped by the same tooling as `~/projects/vms-awk`. Read README.md
first.

## How this differs from vms-grep / vms-sed

- **No host-side configure.** `makefile.com` compiles a fixed source list with
  `src/config.h-vms` copied to `config.h`. `tools/prepare.sh` only fetches, verifies,
  patches and overlays, and checks that `makefile.com` lists every source in `Makefile.am`
  (except `src/loadapi.c`: the load directive is not supported on VMS).
- **Our VMS files live in `overlay/vmsport/`.** Fix upstream's VMS files with patches
  (`#ifdef VMS`, or `config.h-vms`): they are candidates for make's VMS port.
- **`makefile.com` stops at the first error.** `tools/build.sh <node> ALL KEEP_GOING`
  compiles every source with its qualifiers and lists all failures, without linking.
- **The VMS port lagged make 4.4** (patches 0001-0005); new releases may need more. Check
  `config.h-vms` against `src/config.h.in` for new `HAVE_*` that change declarations.
- **Known limitation:** with `DEFINE/USER SYS$OUTPUT` the LIB$SPAWNed recipes fail with
  `%DCL-W-UNDFIL`; PIPE, SPAWN/OUTPUT, terminal and batch work. Tests capture with PIPE.
- **Writing test makefiles in DCL:** recipe `$` must be `$$`; make's `@` prefix in front of
  a DCL command misfires; a `CREATE` data line beginning with `$` ends the data.

## Ground rules

- **Never edit `staging/`, `cache/` or `out/`.** They are regenerated. Every VMS change is
  either a patch (`patches/NNNN-*.patch`, listed in `patches/series`) or a new file in
  `overlay/`. `tools/prepare.sh` refuses overlay files that would replace upstream files.
- **Change an upstream file with a patch.** Make a pristine copy under `a/` and an edited
  copy under `b/`, run `diff -u a/<path> b/<path>`, and put a `Subject:` line and a short
  explanation above the diff. Guard VMS-only code with `#ifdef VMS` (make's own macro) so
  the patch could go upstream. Patches to the same file stack, so diff against the tree as it stands after the
  earlier patches.
- **Test failures:** before blaming make, rerun the case by hand on the node: most smoke
  failures so far were DCL quoting in the test itself (see above).
- **Committed files must not contain real node details.** Use `<ia64-host>`, `<x86-host>`
  and `DISK$USER:[USERNAME.VMS_GREP]`. The real values live only in the git-ignored
  `tools/nodes.conf`.
- Keep `docs/TESTING.md` and the README status table in step with test results.

## Commands

```sh
tools/prepare.sh                        # always first after changing patches/overlay
tools/build.sh <ia64|x86> [ALL|CLEAN] [KEEP_GOING]
tools/test.sh <node>                    # DCL smoke test
tools/vms.sh <node> dcl '<cmd>' ...     # run DCL; also run/batch/put/get
tools/kit.sh <node>                     # PCSI kit -> out/kits/ (producer ISSINOHO)
tools/installcheck.sh <node>            # install kit, smoke-test it, remove (changes system; ask first)
```

A build takes a few minutes. makefile.com recompiles everything every time, so there is
no stale-object problem.

## VMS and tooling pitfalls (learned the hard way)

- **Use `tools/vms.sh`, never raw `ssh host cmd`.** Raw ssh output is often lost, and
  sessions sometimes never close. vms.sh logs to a file and waits for a completion marker.
- **Never use `WAIT` in DCL run over ssh**; it hangs (batch jobs are fine).
- **Never edit a bash script that is running.** bash reads scripts incrementally. Replace
  long-running tools atomically (write a copy, then `mv`).
- **Don't use `pkill -f` / `pgrep -f`** with a pattern that also matches your own shell's
  command line. Kill by explicit PID. On VMS, stop only processes this session started
  (they are network/batch processes of the work account); leave interactive sessions alone.
- **DCL details:**
  - `F$SEARCH` with a wildcard needs a stream id when other `F$SEARCH` calls happen in the
    same loop.
  - Batch jobs default to `/LIST` and `/MAP`.
  - DCL command lines are limited to about 4096 bytes (hence the wildcard librarian step).
  - `CALL` arguments are upper-cased unless quoted.
  - `SYS$LOGIN:[.X]` is not valid on these nodes.
- **`sftp put -r` into an existing directory nests a copy**; push.sh uploads file by file.
- **Run `tools/prepare.sh` after every change to `patches/` or `overlay/`.** build.sh and
  kit.sh push whatever is in `staging/`; forgetting this once shipped a stale kit.
- **stdout on VMS is often record-oriented** (terminal, `/OUTPUT` log, mailbox). The CRTL
  turns each `fwrite` item into a record (patch 0004 writes with `putc`), and a host-side
  `grep` treats output containing a NUL as binary (use `grep -a`).
- **CRTL quirks** that matter (shared with grep) are documented in
  vms-grep's `docs/vms-environment.md`:
  - no `#include_next`; text-library includes instead;
  - `open()` of a directory fails;
  - `setlocale("")` ignores environment variables;
  - UTF-8 decoding bugs;
  - `mempcpy` is a macro;
  - argument case under traditional parse style.

## Commits

Commit in logical steps with messages that explain the VMS reason for each change. Don't
push without the user asking. The GitHub remote is `origin`
(github.com/issinoho/vms-make), branch `main`.
