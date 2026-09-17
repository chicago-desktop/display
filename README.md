# chicago/display

Display Properties is an independent module. It owns desktop appearance settings
and the 3D Pipes preview. Install it alongside Chicago shell; it registers
**Start → Settings → Display Properties** and **desktop right-click → Properties**
through registry metadata. Its Welcome tip is registered by Display too. The shell does not import this module.

## Background layout

The Background page follows the classic dialog: the preview monitor above one
Wallpaper group — "Select a picture:", the list of the shell's wallpapers
(each with a picture, "(None)" first) on the left, and **Browse…**,
**Pattern…** and the **Display** drop-down (Center, Tile) on the right. Browse
is disabled until a file dialog serves it; the drop-down is disabled without a
wallpaper. Stretch is not offered: the desktop draws pictures at 1:1.

**Pattern…** opens the Pattern dialog (`chicago.display:pattern`): the hint,
the pattern list, a 1:1 preview over the pending desktop color, OK, Cancel and
a disabled **Edit Pattern…**. OK sends the choice back to Display Properties
as the pending pattern; **Apply** or **OK** there writes it, Cancel there
drops it.

## Screen Saver layout

The Screen Saver page follows the classic Display Properties structure: a static
monitor above the Screen saver group, a selector with Settings and Preview on
one row, Wait and resume controls, a separate Monitor power group, and the
standard OK / Cancel / Apply footer. The monitor does not animate.

**Settings…** opens a separate 3D Pipes Settings dialog with speed (Slow, Normal,
Fast), thickness (Thin, Normal, Thick), and palette (Classic, Chrome, Neon).
OK saves these preferences for the current user; Cancel discards edits. Each
Preview reads the latest saved settings. These settings are independent of the
Display window's Apply button, which applies desktop appearance changes.

Wait, Welcome screen on resume, and Power are disabled: automatic activation,
locking and operating-system power control are not implemented.

## 3D Pipes preview

Open **Display Properties > Screen Saver**, choose **3D Pipes**, and click
**Preview**. This release provides a manual preview only; it does not monitor
inactivity, start automatically or lock the desktop.

Eight colored pipes grow through a bounded 3D grid on a black background.
Occupied grid points are not reused. Each pipe advances in short steps, and a
completed or blocked scene pauses briefly before clearing and starting again.
The view uses perspective, depth shading and continuous rounded elbows. Nearby
pipes appear wider; distant paths converge into the scene.

- Preview covers the whole terminal, including the taskbar area, without a frame.
- Move the mouse, click, scroll or press any key to return to Display.
- The opening mouse release does not dismiss Preview. The dismissal gesture is
  consumed, so it cannot activate controls in Display or quit the desktop.
- Terminal resizing keeps Preview full-screen.

Pixel graphics (Kitty or Sixel) are required to see the animation. A terminal
without graphics displays an explanation; any key returns to Display.

## Architecture

- `chicago.display:window` owns the settings UI and uses the shell settings repository.
- `chicago.display:pattern` is the Pattern dialog; it writes nothing and
  answers the opener's pid on the `chicago.display.pattern` topic.
- `chicago.display:images` is the module's image pack (the Wallpaper list's
  pictures), drawn by `tools/display_images.py` (`make icons`).
- `chicago.display:desktop_properties` contributes a `chicago.desktop_menu` entry.
- `chicago.display.pipes:settings` owns the settings dialog; `options` validates
  the versioned `display_pipes_v1` setting in the existing per-user repository.
- `chicago.display.pipes:model` owns the bounded simulation; `render` draws it
  in the preview process, publishing PNG data through the SDK's `picture` node.
- The compositor uses the ordinary `chicago.shell.sdk:render`. No per-app theme
  imports, runtime changes or privileges are needed.
- Shared wallpaper and pattern catalogs remain shell rendering assets under
  `chicago.shell.display`; the Display application itself lives here.

The preview renders at the terminal's aspect ratio, capped at 800×600, and targets
five updates per second. Completed geometry is cached; only changing sections
are rasterized again. The cache is bounded to the current scene and discarded
when it resets. The preview writes no files, preferences or database entries.

## Installation

Use Chicago shell **0.3.1 or later**, based on tui-desktop **0.2.3 or later**.
Add this dependency to your application's registry and run `wippy install`:

```yaml
- name: display
  kind: ns.dependency
  component: github.com/chicago-desktop/display
  version: ">=0.1.2"
```

No host-owned resources or dependency parameters are required. The module uses
the shell's existing per-user settings. Its `chicago.tip` contribution appears
when Welcome is installed, without a dependency on Welcome itself.

## Local preview

```sh
cd test
CHICAGO_PIXELS=1 ../../app/bin/wippy run --host chicago.shell:terminal chicago
```

Right-click the desktop, then **Properties → Screen Saver → Preview**.

## Development

With a Chicago runtime containing `gfx` at `../app/bin/wippy`:

```sh
cd test
../../app/bin/wippy install
cd ..
make test
make lint
```

The harness replaces Display, shell and tui-desktop with sibling working copies.
It owns all test host resources; the product module declares none. Tests include
layout, settings updates, bounded growth, perspective, rounded elbows and close, launch failure and
real raster rendering at two window sizes (`test/shots/pipes_*.png`), and the
Background page and the Pattern dialog at 8×16 and 10×20
(`test/shots/background_*.png`, `test/shots/pattern_*.png`).

## Migration

The former `chicago.shell.display:window` is now `chicago.display:window`.
Update saved shortcuts or integrations naming the old entry. Existing appearance
settings remain in the same shell repository and need no data migration.
The shell's own harness no longer depends on Display; installing shell alone
provides the desktop and SDK without this optional settings application.

See the shell's `docs/desktop-menu.md` and `docs/sdk.md` for extension contracts.
