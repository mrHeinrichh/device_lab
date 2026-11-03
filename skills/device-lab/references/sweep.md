# Sweep service extensions

`DeviceLab` registers four VM service extensions when it is enabled, so any app that uses it can be
driven by an agent or a script with no wiring of its own. They exist only in debug and profile runs
(`dart:developer` extensions are no-ops in release) and act on the most recently mounted `DeviceLab`.

Call them with the Dart MCP server's `vm_service` tool (`command: callMethod`, `method: <name>`,
`isolateId: <main isolate>`, `arguments: {...}` — every argument is a string), or from DevTools.

## Contents

1. [Selectors](#selectors)
2. [`ext.deviceLab.devices`](#extdevicelabdevices)
3. [`ext.deviceLab.sweep`](#extdevicelabsweep)
4. [`ext.deviceLab.show`](#extdevicelabshow)
5. [`ext.deviceLab.capture`](#extdevicelabcapture)
6. [Reading large responses](#reading-large-responses)

## Selectors

Shared by `devices` and `sweep`:

| Param | Value | Example |
| --- | --- | --- |
| `category` | a `DeviceCategory` name: `phone`, `foldable`, `tablet`, `desktop`, `watch`, `tv` | `tablet` |
| `platform` | a `TargetPlatform` name: `iOS`, `android`, `macOS`, `windows`, `linux`, `fuchsia` | `iOS` |
| `ids` | comma-separated catalog ids; overrides `category` and `platform` | `apple.ipad-pro-11-m4,samsung.galaxy-z-fold-7` |

Request → selectors: tablets → `category=tablet`; iPads → `category=tablet` + `platform=iOS`; Android
tablets → `tablet` + `android`; phones → `phone`; iPhones → `phone` + `iOS`; foldables → `foldable`; flips,
one vendor or one generation → list with `devices`, then pass `ids`.

## `ext.deviceLab.devices`

Returns `{count, devices: [{id, name, category, platform, size: [w, h], rotatable, foldable}]}` in
catalog order. Use it first to confirm how many devices a request covers.

## `ext.deviceLab.sweep`

Shows every selected device in turn and records the Flutter errors raised while each was on screen.

| Param | Default | Meaning |
| --- | --- | --- |
| `offset`, `limit` | all | Batch a long category (78 phones × 2 orientations = 156 cases): `limit=20`, `offset=0,20,40,60` |
| `orientations` | `both` | `both` or `natural`. Only rotatable devices get both. |
| `postures` | `all` | Foldables only: `all` (folded and flat), `every` (adds half opened) or `open` |
| `settleMs` | `600` | Wait after each switch before reading errors. Raise it for screens that load on rebuild. |
| `screenshots` | `none` | `none`, `failures` or `all` |
| `pixelRatio` | `0.5` | Screenshot scale against the simulated logical size |

Returns `{count, failed, results}`. Each result:
`{id, name, orientation, posture, size: [w, h], errors: [...], screenshot?}`. An error is the error
summary (for example `A RenderFlex overflowed by 12 pixels on the right.`) plus the source location of
the widget that caused it. Errors raised by device_lab's own panel are prefixed `[device_lab]` and are
not counted in `failed`. The device, orientation, posture and preview visibility in place before the
sweep are restored when it ends. Only one sweep runs at a time.

A sweep covers the screen that is showing. It does not see layouts that are wrong without raising an
error, or code that only runs on interaction.

## `ext.deviceLab.show`

`id` (required), `orientation` (`portrait` or `landscape`), `posture` (`folded`, `halfOpened`, `flat`).
Switches the preview to that case, keeps it there, and returns the case record. Use it to reproduce a
failure before fixing it.

## `ext.deviceLab.capture`

`pixelRatio` (default `0.5`). Returns `{id, orientation, posture, size, screenshot}`: a base64 PNG of the
simulated screen only, without the device frame or the tools panel.

## Reading large responses

Screenshots make responses large; a tool may save the response to a file instead of returning it. Parse
it with a script and decode screenshots rather than reading it whole:

```sh
python3 - "$RESPONSE_FILE" <<'EOF'
import base64, json, pathlib, sys
text = pathlib.Path(sys.argv[1]).read_text()
data = json.loads(text[text.index('{'):])
data = data.get('result', data)
for r in data['results']:
    if r['errors']:
        print(r['id'], r['orientation'], r['posture'], r['errors'])
    if r.get('screenshot'):
        out = pathlib.Path(f"/tmp/sweep/{r['id']}-{r['orientation']}-{r['posture']}.png")
        out.parent.mkdir(parents=True, exist_ok=True)
        out.write_bytes(base64.b64decode(r['screenshot']))
print(data['count'], 'cases,', data['failed'], 'failed')
EOF
```
