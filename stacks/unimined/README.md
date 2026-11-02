# Outlands Mod Development Kit

Template for a 1.12.2 Outlands mod, built on [Unimined](https://github.com/Project-Outlands/Unimined).

This kit is the plain **Java** one; the mixin variant is the same project plus a loading plugin, a config plugin and
two example mixins (your zip is called `mdk-java-mixin.zip` in that case).

`mdk.properties` records which kit this is, the loader version it pins, and the commit it was cut from. Quote it in a
bug report.

## First steps

1. `gradle.properties`: set `mod_id`, `mod_name`, `root_package`, `mod_version`.
2. Rename `src/main/resources/modid_at.cfg` to `<your mod id>_at.cfg` (or set `access_transformer_locations`), and drop
   the example entry inside it if you do not need an access transformer.
3. Move the example classes from `com.example.modid` to your own package. `Reference` is generated from
   `src/main/java-templates`, keep it in your top package.
4. `./gradlew build` and `./gradlew runClient`.

### Running Client or Server
If you are using IntelliJ, **DO NOT** use the `Minecraft Client` configure with a blue icon. Just use the `2. Run Client` Gradle task.

### Adding Mod Dependencies
You can find the dependencies block in `gradle/scripts/dependencies.gradle`.

No more `rfg.deobf()` or `fg.deobf`. You **MUST** add mods by using `modImplementation` or `modRuntimeOnly`, or the game will crash when running.

Use `modLibrary` for libs/mods that you don't want to remap.

### Non-Mod Dependencies
`shadow` bundles a dependency into the shadow jar. For a jar that ships *inside* this one, wrap the declaration in
`contained(...)` - Unimined then copies it to `META-INF/libraries` and states it in `mcmod.info`. See
`dependencies.gradle`.

### gradle.properties
Edit gradle.properties and set your modid, mod version, mod name, package, etc.

If you are writing a coremod, remember to set related settings to true.

### Reference Class
There will be a `Reference` class under your top package.

This is used to store mod version so you can fill it to `@Mod` annotation.

You should change its location to fit your new package name.

You can find its template under `src/main/java-templates`.

### Mixin
1. Rename json config file to use your modid. 
2. Add **all** your mixin classes there.
3. Use `IMixinConfigPlugin` to control if certain mixin should be enabled.
4. mixin classes will be passed to the plugin only when target class is loading, so you don't need to call `Loader.isModLoaded()`
5. Don't worry about refmap, Unimined will handle it automatically. You can still `disableRefmap()` manually though

### Access Transformer
You **MUST** write AT file in MCP name. It will be remapped back to SRG name in artifact jar.

Rename AT file name to your modid before using it. There's an example entry in AT file, remove it if you want to use AT.

The file's path is relative to `META-INF/`: that is where the loader opens it, and it is what the `mcmod.info` jar
section declares. `access_transformer_locations` states it; a development run applies the first location only.

### Vanilla Source Code with Comments
Run `genSources` task in gradle. If it didn't work, run again until a file with `-sources.jar` suffix appeared.

If you want to `find usage` from vanilla like RFG, just change the scope in IntelliJ settings.

### Publishing
`gradle/scripts/publishing.gradle` publishes the jar to the maven you configure in `gradle.properties`
(`publish_to_maven`, `maven_name`, `maven_url`, credentials from `~/.gradle/gradle.properties` or the environment):

```bash
./gradlew publish
```

CurseForge/Modrinth uploads and GitHub releases are left to you on purpose: every author wants different
metadata, and a workflow you did not write is a workflow you cannot debug. The kit ships what is reusable.

### GitHub Action
`build.yml` builds and uploads a jar artifact for every commit, which is enough to hand out test builds.
A tag-triggered release workflow and a CurseForge/Modrinth publisher were part of the original Cleanroom
template - copy them from there if you want them, they need your project ids and tokens.

### Credit
Thanks @Karnatour for fixing shadow plugin