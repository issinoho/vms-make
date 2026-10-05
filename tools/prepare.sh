#!/usr/bin/env bash
# prepare.sh - build a VMS-ready GNU make source tree in staging/<name>-<version>/
#
#   1. fetch + verify the upstream tarball
#   2. extract it, apply patches/series, lay overlay/ over the top
#
# GNU make ships its own OpenVMS port (makefile.com, src/config.h-vms,
# src/vms*.c, mk/VMS.mk), maintained upstream, so as for gawk (vms-awk) there
# is no host-side configure.  Our own VMS files live in vmsport/.
#
# Nothing in staging/ is ever edited by hand: fix things in patches/ or overlay/.
set -euo pipefail

top=$(cd "$(dirname "$0")/.." && pwd)
. "$top/upstream.conf"
name=$UPSTREAM_NAME-$UPSTREAM_VERSION
tarball=$top/cache/$(basename "$UPSTREAM_URL")
stage=$top/staging/$name

step() { echo "prepare: $*"; }
die() { echo "prepare: error: $*" >&2; exit 1; }

"$top/tools/fetch.sh" >/dev/null

step "extracting $name"
rm -rf "$stage"; mkdir -p "$top/staging"
tar -xzf "$tarball" -C "$top/staging"
[ -d "$stage" ] || die "tarball did not unpack to $stage"

while read -r p; do
    case $p in ''|'#'*) continue ;; esac
    step "patch $p"
    patch -d "$stage" -p1 -s --no-backup-if-mismatch -F0 < "$top/patches/$p" ||
        die "patch $p does not apply cleanly"
done < "$top/patches/series"

# overlay/ may only add files; changes to upstream files belong in patches/.
(cd "$top/overlay" && find . -type f) | while read -r f; do
    [ -e "$stage/$f" ] && die "overlay/$f would replace an upstream file; use a patch"
    true
done
cp -a "$top/overlay/." "$stage/"

# Every source the Unix build compiles must be in upstream's VMS build too:
# a release whose makefile.com misses a new source would not link.  Sources
# that are only for features VMS does not have are listed with a reason.
notvms="src/loadapi"   # the load directive (loadable objects); not on VMS
unix=$(awk '/^(make|vms|glob)_SRCS *=/,/^$/' "$stage/Makefile.am" | tr ' \t\\' '\n\n\n' |
       sed -n 's/\.c$//p' | LC_ALL=C sort -u)
vms=$(sed -n '/^\$ filelist =/,/getopt"$/p' "$stage/makefile.com" | grep -oE '\[\.(src|lib)\][a-z0-9_-]+' |
      sed 's/\[\.\(src\|lib\)\]/\1\//' | LC_ALL=C sort -u)
missing=$(LC_ALL=C comm -23 <(echo "$unix") <(echo "$vms") | grep -vxF -e "$notvms" || true)
[ -z "$missing" ] || die "makefile.com lacks sources the Unix build uses: $missing"
step "makefile.com covers all $(echo "$unix" | wc -l) sources (less: $notvms)"

printf 'VERSION=%s\nKIT_VERSION=%s-vms%s\n' "$UPSTREAM_VERSION" "$UPSTREAM_VERSION" \
    "$VMS_PATCH_LEVEL" > "$stage/vmsport/version.env"
# --- PCSI kit inputs (vmsport/kit/MAKE_KIT.COM builds the kit on each node) --
kit=$stage/vmsport/kit
: "${KIT_PRODUCER:=ISSINOHO}"
# Three-part versions (4.4.1): the third part is the PCSI update and our VMS
# patch level the ECO, as in vms-awk, so 4.4.1-vms1 is V4.4-1E1.
IFS=. read -r major minor update _ <<< "$UPSTREAM_VERSION"
pcsiversion="V$major.$minor-${update:-0}E$VMS_PATCH_LEVEL"
kitversion="$UPSTREAM_VERSION-vms$VMS_PATCH_LEVEL"
subst() {
    sed -e "s/@PRODUCER@/$KIT_PRODUCER/g" -e "s/@BASE@/$1/g" \
        -e "s/@PCSIVERSION@/$pcsiversion/g" -e "s/@VERSION@/$UPSTREAM_VERSION/g" \
        -e "s/@KITVERSION@/$kitversion/g" -e "s/@ARCH@/$2/g"
}
for base in I64VMS X86VMS; do
    subst $base "" < "$kit/make.pcsi\$desc_template" > "$kit/MAKE-$base.PCSI\$DESC"
    subst $base "" < "$kit/make.pcsi\$text_template" > "$kit/MAKE-$base.PCSI\$TEXT"
done
rm -f "$kit/make.pcsi\$desc_template" "$kit/make.pcsi\$text_template"
subst "" "IA64 and x86-64" < "$kit/readme.vms" > "$kit/README.VMS"; rm -f "$kit/readme.vms"
mkdir -p "$kit/doc"
cp "$stage/doc/make.1" "$kit/doc/MAKE.1"
cp "$stage/README.VMS" "$kit/doc/README_UPSTREAM.VMS"
cp "$stage/COPYING" "$kit/doc/COPYING."
cp "$stage/NEWS" "$kit/doc/NEWS."
# The manual: the doc/make.info* files are plain text apart from Info's
# control lines (no makeinfo needed on the host).
cat "$stage/doc/make.info-"[0-9]* |
    sed -e '/^\x1f/d' -e '/^Tag Table:/,$d' -e 's/\x7f[0-9]*//' |
    tr -d '\000-\010\016-\037\177' > "$kit/doc/MAKE.TXT"
printf 'KIT_PRODUCER=%s\nPCSI_VERSION=%s\nKIT_VERSION=%s\n' "$KIT_PRODUCER" "$pcsiversion" \
    "$kitversion" > "$kit/kit.env"
step "staged $stage"
