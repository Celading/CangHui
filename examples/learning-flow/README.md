# Learning flow

A small ordinary CangHui application, not a game engine. Model, actions and view are separate. One answer can award points only once; retry resets the lesson.

From the framework root, using the matching debug CUIC:

```sh
cuic build macos examples/learning-flow
cuic test macos examples/learning-flow
cuic prntx examples/learning-flow learning.phone --format summary
cuic prntx examples/learning-flow learning.desktop --format summary
cuic prntx examples/learning-flow learning.phone --format json --events 'focus lesson.start
key Enter
focus lesson.correct
key Enter
focus lesson.finish
key Enter
assert activation lesson.finish 1'
cuic prnt macos examples/learning-flow --output /tmp/learning-flow.bmp
```

The probes use 360 and 800 logical units. They test layout and callbacks, not real touch hardware or physical DPI changes. Debug-only automation must not be enabled in distributed builds.

The repository-relative dependency is for this checked-out example. Consumer projects should pin a reviewed framework revision or use a versioned offline package; do not modify a package cache or vendor the development workspace.

No audio, vocabulary database, persistence or mobile host is bundled. See the [migration guide](../../manual/guide/how-to/migrate-learning-app.md) before adapting a real application.
