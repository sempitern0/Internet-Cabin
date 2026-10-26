# Screenshot Capture Quickstart

## Purpose

`NucleusWindow` can capture any Godot `Viewport` into an `Image` and save it as:

```text
PNG
JPEG
WebP
```

Typical uses include:

```text
Steam/store screenshots
press kits
social thumbnails
development comparisons
marketing stills
trailer title-card/source frames
```

This is a still-image utility, not a video recorder.

## Default screenshot directory

Nucleus exposes:

```gdscript
NucleusPaths.screenshots_directory()
```

which resolves under the project's writable user-data directory.

## One-shot screenshot

Build the path first so the caller knows exactly where the file will be written:

```gdscript
var path := NucleusWindow.build_screenshot_path(
	"",
	"steam",
	"png",
)

var error := await NucleusWindow.capture_screenshot_to_file(
	get_viewport(),
	path,
)

if error == OK:
	print("Screenshot saved: ", path)
```

`capture_screenshot_to_file()` waits for `RenderingServer.frame_post_draw`
before reading the viewport.

## Capture without saving

```gdscript
var image: Image = await NucleusWindow.capture_viewport_after_draw(
	get_viewport()
)
```

Or, when your code already runs after `frame_post_draw`:

```gdscript
var image := NucleusWindow.capture_viewport(get_viewport())
```

## Hide HUD for marketing capture

Nucleus deliberately does not know which CanvasLayers/Controls belong to your
game HUD.

Handle game presentation locally:

```gdscript
hud.hide()

var path := NucleusWindow.build_screenshot_path(
	"",
	"marketing",
	"png",
)

var error := await NucleusWindow.capture_screenshot_to_file(
	get_viewport(),
	path,
)

hud.show()
```

Waiting for the render frame ensures the captured frame reflects the hidden HUD.

## High-resolution capture

The captured image uses the selected Viewport's rendered output.

For marketing masters, either:

- temporarily run the game at the desired capture resolution; or
- render a dedicated `SubViewport` at the desired resolution and pass it to
  `NucleusWindow`.

Nucleus does not silently resize the game window or modify graphics settings.

## Formats

### PNG

Recommended default for source/master screenshots:

```gdscript
NucleusWindow.build_screenshot_path("", "steam", "png")
```

Lossless and predictable.

### JPEG

Useful when file size matters:

```gdscript
await NucleusWindow.capture_screenshot_to_file(
	get_viewport(),
	path,
	0.9,
)
```

The quality parameter applies to JPEG and lossy WebP.

### WebP

`save_screenshot_image()` and `capture_screenshot_to_file()` can write WebP.

Pass `webp_lossy = true` only when lossy output is intentional.

## Saving an existing Image

```gdscript
var error := NucleusWindow.save_screenshot_image(
	image,
	path,
	0.9,
)
```

Parent directories are created through `NucleusFileUtils`.

## Performance boundary

Viewport image capture copies texture data from GPU-accessible rendering data
into a CPU-side `Image`.

Use it for occasional still captures, not every frame.

For actual trailer/video recording, use a dedicated recording/capture workflow
rather than repeatedly calling the screenshot API.

## Headless behavior

A headless process should not be treated as a screenshot renderer.

The screenshot path/file helpers are unit-tested headlessly; visual capture must
be validated in a normal rendering session.
