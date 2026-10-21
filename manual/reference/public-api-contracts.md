# Public API Consumption Boundaries

Application code normally imports `chui.*`, or explicit names such as
`import chui.{TextArea, TextAreaVisualLine, PointerEvent, InputTransform}`.
A public subpackage declaration is not automatically visible through the root
package. Common consumer contracts therefore include their named result,
argument and provider types in the root facade.

| Consumer operation | Public facade contract |
| --- | --- |
| Store or return measured editor rows | `TextAreaVisualLine`, `TextArea.visualLines` |
| Normalize rich pointer input | `InputCoordinateSpace`, `InputTransform`, `WindowMetrics`, `PointerEvent`, `PointerDeviceKind`, `PointerPhase`, `PointerNormalizationDisposition`, `PointerNormalizationReceipt`, `normalizePointerEvent`, `pointerEventToLegacyUiEvent` |
| Submit platform input or bounded messages | `PointerInputBridge`, `BoundedMailbox<T>` |
| Implement an external frame provider | `ExternalFramePlane`, `ExternalFrameSnapshot` |
| Name a provider painter callback | `SymbolPainter` |
| Use provider symbols in a tree | `TreeNode.symbol`; see [Symbols](symbols.md) |

Platform implementations, native C entrypoints and generated probe/privileged
registration helpers remain in their owning subpackages. This facade does not
turn those implementation details into ordinary application contracts.

## Verification

```bash
python3 scripts/verify-public-api-consumer.py
```

The verifier copies the checked-in fixture into a temporary external package,
keeps only its declared `chui` dependency, compiles explicit and wildcard root
imports, and runs real provider callbacks plus eight light/dark, selected and
expanded tree scenarios. It checks recorded renderer commands as well as typed
input, text and frame contracts. This is deterministic source-consumer proof;
it does not certify physical devices or an older installed SDK snapshot.
