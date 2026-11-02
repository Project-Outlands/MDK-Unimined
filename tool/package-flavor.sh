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

flavor=${1:?usage: package-flavor.sh <flavor> [--build] [--loader <version>] [out-dir]}
shift
build=0
loader_override=""
out=""
while [ $# -gt 0 ]; do
    case "$1" in
        --build) build=1; shift ;;
        # Build the kit against another loader release than the pinned one (used by the compat workflow).
        --loader) loader_override=${2:?--loader needs a version}; shift 2 ;;
        *) out=$1; shift ;;
    esac
done
out=${out:-build/zips}

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

# Every zip is a self contained project. The wrapper lives at the repository root; the canonical tree keeps the same
# distribution so an IDE opening it does not download one of its own, and packaging copies the root files over it. A
# version bumped in one place only would make those two disagree, which is what this checks.
for file in gradle-wrapper.jar gradle-wrapper.properties; do
    if ! cmp -s "$root/gradle/wrapper/$file" "$stack/gradle/wrapper/$file"; then
        echo "$stack/gradle/wrapper/$file differs from the root wrapper: bump both, or drop the copy from the stack" >&2
        exit 1
    fi
done
cp "$root/gradlew" "$root/gradlew.bat" "$work"/
mkdir -p "$work/gradle"
cp -a "$root/gradle/wrapper" "$work/gradle/"

if [ -n "$loader_override" ]; then
    sed -i 's/^\( *\)loader ".*"$/\1loader "'"$loader_override"'"/' "$work/build.gradle"
    grep -q "loader \"$loader_override\"" "$work/build.gradle" || {
        echo "could not set loader $loader_override in $work/build.gradle" >&2
        exit 1
    }
fi

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
