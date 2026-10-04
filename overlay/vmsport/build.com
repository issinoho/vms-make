$! BUILD.COM - build GNU make for OpenVMS with upstream's own VMS port
$!
$! Usage:  @[.VMSPORT]BUILD [target] [KEEP_GOING]
$!         target ALL (default) or CLEAN.  KEEP_GOING compiles every source
$!         with MAKEFILE.COM's qualifiers, carrying on past failed compiles
$!         (to see every problem at once), and does not link.
$!
$! GNU make ships its OpenVMS build as MAKEFILE.COM in the top directory,
$! maintained upstream; this procedure only runs it from the top of the
$! tree.  Output: MAKE.EXE in the top directory.
$!
$ status = 44  ! SS$_ABORT unless the build runs
$ on control_y then goto done
$ saved_default = f$environment("DEFAULT")
$ proc = f$environment("PROCEDURE")
$ vmsdir = f$parse(proc,,,"DEVICE") + f$parse(proc,,,"DIRECTORY")
$ set default 'vmsdir'
$ set default [-]
$ arch = f$edit(f$getsyi("ARCH_NAME"), "UPCASE")
$ target = f$edit(p1, "UPCASE")
$ if target .eqs. "" then target = "ALL"
$ write sys$output "BUILD: ''target' for ''arch' in ''f$environment("DEFAULT")'"
$ if target .eqs. "CLEAN"
$ then
$   if f$search("[.SRC]*.OBJ") .nes. "" then delete/nolog [.SRC]*.OBJ;*
$   if f$search("[.LIB]*.OBJ") .nes. "" then delete/nolog [.LIB]*.OBJ;*
$   if f$search("MAKE.EXE") .nes. "" then delete/nolog MAKE.EXE;*
$   status = 1
$   goto finish
$ endif
$ if f$search("MAKE.EXE") .nes. "" then delete/nolog MAKE.EXE;*
$ if f$edit(p2, "UPCASE") .eqs. "KEEP_GOING" then goto keep_going
$ @makefile.com
$ status = 44
$ if f$search("MAKE.EXE") .nes. "" then status = 1
$ goto finish
$!
$! The file list is read from MAKEFILE.COM, so it follows upstream; the
$! qualifiers are its compileit subroutine's.
$keep_going:
$ set noon
$ copy/nolog [.src]config.h-vms [.src]config.h
$ copy/nolog [.lib]fnmatch.in.h [.lib]fnmatch.h
$ copy/nolog [.lib]glob.in.h [.lib]glob.h
$ quote = """"
$ open/read mf makefile.com
$ list = ""
$ in_list = 0
$kg_read:
$ read/end=kg_read_done mf line
$ if f$locate("filelist =", line) .lt. f$length(line) then in_list = 1
$ if .not. in_list then goto kg_read
$ rest = f$extract(f$locate(quote, line) + 1, 999, line)
$ list = list + " " + f$extract(0, f$locate(quote, rest), rest)
$ if f$locate("getopt" + quote, line) .lt. f$length(line) then goto kg_read_done
$ goto kg_read
$kg_read_done:
$ close mf
$ list = f$edit(list, "COMPRESS,TRIM")
$ bad = 0
$ n = 0
$kg_loop:
$ cfile = f$element(n, " ", list)
$ if cfile .eqs. " " .or. cfile .eqs. "" then goto kg_done
$ objdir = f$extract(0, f$locate("]", cfile) + 1, cfile)
$ cc/decc/prefix=(all,except=(globfree,glob))/warn=(disable=questcompare) -
    /nested=none/include=([],[.src],[.lib])/obj='objdir' -
    /define=("allocated_variable_expand_for_file=alloc_var_expand_for_file",-
    "unlink=remove","HAVE_CONFIG_H","VMS") 'cfile'
$ sev = $severity
$ ok = sev .ne. 2 .and. sev .ne. 4
$ if .not. ok then bad = bad + 1
$ if .not. ok then write sys$output "KEEP_GOING: FAILED ''cfile'"
$ n = n + 1
$ goto kg_loop
$kg_done:
$ write sys$output "KEEP_GOING: ''n' sources, ''bad' failed"
$ status = 1
$ if bad .gt. 0 then status = 44
$finish:
$ if status then write sys$output "BUILD: done"
$done:
$ set default 'saved_default'
$ exit status
