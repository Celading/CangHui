package sdl

import std.collection.{ArrayList, HashMap}

/** Process-wide names for application-provided font files. */
public class Fonts {
    private static let registered = HashMap<String, String>()

    private init() {}

    public static func register(name: String, path: String): Unit {
        registered[name] = path
    }

    public static func pathFor(name: String): ?String {
        registered.get(name)
    }

    public static func isRegistered(name: String): Bool {
        registered.contains(name)
    }

    public static func unregister(name: String): Unit {
        let _ = registered.remove(name)
    }

    public static func clear(): Unit {
        registered.clear()
    }

    public static func names(): Array<String> {
        let out = ArrayList<String>()
        for ((name, _) in registered) {
            out.add(name)
        }
        out.toArray()
    }
}
