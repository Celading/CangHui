package sdl.text

// Ordered, length-delimited fields: font paths may legally contain separators and newlines.
// The count also makes the end of the chain unambiguous before appending a text cache key.
protected func fontPathChainKey(paths: Array<String>): String {
    let out = StringBuilder()
    out.append(paths.size.toString())
    for (path in paths) {
        out.append("|")
        out.append(path.size.toString())
        out.append(":")
        out.append(path)
    }
    out.toString()
}
