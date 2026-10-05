$! MAKE$STARTUP.COM - system startup for GNU make on OpenVMS
$!
$! Installed by PCSI into SYS$STARTUP.  Defines the system logical name
$! MAKE$ROOT, pointing at the installed [MAKE] directory.  To run it at every
$! boot, add this line to SYS$MANAGER:SYSTARTUP_VMS.COM:
$!
$!     $ @SYS$STARTUP:MAKE$STARTUP.COM
$!
$! P1 = "INSTALL": also print the post-installation tasks (PCSI runs it so).
$! P1 = "REMOVE":  deassign MAKE$ROOT instead (PCSI runs it so at removal).
$!
$! Users then define the make and gmake commands with
$!     $ @MAKE$ROOT:[000000]MAKE$SETUP.COM
$!
$ set noon
$ mode = f$edit(p1, "UPCASE")
$ if mode .eqs. "REMOVE"
$ then
$   if f$trnlnm("MAKE$ROOT", "LNM$SYSTEM_TABLE") .nes. "" then -
        deassign/system/executive_mode MAKE$ROOT
$   exit 1
$ endif
$!
$! This procedure sits in <destination>[SYS$STARTUP]; the product is in
$! <destination>[MAKE].  Rooted logicals need the physical form:
$! DKA0:[SYS0.SYSCOMMON.SYS$STARTUP] -> DKA0:[SYS0.SYSCOMMON.MAKE.]
$ proc = f$environment("PROCEDURE")
$ dev = f$parse(proc,,,"DEVICE","NO_CONCEAL")
$ dir = f$edit(f$parse(proc,,,"DIRECTORY","NO_CONCEAL"), "UPCASE") - "]["
$ root = dir - "SYS$STARTUP]" + "MAKE.]"
$ if root .eqs. dir + "MAKE.]"
$ then
$   write sys$error "MAKE$STARTUP: expected to be in a [SYS$STARTUP] directory, not ''dir'"
$   exit 44
$ endif
$ root = root - ".000000"
$ define/system/executive_mode/translation_attributes=concealed MAKE$ROOT 'dev''root'
$ if f$search("MAKE$ROOT:[BIN]MAKE.EXE") .eqs. ""
$ then
$   write sys$error "MAKE$STARTUP: MAKE.EXE not found under ''dev'''root'"
$   exit 44
$ endif
$ if mode .nes. "INSTALL" then exit 1
$ say = "write sys$output"
$ say ""
$ say "    Post-installation tasks for GNU make"
$ say ""
$ say "    At system startup: to define MAKE$ROOT at every boot, add this line to"
$ say "    SYS$MANAGER:SYSTARTUP_VMS.COM:"
$ say "    $ @SYS$STARTUP:MAKE$STARTUP.COM"
$ say "    For each user: to define the make and gmake commands, add this line to LOGIN.COM:"
$ say "    $ @MAKE$ROOT:[000000]MAKE$SETUP.COM"
$ say ""
$ say "    PRODUCT REMOVE MAKE removes the product and deassigns MAKE$ROOT."
$ say ""
$ exit 1
