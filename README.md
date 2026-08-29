# Anneau

[![Build and Test](https://github.com/lagenorhynque/anneau/actions/workflows/build-and-test.yaml/badge.svg)](https://github.com/lagenorhynque/anneau/actions/workflows/build-and-test.yaml)

An HTTP server library for [Flix](https://flix.dev/).

*Anneau* is French for **ring**. The name is a nod to
[Ring](https://github.com/ring-clojure/ring), the Clojure web library this one takes its
cue from.

Routing is a statically typed DSL. A path is a value whose type records the parameters
it captures, and that one value both matches an incoming request and generates URIs, so
the two can never drift apart.

## Status

Early. Milestone 1 is done: `Anneau.Router.Codec` and `Anneau.Router.Path` are
implemented and tested. There is no HTTP layer and no server yet, so Anneau cannot serve
a request on its own. Nothing about the API is stable.

## A typed path

```flix
use Anneau.Router.Codec
use Anneau.Router.Codec.SegmentCodec
use Anneau.Router.Path
use Anneau.Router.Path.{$$, literal, param}

// Give each identifier its own type, and a to-do id can no longer be passed
// where a user id is expected.
enum ToDoId(Int32) with Eq, ToString

instance SegmentCodec[ToDoId] {
    pub def codec(): Codec[ToDoId] =
        Codec.int32() |> Codec.wrap(
            "ToDoId",
            decode = ToDoId,
            encode = id -> let ToDoId(v) = id; v
        )
}

// The type index says it: this path captures exactly one `ToDoId`.
def toDoPath(): Path[ToDoId -> a, a] =
    literal("todos") $$ param("id")

// A handler is an ordinary curried function whose leading arguments are the
// captures. `String` stands in here for the request and response types of
// Milestone 2.
def showToDo(id: ToDoId, req: String): String =
    let ToDoId(n) = id;
    "${req} to-do #${n}"
```

One value, read in both directions:

```flix
Path.describe(toDoPath())          // "/todos/{id: ToDoId}"
Path.link(toDoPath())(ToDoId(42))  // "/todos/42"

let matched = Path.matchUri(toDoPath(), "/todos/42")
    |> Option.map(h -> h(showToDo));
matched |> Option.map(f -> f("GET"))  // Some("GET to-do #42")

Path.matchUri(toDoPath(), "/todos/x")  // None: "x" is not a ToDoId
```

Because the path knows what it captures:

- a handler whose parameters do not match the path is a compile error, not a 500
- URIs are built by function application, so a route that does not exist cannot be
  named and its arguments cannot be passed in the wrong order
- there is no `Map[String, String]` to read out of, and so no lookup to get wrong
- a handler that tries to perform an effect *while routing* is a type error; effects
  belong on the last arrow, after the request has arrived

## Milestones

- [x] **M1 — Typed paths.** No HTTP, no Java interop.
  - [x] `Codec` and the `SegmentCodec` trait, with `wrap` and `refine`
  - [x] `Path[h, t]` and `$$`; `root`, `literal`, `literals`, `param`, `paramWith`
  - [x] `matchPath`, `matchUri`, `link`, `describe`, `pattern`
  - [x] Tests, including the category laws and the round trip between `link` and
        `matchUri`
- [ ] **M2 — HTTP and Router.** `Method`, `Status`, `Body`, `Request` and `Response`;
      `Endpoint` and `Router` with linear matching; a `com.sun.net.httpserver` adapter.
- [ ] **M3 — Middleware and effects.** `Router[ef]` and `mapHandlers`; early responses
      through a `Respond` effect; the capabilities an application needs, tracked in its
      type.
- [ ] **M4 — Analysis.** Trie dispatch built from the route patterns; duplicate and
      shadowed routes detected in Datalog; documentation generated from the route table.
- [ ] **M5 — Generalisation.** Extractors for query parameters, headers and bodies; a
      type-safe client that reuses the URI generator.

[docs/design/routing.md](docs/design/routing.md) has the design, what was given up and
why, and the limitations found so far.

## Development

```
flix check
flix test
```

Requires JDK 21 or later. The Flix version is pinned in [flix.toml](flix.toml).

## License

MIT. See [LICENSE](LICENSE).
