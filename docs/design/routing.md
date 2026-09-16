# Anneau: typed routing design notes

Scope: `Anneau.Router.*`
Assumes: Flix 0.75.3

This document is the specification. Where it and the implementation disagree, decide
explicitly which one to change. Section 6 records the Milestone 0 language spikes and
what they actually returned; section 10 records the constraints that only became visible
once the code existed; section 11 records where the road might go afterwards, and which
of today's decisions those directions bear on.

## 1. Goals and non-goals

**Goal**: make the type checker guarantee that a path pattern and its handler agree,
and derive reverse routing (URI generation) from the very same value, as a total
function.

**Non-goals, given up deliberately**:

- A type-level DSL in the style of [Servant](https://www.servant.dev/), the Haskell
  library that describes an API as a type. Flix has no type-level strings, and the type
  of an instance is limited to a type constructor applied to zero or more distinct type
  variables, so there is no way to write the type-level computation that Servant's
  `HasServer` performs.
- An initial encoding by GADTs (generalised algebraic data types). Flix has neither
  existential types nor GADTs, so the DSL is a **final encoding: a record of
  functions**.
- Static detection of duplicate or shadowed routes. Without type-level strings this
  cannot happen at compile time, so route descriptions (`List[PatternSegment]`) are
  handed instead to an analysis written in
  [Flix's first-class Datalog](https://doc.flix.dev/fixpoints.html), run as a test
  (Milestone 4).

## 2. What is guaranteed statically

| Guarantee | Mechanism | Status |
|---|---|---|
| The number and types of parameters match the handler's signature | the type indices of `Path[h, t]` | implemented |
| No reference to a parameter that does not exist | parameters arrive by position and type, never through a `Map[String, String]` | implemented |
| Reverse routing is total | `link` has type `Path[h, String] -> h` | implemented |
| Routing itself performs no effect | `matchPath` is a pure function | implemented |
| A handler's effects happen only after the request arrives | the type checker demands that the intermediate arrows be pure | measured (§6 S2) |
| The capabilities an application requires, gathered in one place | the `ef` of `Router[ef]` | Milestone 3 |

What the types cannot hold on to is collected in section 10.

## 3. Core types

The technique is the same difference-typing that Olivier Danvy uses for functional
unparsing ([*Functional Unparsing*, BRICS RS-98-12,
1998](https://www.brics.dk/RS/98/12/)).
Read `Path[h, t]` as "a route that turns a handler of type `h` into a `t`". With an
`Int32` and a `String` parameter, `h = Int32 -> String -> t`.

```flix
pub enum Path[h, t]({
     pattern = Pattern,
     parse = Parse[h, t],
     print = Print[h, t]}
)

type alias Segments = List[String]
type alias Parse[h, t] = Segments -> Option[(h -> t, Segments)]
type alias Print[h, t] = (Segments -> t) -> h
```

The type is the specification:

- `Path[a, a]` — captures nothing
- `Path[ToDoId -> a, a]` — captures one `ToDoId`
- `Path[UserId -> PostId -> a, a]` — captures two

The pattern itself is kept as a value, a `Pattern` wrapping a `List[PatternSegment]`.

```flix
enum PatternSegment with Eq, Order, ToString {
    case Literal(String)
    case Param(ParamName, CodecName)
}

enum ParamName(String) with Eq, Order, ToString
enum CodecName(String) with Eq, Order, ToString
```

`ParamName` and `CodecName` are separate types so that the shape of `describe`'s output
(`{id: ToDoId}`) — a label paired with a type name — is visible in the types. Neither
can be named from outside `Anneau.Router.Path` (§10).

### Composition

No type-level list and no type-level append are needed: composing routes is plain
function composition.

```flix
// Joins Path[a, b] and Path[b, c] into Path[a, c]
pub def $$(p1: Path[a, b], p2: Path[b, c]): Path[a, c]
```

- `parse`: `(a -> b) >> (b -> c)` gives `a -> c`
- `print`: `k -> print1(s1 -> print2(s2 -> k(s1 ::: s2)))`
- `pattern`: list concatenation

`/` cannot appear in a Flix operator name (§6 S1), so the separator is written with the
vertical pair `$$`, chosen over the alternatives because it will not be misread as `>>`
(function composition). That composition is associative and that `root()` is its
identity are checked in `TestPath.Laws`.

### Primitives

```flix
pub def root(): Path[a, a]                                    // empty
pub def literal(s: String): Path[a, a]
pub def literals(ss: List[String]): Path[a, a]
pub def param(name: String): Path[v -> a, a] with SegmentCodec[v]
pub def paramWith(name: String, c: Codec[v]): Path[v -> a, a]
```

The `name` of a `param` is a label for documentation and for display only; the handler
receives its parameters by position and type. That is the decisive difference from the
`Map[String, String]` approach.

### Consuming and producing

```flix
// Some only if the segment list is consumed entirely
pub def matchPath(p: Path[h, t], segs: Segments): Option[h -> t]

// splits the URI, then matchPath
pub def matchUri(p: Path[h, t], uri: String): Option[h -> t]

// Reverse routing. link(toDoPath()) : ToDoId -> String
pub def link(p: Path[h, String]): h

// A display string such as "/todos/{id: ToDoId}"
pub def describe(p: Path[h, t]): String

// The erased representation, for analysis and documentation generation
pub def pattern(p: Path[h, t]): List[PatternSegment]

// Splits a URI into segments, discarding empty ones
pub def split(uri: String): Segments
```

That `matchPath` and `link` come out of one and the same `Path` value is what keeps a
pattern and the URIs generated from it in step. **A path must therefore be defined as a
`def`**, since `t` has to be instantiated both at `Handler[ef]` and at `String`.

### Segment codecs

```flix
pub enum Codec[v]({
    name = String,
    decode = String -> Option[v],
    encode = v -> String
})

pub trait SegmentCodec[v] {
    pub def codec(): Codec[v]
}
```

`name` is a display label used only by `describe`; it carries no semantics. Instances
are provided for `String`, `Int32`, `Int64` and `Bool` — an instance for a nullary type
constructor such as `Int32` is permitted.

Users are encouraged to give each identifier its own single-case enum and a
`SegmentCodec` instance, which turns a swap between two parameters of the same
underlying type (`UserId` and `PostId` in the wrong order) into a type error. Two
combinators exist for building those codecs.

```flix
// lift along a total conversion
pub def wrap(name: String, wrapDecode: {decode = a -> b}, wrapEncode: {encode = b -> a}, c: Codec[a]): Codec[b]

// lift along a partial conversion, for values that need validating
pub def refine(name: String, wrapDecode: {decode = a -> Option[b]}, wrapEncode: {encode = b -> a}, c: Codec[a]): Codec[b]
```

### Example

```flix
def toDosPath(): Path[a, a] =
    literal("todos")

def toDoPath(): Path[ToDoId -> a, a] =
    toDosPath() $$ param("id")

def completedPath(): Path[ToDoId -> a, a] =
    toDoPath() $$ literal("completed")

// describe(toDoPath())        == "/todos/{id: ToDoId}"
// link(toDoPath())(ToDoId(3)) == "/todos/3"
```

## 4. How effects are handled (a convention)

**Effects appear on the last arrow only.** A handler has type

```
ToDoId -> Request -> Response \ ef
```

where the `ToDoId ->` part is pure. Because of this:

- `Path` needs no effect variable
- every partial application inside `f(handler)` stays pure
- a handler that performs an effect *while routing* (say `id -> effectfulThing(id)`) is
  a type error

The last point was measured in §6 S2: passing a handler whose intermediate arrow
carries an effect to the result of `matchPath` fails with
`Mismatched effect(s): expected 'Pure', but got 'Logger'`.

## 5. Module layout

```
src/
  Anneau.flix                     pub mod Anneau {}
  Anneau/
    Router.flix                   Endpoint, Router                        (M3)
    Router/
      Codec.flix                  Codec                                   (M1) implemented
      Codec/
        SegmentCodec.flix         SegmentCodec trait and its instances    (M1) implemented
      Path.flix                   PatternSegment, Path, $$, link          (M1) implemented
      Analysis.flix               route table analysis in Datalog         (M4)
    Http.flix                     Method, Status, Body, Request, Response (M2)
    Middleware.flix               Respond, mapHandlers                    (M3)
    Server/
      JavaHttp.flix               com.sun.net.httpserver adapter          (M2)
test/
  Anneau/
    Router/
      TestCodec.flix              implemented
      Codec/
        TestSegmentCodec.flix     implemented
      TestPath.flix               implemented
```

The server lives in `Anneau.Server.*`, so that `Anneau.Router` stays a pure module with
no dependency on Java interop.

A submodule that callers are meant to reach into gets its own file and is declared
`pub`, as `SegmentCodec` is: since Flix 0.76.0 a submodule without `pub` genuinely hides
its members from everything outside its parent (§10), and a `pub` one has to live in the
file its path names. A submodule that is genuinely internal, such as `Pattern`, stays
unexported and inline. The tests mirror the same layout.

## 6. Milestone 0: results of the language spikes

Measured on Flix 0.75.3.

### S1. Symbolic operators — confirmed

`/` may not appear in an operator name, so `p / q` cannot be written. `$$` can be
defined, and chains without parentheses:
`literal("users") $$ param("uid") $$ literal("posts") $$ param("pid")`. Since
composition is associative, the grouping does not affect the meaning.

### S2. Purity of the outer arrows of a curried handler — confirmed. The important one

A handler that carries its effect on the last arrow can be passed as it is. A handler
that carries an effect on an intermediate arrow is a type error. The convention in §4
therefore holds, and `Path` does not need an effect variable.

### S3. Polymorphism of `Path` — confirmed

One `def` can be instantiated both at `t := String` (for `link`) and at `t :=` whatever
a handler returns (for `matchPath`). Being a `def` is essential: bound with `let` it is
monomorphised and only one of the two uses survives.

### S4. The default effect of a function type inside a `type alias` — confirmed

The `h -> t` in `type alias Parse[h, t] = Segments -> Option[(h -> t, Segments)]` is
treated as a pure function; no effect variable is introduced implicitly. The aliases are
used as written.

### S5. Non-resumable operations — confirmed

`Void` is the return type of an operation that cannot resume. It is uninhabited, so the
continuation a handler receives for such an operation can never be invoked; see
[Effects and Handlers](https://doc.flix.dev/effects-and-handlers.html). The standard
library relies on this in [`Abort`](https://api.flix.dev/Abort.html), and likewise in
`OutOfBounds`, `KeyNotFound` and `Sys.Exit`.

An effect carrying a `Response` rather than a message behaves the same way, and its
handler narrows the effect purely, with no `IO`:

```flix
eff Respond {
    def respond(res: Response): Void
}

def runWithResponse(f: Unit -> Response \ ef): Response \ (ef - Respond) =
    run {
        f()
    } with handler Respond {
        def respond(res, _k) = res
    }
```

Measured: a `respond` raised inside a nested call returns that response, and the
statements following it never run. Because `Void` is uninhabited, `Respond.respond` also
type-checks in expression position at any type, so a failing branch needs no filler
value.

The standard library's `Abort` carries a `RichString`, so Anneau needs an effect of its
own rather than reusing it. What is worth reusing is the shape of
`Abort.handleWithResult`, whose `(ef - Abort)` is the narrowing Milestone 3 needs.

The name is deliberately not `Abort`. Two effects of that name, one carrying a message
and one carrying a `Response`, would be confusing at every `use` site even though they
never appear in the same context. `Respond` also describes the wider job:
short-circuiting is not only for errors, and a 304 or a redirect leaves early for a
reason that is not a failure at all.

## 7. Testing strategy

Because `t` can be instantiated freely, a captured value can be read straight back out:
take `h := v -> v` and `t := v`.

```flix
def capturedValue(matched: Option[(a -> a) -> a]): Option[a] =
    Option.map(h -> h(identity), matched)

@Test
def testParamCapturesValue(): Unit \ Assert =
    let p = literal("todos") $$ param("id");
    assertEq(expected = Some(42), Path.matchPath(p, List#{"todos", "42"}) |> capturedValue)
```

Cases covered:

- a literal that matches, and one that does not
- a parameter that decodes, and one that does not (`"abc"` for `param("id")`)
- too many and too few segments (leftovers give `None`)
- the round trip between `link` and `matchUri`
- the round trips that break (a `String` parameter that is empty or contains `/`)
- the output of `describe` and the length of `pattern`
- the category laws (`root()` is the identity, `$$` is associative)
- handlers with several parameters, and handlers with effects
- the empty path and trailing slashes (settled as a specification in §9)

## 8. Milestones

1. **M1** `Codec`, `SegmentCodec`, `Path`, `$$`, `link`, `matchPath`, `describe`, and
   their tests. No HTTP and no Java interop. **Done.**
2. **M2** `Http` (`Method`, `Status`, `Body`, `Request`, `Response`), linear matching in
   `Endpoint` and `Router`, and an adapter for
   [`com.sun.net.httpserver`](https://docs.oracle.com/en/java/javase/21/docs/api/jdk.httpserver/com/sun/net/httpserver/package-summary.html),
   the small HTTP server that ships with the JDK. Register a single `"/"` context and do
   the matching ourselves.
3. **M3** Middleware over `Router[ef]` (`mapHandlers`), early responses through a
   `Respond` effect, and tracking of capabilities in the type.
4. **M4** Fast dispatch by building a trie from `pattern`, detection of duplicate and
   shadowed routes in Datalog, and documentation generated from the route table.
5. **M5** Generalising the extractors to query parameters, headers and bodies, and a
   type-safe client that reuses `print`.

## 9. Settled

- **Trailing slashes**: `split` discards empty segments, so `/todos`, `/todos/` and
  `//todos//` are all the same path. Normalisation happens once, on the way in through
  `matchUri`.
- **The empty path**: both `link(root())` and `describe(root())` are `"/"`.

## 10. Open questions and known limitations

### Hiding the representation does not fully work

The intent is to seal the constructor of `Path` so that values can only be built through
the combinators. A `Path` whose `pattern` disagrees with its `parse` and `print` would
let the route table analysis of M4 draw conclusions about something that never runs.

Measured on Flix 0.75.3, the sealing **applies to references to the type only**.

| Attempted from an outside module | Result |
|---|---|
| naming the types `PatternSegment` / `Pattern` in a signature | `Resolution Error [E0459] inaccessible enum` |
| forging one with `Path({pattern = Pattern(...), parse = ..., print = ...})` | accepted |
| taking one apart with `let Path({pattern \| _}) = p` | accepted |
| taking one apart in a `match` without naming the type, `case Literal(s) => ...` | accepted |

In other words, the constructors of an enum remain reachable even where the enum type
itself cannot be named from outside. "Build them only through the combinators" is
therefore **a convention, not a guarantee**. What is guaranteed is that `pattern` cannot
be named from outside, which is enough to keep the representation free to change later.

Whether this is intended in Flix or an oversight has not been established. Whether to
work around it — wrapping constructors in functions, mixing an opaque function type into
the fields — is a decision for the point at which M4 starts.

### Others

- Which layer handles percent-encoding. Having `Path` receive already-decoded segments
  is the natural reading.
- Whether a catch-all segment (`rest(name): Path[List[String] -> a, a]`) belongs in M2.
- `group`, for gathering several routes. A prefix that captures nothing is already
  expressible as `Path[a, a]`; grouping under a prefix that captures needs thought.
- The `String` codec breaks its round trip for values that are empty or that contain
  `/`, and the types cannot prevent it, so `link` can produce a URI that `matchUri` will
  not match back.

## 11. Directions beyond Milestone 5

None of the following is committed to, and none of it belongs in a first release. It is
written down because three of the four constrain decisions taken much earlier, and
keeping a door open costs far less than reopening it.

### Splitting the repository into several packages

`Anneau.Router` is free of `IO` and of Java interop, and `Anneau.Server.*` is where the
interop is confined (§5). That separation is what would make it possible to publish the
router on its own, for someone who wants typed paths and reverse routing but not a
server.

So treat the boundary as load-bearing rather than merely tidy. A single `IO` leaking
into `Anneau.Router` would cost nothing on the day and forecloses this afterwards.

### Adapters for other servers

`com.sun.net.httpserver` is the adapter of Milestone 2 because it needs no dependency,
not because it is the one worth having. Jetty and Netty are the obvious next ones.

The consequence for Milestone 2 is to write it as *an* adapter rather than as *the*
server. Whatever `Anneau.Server.JavaHttp` turns out to need from a `Router` — match a
method and a URI, hand back a response — is the interface a second adapter would
implement, and it is worth naming while there is still only one, when it is still
obvious which parts are `com.sun.net.httpserver` and which parts are Anneau.

### Generating an OpenAPI document

Milestone 4 already generates documentation from the route table, and OpenAPI is that
same generation with the output format fixed. The gap is not in the generator but in
what the route table knows: paths, methods and codec names carry a route listing, while
an OpenAPI document also wants status codes and the schemas of requests and responses.

That makes it a constraint on Milestones 2 and 5, not on Milestone 4. If `Endpoint`
erases everything but the handler, the material is gone before the analysis ever runs.
Erase as little as the type system forces, and no more.

### GraphQL and gRPC servers

Both would sit on the effects and middleware of Milestone 3 rather than on the routing
of Milestone 1: a single endpoint, with the dispatch happening inside it. The question
they raise is whether `Router[ef]` and the server adapters are reusable by a protocol
that does not route by path — worth asking of the Milestone 3 design as it is written,
and not worth answering now.
