$! TEST_SMOKE.COM - smoke test for the built GNU make (MAKE.EXE at the top)
$!
$! Usage:  @[.VMSPORT]TEST_SMOKE
$! Runs make from DCL on small makefiles whose recipes are DCL commands
$! (a "$" in a recipe is written "$$").  make's output is captured with PIPE:
$! with SYS$OUTPUT redirected by DEFINE/USER the subprocesses that run the
$! recipes cannot write to it (%DCL-W-UNDFIL).
$!
$ set noon
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ make = "$" + f$parse("MAKE.EXE")
$ pass = 0
$ fail = 0
$ if f$search("SMOKE.DIR") .eqs. "" then create/directory [.SMOKE]
$ set default [.SMOKE]
$ set process/parse_style=extended
$!
$! 1. version
$ pipe make --version > out.log
$ search/nooutput out.log "GNU Make 4"
$ sev = $severity
$ name = "version"
$ gosub check_success_log
$!
$! 2. a target is made from its prerequisite by a DCL recipe
$ create in.txt
hello from make
$ create build.mk
all : out.txt
	write sys$$output "built"

out.txt : in.txt
	copy in.txt out.txt
$ pipe make -f build.mk > out.log
$ sev = $severity
$ if f$search("out.txt") .eqs. "" .and. sev .eq. 1 then sev = 2
$ if sev .eq. 1
$ then
$   search/nooutput out.txt "hello from make"
$   sev = $severity
$ endif
$ name = "recipe makes out.txt from in.txt"
$ gosub check_success_log
$!
$! 3. a second run finds out.txt up to date (no copy)
$ pipe make -f build.mk > out.log
$ sev = $severity
$ if sev .eq. 1
$ then
$   define/user sys$output nla0:
$   search/nooutput out.log "copy in.txt"
$   if $severity .eq. 1 then sev = 2
$ endif
$ name = "second run: out.txt is up to date"
$ gosub check_success_log
$!
$! 4. -n prints the recipe but does not run it
$ delete/nolog out.txt;*
$ pipe make -n -f build.mk > out.log
$ sev = $severity
$ if sev .eq. 1
$ then
$   search/nooutput out.log "copy in.txt out.txt"
$   sev = $severity
$   if f$search("out.txt") .nes. "" then sev = 2
$ endif
$ name = "-n prints the recipe without running it"
$ gosub check_success_log
$!
$! 5. variables and functions; a variable from the command line reaches the
$!    DCL recipe with its case kept
$! (a data line of CREATE may not start with "$", so $(info) is assigned)
$ create func.mk
WORDS := alpha beta gamma
SHOWN := $(info count=$(words $(WORDS)) last=$(lastword $(WORDS)) up=$(subst a,A,$(WORDS)))
show :
	write sys$$output "msg=$(MSG)"
$ pipe make -f func.mk "MSG=Hello" > out.log
$ sev = $severity
$ if sev .eq. 1
$ then
$   search/nooutput/exact out.log "count=3 last=gamma up=AlphA betA gAmmA"
$   sev = $severity
$ endif
$ if sev .eq. 1
$ then
$   search/nooutput/exact out.log "msg=Hello"
$   sev = $severity
$ endif
$ name = "functions, and a command-line variable in a recipe"
$ gosub check_success_log
$!
$! 6. pattern rules and automatic variables
$ create a.src
aaa
$ create b.src
bbb
$ create pat.mk
all : a.dst b.dst

%.dst : %.src
	copy $< $@
$ pipe make -f pat.mk > out.log
$ sev = $severity
$ if sev .eq. 1 .and. (f$search("a.dst") .eqs. "" .or. f$search("b.dst") .eqs. "") then sev = 2
$ name = "pattern rule with $< and $@"
$ gosub check_success_log
$!
$! 7. a failing recipe stops make with an error status
$ create fail.mk
fail :
	exit 44
$ define/user sys$error nla0:
$ pipe make -f fail.mk > out.log
$ sev = $severity
$ name = "failing recipe gives an error status"
$ gosub check_failure
$!
$! 8. a missing makefile gives an error status
$ define/user sys$error nla0:
$ pipe make -f nonexistent.mk > out.log
$ sev = $severity
$ name = "missing makefile gives an error status"
$ gosub check_failure
$!
$ write sys$output "SMOKE: ''pass' passed, ''fail' failed"
$ delete/nolog *.*;*
$ set default [-]
$ set file/protection=o:rwed SMOKE.DIR
$ delete/nolog SMOKE.DIR;
$ set default 'saved_default'
$ if fail .eq. 0 then exit 1
$ exit 44
$!
$check_success_log:
$ if sev .eq. 1
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ")"
$   if f$search("out.log") .nes. ""
$   then
$     write sys$output "   output was:"
$     type out.log;0
$   endif
$ endif
$ return
$!
$check_failure:
$ if sev .eq. 2 .or. sev .eq. 4
$ then
$   pass = pass + 1
$   write sys$output "PASS: ", name
$ else
$   fail = fail + 1
$   write sys$output "FAIL: ", name, " (severity ", sev, ", expected an error)"
$ endif
$ return
