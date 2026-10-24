# MDK-Unimined

Mod Development Kits for [Outlands](https://github.com/Project-Outlands) (the 1.12.2 loader), built on [Unimined](https://github.com/Project-Outlands/Unimined).

**Download a kit** from the [releases page](https://github.com/Project-Outlands/MDK-Unimined/releases) — every kit is a
self contained Gradle project, not a branch to check out.

| Kit | Contents |
|---|---|
| `mdk-java.zip` | Java example mod |
| `mdk-java-mixin.zip` | Java + mixin (loading plugin, config plugin, two mixin examples) |
| `mdk-kotlin.zip` | Kotlin example mod |
| `mdk-scala.zip` | Scala example mod |

Java and Kotlin/Scala do not mix in one kit on purpose: the language decides the whole source tree, while everything
else (shadow, access transformers, publishing) stays a `gradle/scripts/*.gradle` file you can edit or delete.

Mixin is only shipped for Java. If you are on Kotlin or Scala you are expected to be able to wire it yourself: copy
`stacks/unimined/flavors/mixin/files/src/main/java/**` and run its `patch.sh` against your project (it applies four
anchored edits to `build.gradle` / `gradle.properties`).

## Layout

```
stacks/unimined/            canonical tree = the java kit, directly buildable
stacks/unimined/flavors/    per flavor: files/ (new sources) + patch.sh (anchored edits) + remove.txt (deletions)
tool/package-flavor.sh      assembles a flavor, optionally builds it, and zips it
gradle/wrapper/             one wrapper, injected into every kit
```

A kit is never stored assembled: `tool/package-flavor.sh <flavor> --build` copies the canonical tree, applies the
overlay, runs `./gradlew build` **in the copy** and zips the result. If a flavor stops compiling, packaging fails
instead of shipping a broken kit.

```bash
./tool/package-flavor.sh java --build            # -> build/zips/mdk-java.zip
./tool/package-flavor.sh java-mixin --build      # -> build/zips/mdk-java-mixin.zip
```

Releases are cut by pushing a `mdk/<version>` tag; CI assembles every flavor, builds it, and attaches the zips.

## Version policy

A kit is not versioned with the loader. `mdk.properties` inside each zip records `mdk.version`, `mdk.flavor`,
`loader.version` and `source.commit`, which is what a bug report needs. The loader version a kit pins is the newest
stable one at packaging time; `.github/workflows/compat.yml` builds every flavor against the newest published loader
every night, so a stale pin shows up as a red build instead of in a user's workspace.
