#!/usr/bin/env bash
# Mixin flavor: wires the example mixin into the canonical build.
#
# Every edit asserts its anchor, so a change to the canonical build fails here instead of silently dropping the
# mixin wiring from the flavor.
set -euo pipefail

target=${1:?usage: patch.sh <assembled flavor dir>}

python3 - "$target" <<'PY'
import pathlib, sys

root = pathlib.Path(sys.argv[1])

def edit(relative, replacements):
    path = root / relative
    text = path.read_text()
    for old, new in replacements:
        if old not in text:
            raise SystemExit(f"{relative}: anchor not found:\n{old}")
        text = text.replace(old, new, 1)
    path.write_text(text)

edit('gradle.properties', [
    ('is_coremod = false', 'is_coremod = true'),
    ('coremod_plugin_class_name =', 'coremod_plugin_class_name = com.example.modid.ExampleLoadingPlugin'),
])

edit('build.gradle', [
    ('        runs.all {\n            args += [\'--username\', minecraft_username]',
     '        runs.all {\n            systemProperty("crl.dev.mixin", "${mod_id}.mixin.json")\n            args += [\'--username\', minecraft_username]'),
    ('    remap(tasks.named(jarTaskName).get())',
     '    remap(tasks.named(jarTaskName).get()) {\n        mixinRemap {\n            enableBaseMixin()\n            enableMixinExtra()\n        }\n    }'),
    ('            attribute_map[\'ModType\'] = "CRL"',
     '            attribute_map[\'ModType\'] = "CRL"\n            attribute_map[\'MixinConfigs\'] = "${mod_id}.mixin.json"'),
])
PY
