# CangHui Scene3D bgfx4cj Provider

Optional `Scene3DDriver` implementation backed by
[`bgfx4cj`](https://gitcode.com/Cangjie-TPC/bgfx4cj).

The package keeps bgfx handles and CFFI objects outside application code. A
platform host supplies the native window pointer and its matching serializable
surface identity when constructing `Bgfx4cjDriver`; applications use CangHui
`Scene3DProvider` contracts. The driver rejects an attach when that identity
does not match `Scene3DHostSurface.opaqueHandle`.

Current scope is the provider lifecycle, resource-metadata staging, and a
clear-frame submission path. Scene snapshots are sealed at submission;
`loadScene` does not upload geometry, shaders, or textures yet. Picking and
platform runtime certification remain separate work.

This package is Apache-2.0. Its `bgfx4cj` dependency is MIT-licensed and retains
its own upstream notices and dependency obligations.
