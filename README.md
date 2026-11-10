# MDK-Unimined

Mod Development Kits for [Outlands](https://github.com/Project-Outlands) (the 1.12.2 loader), built on [Unimined](https://github.com/Project-Outlands/Unimined).

**Download a kit** from the [releases page](https://github.com/Project-Outlands/MDK-Unimined/releases) — every kit is a
self contained Gradle project, not a branch to check out.

| Kit | Contents |
|---|---|
| `mdk-java.zip` | Java example mod |
| `mdk-java-mixin.zip` | Java + mixin (loading plugin, config plugin, two mixin examples) |

Mixin ships only as its own kit: it is not a switch on the example, it changes the source shape (loading plugin,
config plugin, mixin json) and adds four lines of build wiring. Wiring it into another language's project is a
source-tree decision, so the overlay is readable: copy `stacks/unimined/flavors/mixin/files/src/main/java/**` and run
its `patch.sh` against your project (four anchored edits to `build.gradle` / `gradle.properties`).

Everything else (shadow, access transformers, publishing) stays a `gradle/scripts/*.gradle` file you can edit or
delete, so a kit is a starting point, not a framework.

## Layout

```
stacks/unimined/            canonical tree = the java kit, directly buildable
stacks/unimined/flavors/    per flavor: files/ (new sources) + patch.sh (anchored edits) + remove.txt (deletions)
tool/package-flavor.sh      assembles a flavor, optionally builds it, and zips it
gradle/wrapper/             the wrapper every kit ships; the canonical tree carries the same files
```

The canonical tree holds a copy of `gradle/wrapper/` (not of `gradlew`, which packaging injects) so that opening
`stacks/unimined` in an IDE uses the kit's Gradle instead of downloading whatever the IDE defaults to. Packaging copies
the root wrapper over it and refuses to start if the two disagree, so a version bump cannot land in only one of them.

A kit is never stored assembled: `tool/package-flavor.sh <flavor> --build` copies the canonical tree, applies the
overlay, runs `./gradlew build` **in the copy** and zips the result. If a flavor stops compiling, packaging fails
instead of shipping a broken kit.

```bash
./tool/package-flavor.sh java --build            # -> build/zips/mdk-java.zip
./tool/package-flavor.sh java-mixin --build      # -> build/zips/mdk-java-mixin.zip
```

Releases are cut by pushing a `mdk/<version>` tag; CI assembles every flavor, builds it, and attaches the zips.

### Automatic loader releases

`.github/workflows/update-loader.yml` accepts an `outlands-released` repository dispatch. It waits for the version to
appear on Maven, builds every kit, commits the new loader pin to `main`, and pushes the corresponding `mdk/<version>`
tag. It then explicitly dispatches the existing MDK workflow to build and publish the release archives: a tag pushed
with the receiving workflow's `GITHUB_TOKEN` would not start another workflow by itself. A repeated dispatch is
harmless, and a dispatch for an older loader is rejected instead of downgrading the pin. The nightly compat build
remains the fallback if a dispatch is missed.

Add this step at the end of `Release` in the Outlands repository's `.github/workflows/Release.yml`, after its `Verify`
step, so the MDK is notified only after both Maven and the GitHub release are ready:

```yaml
      - name: Trigger MDK update
        env:
          VERSION: ${{ steps.version.outputs.version }}
          GH_TOKEN: ${{ secrets.MDK_DISPATCH_TOKEN }}
        run: |
          set -euo pipefail
          gh api repos/Project-Outlands/MDK-Unimined/dispatches \
            -X POST \
            -f event_type=outlands-released \
            -f "client_payload[version]=$VERSION"
```

Create `MDK_DISPATCH_TOKEN` as an Actions secret **in the Outlands repository**. A fine-grained personal access token
with `Contents: Read and write` on only `Project-Outlands/MDK-Unimined` is sufficient; the source repository's
`GITHUB_TOKEN` cannot dispatch another repository. The receiving workflow must be on this repository's default branch,
and the Actions bot must be allowed to push to `main`. It can also be run manually with a loader CalVer to recover a
missed release.

## Version policy

A kit is not versioned with the loader. `mdk.properties` inside each zip records `mdk.version`, `mdk.flavor`,
`loader.version` and `source.commit`, which is what a bug report needs. The loader version a kit pins is the newest
stable one at packaging time; `.github/workflows/compat.yml` builds every flavor against the newest published loader
every night, so a stale pin shows up as a red build instead of in a user's workspace.
