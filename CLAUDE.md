# CLAUDE.md

## Project

Anneau is an HTTP server library for [Flix](https://flix.dev/), written in Flix.
The current focus is `Anneau.Router.*`: a statically typed routing DSL.

Read `docs/design/routing.md` before writing any code. It is the specification.
If the design document and your intuition disagree, the design document wins —
raise the conflict instead of silently deviating.

## Toolchain

- Flix — the version is pinned in `flix.toml`. Read it from there rather than
  assuming one; Flix moves quickly and behaviour differs between releases.
- JDK 21 or later — 21 is Flix's minimum, and the version CI runs on
- `flix check` — type check (CI runs `java -jar flix.jar check`)
- `flix test` — run `@Test` functions (CI runs `java -jar flix.jar test`)

Run `check` after every edit to a `.flix` file. Do not batch up many changes
before checking; Flix error messages degrade quickly when several unrelated
things are broken at once.

## Working rules

**Do not guess Flix syntax.** Flix is a low-resource language and plausible-looking
code is frequently wrong. Read <https://doc.flix.dev/for-llms.html> first: it is
written for exactly this failure mode and names the constructs whose current form
differs from what an older model tends to produce. Then, before using an unfamiliar
construct:

1. Look it up in <https://doc.flix.dev/> (the book) or
   <https://api.flix.dev/> (standard library API docs).
2. If still unclear, write the smallest possible standalone file that exercises
   the construct, run `check` on it, and only then use it in real code.
3. If a construct turns out to be unsupported, say so explicitly rather than
   working around it with a cast.

**Type signatures first.** Write the full signature of every public definition
before its body, and check that the signatures compile with `???` bodies.
This design relies on the type indices of `Path[h, t]` being exactly right;
getting them wrong is much cheaper to find at signature level.

**No `unchecked_cast`.** If you believe a cast is necessary, stop and explain
why. The whole point of this library is static guarantees.

**Effects.** Keep `Anneau.Router.*` free of `IO` and of Java interop.
Routing must be a pure computation. Java interop belongs in `Anneau.Server.*`.

**Tests.** Every public function in `Anneau.Router.*` gets at least one `@Test`.
Tests must be pure — no server, no sockets.

## Conventions

- Module paths mirror the file layout: `src/Anneau/Router/Path.flix` defines
  `pub mod Anneau.Router.Path`.
- Private by default; export deliberately. That now holds for submodules too:
  since Flix 0.76.0 a submodule without `pub` hides its members from everything
  outside its parent. A submodule callers are meant to reach into therefore gets
  `pub` and its own file, as `Anneau.Router.Codec.SegmentCodec` does; one that is
  genuinely internal, such as `Anneau.Router.Path.Pattern`, stays unexported and
  inline. Beware that a companion — a declaration sharing its name with its
  module — carries its own visibility, so a `pub` trait or enum inside an
  unexported module stays reachable and hides the mistake until someone adds a
  plain `def` beside it.
- Build `Path` values only through the combinators, so that the `pattern` field
  can never drift from `parse`/`print`. Flix does not enforce this: an enum's
  *type* can be made inaccessible outside its module, but its *constructor*
  stays reachable, so this is a convention rather than a guarantee. See §10 of
  the design document.
- Naming: `Path` is a typed path pattern, `Endpoint` is an erased
  method + path + handler triple, `Router` is a collection of endpoints.
  Use `param` (not `capture`) and `link` (not `render`/`toUri`).
  Paths are joined with `$$`, since `/` may not appear in a Flix operator name.
- `///` is a doc comment. It belongs to the definition beneath it and says what
  that definition *is*, addressed to whoever will call it. Put one on every
  public definition, and on a private one whose intent its signature does not
  give away. English, in the sandwiched style the Flix standard library uses:

  ```flix
  ///
  /// Returns the display name of `c`.
  ///
  pub def name(c: Codec[v]): String = ...
  ```

- `//` is an ordinary comment. It says why the surrounding code is as it is,
  addressed to whoever reads that code. Use it where the reason cannot be
  recovered from the code itself — a law being upheld, a case deliberately left
  unhandled, a Flix limitation being worked around — and not to restate what the
  next line plainly does.
- Code blocks in prose — README, design documents — take `//`. Nothing there is
  attached to a definition that anyone can call, and the commentary is for the
  reader of the document rather than for a user of the API. A one-line gloss
  above a signature is not an exception to this, however much it looks like a
  doc comment: the real one lives on the real definition and says more.
- Give a proper noun a link or a gloss where it first appears, in doc comments
  as much as in the documents. Much of what is written here is a record of why
  the design came out as it did, and a name the reader cannot follow up is a
  reason they cannot check. Assume no more background than the Flix book.
- Prose in this repository — README, design documents, doc comments, commit
  messages — is written in English: British, non-Oxford. `-ise` and `-isation`,
  not `-ize` and `-ization`; `behaviour`, `analyse`, `licence` as a noun.
  Identifiers are the exception: they follow the Flix standard library, which
  spells its own `normalize`, `initialize` and `serialize` the American way, so
  a name echoing one of those should match the library rather than the prose
  around it. `LICENSE` likewise keeps its conventional spelling.
- Commit messages in imperative mood, one logical change per commit.

## Formatting

Flix has a `flix format` command, but as of 0.76.0 it is still a stub: it exits
successfully and rewrites nothing, so a clean run is no evidence that a file is
formatted. Until it does something, the layout is kept by reading. Prefer
consistency with what is already here over any outside habit; once the formatter
works, its output wins over everything below.

- Four spaces per level of indentation. No tabs.
- No trailing whitespace, no two consecutive blank lines, and exactly one
  newline at the end of a file.
- No blank line straight after an opening `{` or before a closing `}`.
- `use` declarations first, then `import` declarations, each group sorted by
  codepoint — which is what plain `sort` gives, and which puts an uppercase
  initial before a lowercase one, so `Wrap.FooId` precedes `assertRoundTrips`.
  Sort the names inside `{...}` the same way.
- A record laid out over several lines indents its fields one level and closes
  with `})` on a line of its own:

  ```flix
  pub enum Codec[v]({
      name = String,
      decode = String -> Option[v],
      encode = v -> String
  })
  ```

- Do not align the `=>` of `match` arms, or anything else, with extra spaces.
  Alignment inside a doc comment — a table of type indices, a trailing `//` on
  an example — is the exception, since it is prose being laid out rather than
  code.

## Out of scope for now

Query parameters, headers, request bodies, middleware, and the HTTP server
adapter are later milestones. Do not add them opportunistically.
