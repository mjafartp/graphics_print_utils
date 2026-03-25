## 2.0.0-beta
### Performance
* Fixed `_ensureHeight` growth calculation — now uses true exponential growth based on current height, significantly reducing resize operations for large receipts.
* Reduced redundant pixel fill operations during canvas resizing (only fills new area).
* Converted `text()` from recursive to iterative multi-line rendering, eliminating O(n²) re-splitting.
* Eliminated PNG encode/decode round-trip in `GraphicsPrintUtilsCommandBased` image transfer (uses raw pixel bytes).

### Breaking Changes
* Removed deprecated `build1()` method — use `build()` instead.
* Updated `image` dependency to `^4.8.0`.

### Improvements
* Added network printing example using `flutter_esc_pos_network`.
* Removed dead code (commented-out methods, debug prints).
* Cleaned up dart analyzer warnings in example app.

## 0.0.8
* Added support for default TextStyle with configurable text size.

## 0.0.6
* Added support for Dotted Line.

## 0.0.5
* Global TextStyle added .

