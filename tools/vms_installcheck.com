$! VMS_INSTALLCHECK.COM <tree-dir-name> - install the MAKE kit, verify, smoke-test
$! the installed image, then remove it.  Changes the system while it runs (PCSI
$! database, SYS$COMMON:[MAKE], system logical MAKE$ROOT); leaves it as it was.
$ set noon
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ base = "I64VMS"
$ if arch .eqs. "X86_64" then base = "X86VMS"
$ tree = f$environment("DEFAULT") - "]" + "." + p1 + "]"
$ kitdir = tree - "]" + ".KIT_''arch']"
$ write sys$output "=== INSTALL from ", kitdir
$ product install MAKE /producer=ISSINOHO /base_system='base' /source='kitdir' /options=noconfirm /log
$ write sys$output "=== install status ", $status
$ product show product MAKE /producer=ISSINOHO
$ write sys$output "=== VERIFY"
$ write sys$output "startup procedure: [", f$search("SYS$STARTUP:MAKE$STARTUP.COM"), "]"
$ show logical MAKE$ROOT
$ directory/nohead/notrail MAKE$ROOT:[000000...]*.*
$ @MAKE$ROOT:[000000]MAKE$SETUP.COM
$ show symbol make
$ show symbol gmake
$ make --version
$ write sys$output "=== SMOKE TEST on installed image"
$ smoke = tree - "]" + ".VMSPORT]TEST_SMOKE.COM"
$ @'smoke' MAKE$ROOT:[BIN]MAKE.EXE
$ write sys$output "=== REMOVE"
$ product remove MAKE /producer=ISSINOHO /options=noconfirm /log
$ write sys$output "=== remove status ", $status
$ write sys$output "MAKE$ROOT after removal: [", f$trnlnm("MAKE$ROOT"), "]"
$ write sys$output "files after removal: [", f$search("SYS$COMMON:[MAKE...]*.*"), "]"
$ write sys$output "startup after removal: [", f$search("SYS$STARTUP:MAKE$STARTUP.COM"), "]"
$ product show product MAKE /producer=ISSINOHO
$ delete/symbol/global make
$ delete/symbol/global gmake
