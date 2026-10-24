#!/usr/bin/env bash
#
# Assembles one flavor of the Unimined MDK and produces the zip users download.
#
#   tool/package-flavor.sh java [--build] [out-dir]
#
# The flavor is assembled from two parts and never stored assembled in the repository:
#
#   stacks/unimined            the canonical tree, and by itself the 'java' flavor
#   stacks/unimined/flavors/*  only the files that differ, copied over the canonical tree
#
# '--build' additionally runs './gradlew build' in the assembled copy, so a flavor that no longer compiles fails
# here instead of in the hands of a user. The zip stays a plain project: no flavors/, no tool/, and no assembly
# leftovers.
set -euo pipefail

flavor=${1:?usage: package-flavor.sh <flavor> [--build] [out-dir]}
shift
build=0
if [ "${1:-}" = "--build" ]; then
    build=1
    shift
fi
out=${1:-build/zips}

root=$(cd "$(dirname "$0")/.." && pwd)
stack=$root/stacks/unimined
work=$root/build/flavors/$flavor

if [ ! -d "$stack" ]; then
    echo "missing $stack" >&2
    exit 1
fi

rm -rf "$work"
mkdir -p "$work"
cp -a "$stack"/. "$work"/
rm -rf "$work/flavors" "$work/.git"

if [ "$flavor" != "java" ]; then
    overlay=$stack/flavors/${flavor#java-}
    if [ ! -d "$overlay" ]; then
        echo "unknown flavor '$flavor' (no $overlay)" >&2
        exit 1
    fi
    if [ -f "$overlay/remove.txt" ]; then
        while IFS= read -r path; do
            [ -z "$path" ] && continue
            case "$path" in \#*) continue ;; esac
            rm -rf "${work:?}/$path"
        done < "$overlay/remove.txt"
    fi
    if [ -d "$overlay/files" ]; then
        cp -a "$overlay/files"/. "$work"/
    fi
    # Overlays that touch the shared build files do it with assert-anchored edits instead of replacing them, so a
    # change to the canonical build breaks the packaging instead of silently dropping the flavor wiring.
    if [ -x "$overlay/patch.sh" ]; then
        "$overlay/patch.sh" "$work"
    fi
fi

# Every zip is a self contained project: the wrapper lives at the repository root so all flavors share one copy.
cp "$root/gradlew" "$root/gradlew.bat" "$work"/
mkdir -p "$work/gradle"
cp -a "$root/gradle/wrapper" "$work/gradle/"

loader_version=$(sed -n 's/^ *loader "\(.*\)"$/\1/p' "$work/build.gradle" | head -1)
commit=$(git -C "$root" rev-parse --short HEAD 2>/dev/null || echo unknown)
mdk_version=${MDK_VERSION:-$(git -C "$root" describe --tags --always --dirty 2>/dev/null || echo dev)}
cat > "$work/mdk.properties" <<EOF
# Filled in by tool/package-flavor.sh: quote these in a bug report.
mdk.version=$mdk_version
mdk.flavor=$flavor
loader.version=${loader_version:-unknown}
source.commit=$commit
EOF

if [ "$build" = "1" ]; then
    echo "== building $flavor"
    (cd "$work" && ./gradlew build --console=plain)
fi

rm -rf "$work/build" "$work/.gradle" "$work/run" "$work/out"

mkdir -p "$root/$out"
zip_path=$root/$out/mdk-$flavor.zip
rm -f "$zip_path"
(cd "$work" && zip -qr "$zip_path" .)
echo "== $zip_path"
