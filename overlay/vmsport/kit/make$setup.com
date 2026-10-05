$! MAKE$SETUP.COM - define the make and gmake commands for a user
$!
$! Add to LOGIN.COM (or SYS$MANAGER:SYLOGIN.COM for everyone):
$!     $ @MAKE$ROOT:[000000]MAKE$SETUP.COM
$!
$! Quote upper-case options and variable assignments ("CC=cc"), or
$! SET PROCESS/PARSE_STYLE=EXTENDED: traditional DCL parsing changes the
$! case of unquoted arguments.
$!
$ if f$trnlnm("MAKE$ROOT") .eqs. ""
$ then
$   write sys$error "MAKE$SETUP: MAKE$ROOT is not defined; run MAKE$STARTUP.COM first"
$   exit 44
$ endif
$ make  :== $MAKE$ROOT:[BIN]MAKE.EXE
$ gmake :== $MAKE$ROOT:[BIN]MAKE.EXE
$ exit 1
