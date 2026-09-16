# chicago/display

Display Properties is an independent module. It owns desktop appearance settings
and the 3D Pipes preview. Install it alongside Chicago shell; it registers
**Start → Settings → Display Properties** and **desktop right-click → Properties**
through registry metadata. Its Welcome tip is registered by Display too. The shell does not import this module.

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
- `chicago.display:desktop_properties` contributes a `chicago.desktop_menu` entry.
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
  version: ">=0.1.1"
```

No host-owned resources or dependency parameters are required. The module uses
the shell's existing per-user settings. Its `chicago.tip` contribution appears
when Welcome is installed, without a dependency on Welcome itself.

## Local preview

```sh
cd test
CHICAGO_PIXELS=1 ../../app/bin/wippy-floppy run --host chicago.shell:terminal chicago
```

Right-click the desktop, then **Properties → Screen Saver → Preview**.

## Development

With a Chicago runtime containing `gfx` at `../app/bin/wippy-floppy`:

```sh
cd test
../../app/bin/wippy-floppy install
cd ..
make test
make lint
```

The harness replaces Display, shell and tui-desktop with sibling working copies.
It owns all test host resources; the product module declares none. Tests include
layout, settings updates, bounded growth, perspective, rounded elbows and close, launch failure and
real raster rendering at two window sizes (`test/shots/pipes_*.png`).

## Migration

The former `chicago.shell.display:window` is now `chicago.display:window`.
Update saved shortcuts or integrations naming the old entry. Existing appearance
settings remain in the same shell repository and need no data migration.
The shell's own harness no longer depends on Display; installing shell alone
provides the desktop and SDK without this optional settings application.

See the shell's `docs/desktop-menu.md` and `docs/sdk.md` for extension contracts.
