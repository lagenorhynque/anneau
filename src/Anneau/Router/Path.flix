///
/// Typed path patterns.
///
/// A `Path[h, t]` carries a path pattern together with both directions of use it
/// supports: matching a URI so that the captured values reach a handler, and
/// building a URI out of those same values. Both come from one value, so a link
/// can never drift from the pattern it was generated from.
///
pub mod Anneau.Router.Path {
    use Anneau.Router.Codec
    use Anneau.Router.Codec.SegmentCodec
    use Anneau.Router.Path.CodecName.CodecName
    use Anneau.Router.Path.ParamName.ParamName
    use Anneau.Router.Path.Pattern.Pattern
    use Anneau.Router.Path.PatternSegment.{Literal, Param}

    ///
    /// A path pattern that captures zero or more typed values.
    ///
    /// Read `Path[h, t]` as "a path that turns a handler of type `h` into a `t`":
    /// the captured values are the leading arguments of `h`.
    ///
    ///   - `Path[a, a]`                     captures nothing
    ///   - `Path[ToDoId -> a, a]`           captures one `ToDoId`
    ///   - `Path[UserId -> PostId -> a, a]` captures a `UserId`, then a `PostId`
    ///
    /// The technique is Olivier Danvy's functional unparsing: the type index is a
    /// difference type, so composing paths is plain function composition and needs
    /// neither a type-level list nor type-level append. See *Functional Unparsing*,
    /// BRICS RS-98-12, 1998: <https://www.brics.dk/RS/98/12/>.
    ///
    /// Leaving `t` polymorphic is what lets a single value serve both `matchPath`
    /// and `link`, so define a path as a `def` rather than binding it with `let`.
    ///
    /// Values are built with `root`, `literal`, `literals`, `param` and `paramWith`,
    /// and composed with `$$`. Build them no other way: the three fields have to
    /// agree with one another, and reaching for the constructor is exactly what lets
    /// `pattern` drift away from `parse` and `print`.
    ///
    pub enum Path[h, t]({
        pattern = Pattern,
        parse = Parse[h, t],
        print = Print[h, t]
    })

    ///
    /// The erased description of a path: which segments it matches, without the
    /// functions that match or build them.
    ///
    mod Pattern {
        use Anneau.Router.Path.PatternSegment

        ///
        /// The segments of a path pattern, in order.
        ///
        enum Pattern(List[PatternSegment])

        ///
        /// Returns the pattern matching the segments of `p1` followed by those of `p2`.
        ///
        pub def append(p1: Pattern, p2: Pattern): Pattern =
            let Pattern(s1) = p1;
            let Pattern(s2) = p2;
            Pattern(s1 ::: s2)

        ///
        /// Returns the segments of `p`, in order.
        ///
        pub def segments(p: Pattern): List[PatternSegment] =
            let Pattern(segments) = p;
            segments
    }

    ///
    /// The segments of a URI path, in order and without separators.
    ///
    type alias Segments = List[String]

    ///
    /// Consumes a prefix of the given segments and yields both a function applying a
    /// handler of type `h` to the values captured from that prefix, and the segments
    /// left over.
    ///
    /// Returns `None` if the prefix does not match.
    ///
    type alias Parse[h, t] = Segments -> Option[(h -> t, Segments)]

    ///
    /// Builds the segments of a path and hands them to a continuation, taking the
    /// values to interpolate as the leading arguments of `h`.
    ///
    type alias Print[h, t] = (Segments -> t) -> h

    ///
    /// Returns the pattern of `p` as a list of segments.
    ///
    /// This is the erased view of a path: enough to render it, to compare it with
    /// another path, or to analyse a whole route table, but not enough to rebuild
    /// the path itself.
    ///
    pub def pattern(p: Path[h, t]): List[PatternSegment] =
        let Path({pattern | _}) = p;
        Pattern.segments(pattern)

    ///
    /// Returns the parser of `p`.
    ///
    def parse(p: Path[h, t]): Parse[h, t] =
        let Path({parse | _}) = p;
        parse

    ///
    /// Returns the printer of `p`.
    ///
    def print(p: Path[h, t]): Print[h, t] =
        let Path({print | _}) = p;
        print

    ///
    /// The label of a parameter segment. It is used for display only.
    ///
    enum ParamName(String) with Eq, Order, ToString

    ///
    /// The display name of the codec of a parameter segment.
    ///
    enum CodecName(String) with Eq, Order, ToString

    ///
    /// One segment of a path pattern.
    ///
    /// `Literal(s)` matches the segment `s` exactly. `Param(name, codecName)` matches
    /// any segment its codec decodes, and records the label and the codec name so
    /// that the segment can be described.
    ///
    /// The type is deliberately not public: it cannot be named outside this module,
    /// so `pattern` hands out values that travel, compare and print, yet that no
    /// outside signature can mention. That leaves the representation free to change.
    ///
    enum PatternSegment with Eq, Order, ToString {
        case Literal(String)
        case Param(ParamName, CodecName)
    }

    ///
    /// Returns the path matching `p1` followed by `p2`, capturing the values of `p1`
    /// and then those of `p2`.
    ///
    /// ```
    /// def userPostPath(): Path[UserId -> PostId -> a, a] =
    ///     literal("users") $$ param("uid") $$ literal("posts") $$ param("pid")
    /// ```
    ///
    /// Composition is associative and `root` is its identity, alike for the pattern,
    /// for matching and for linking.
    ///
    /// The operator stands in for the path separator, which cannot be used as such:
    /// `/` is not among the characters a Flix operator name may contain.
    ///
    pub def $$(p1: Path[a, b], p2: Path[b, c]): Path[a, c] =
        let Path({pattern = pattern1, parse = parse1, print = print1}) = p1;
        let Path({pattern = pattern2, parse = parse2, print = print2}) = p2;
        Path({
            pattern = Pattern.append(pattern1, pattern2),
            parse = segs -> forM (
                (f, r1) <- parse1(segs);
                (g, r2) <- parse2(r1)
            ) yield (f >> g, r2),
            print = k -> print1(s1 -> print2(s2 -> k(s1 ::: s2)))
        })

    ///
    /// Returns the empty path, which matches no segment and captures nothing.
    ///
    /// It is the identity of `$$`, and both `link(root())` and `describe(root())`
    /// are `"/"`.
    ///
    pub def root(): Path[a, a] =
        Path({
            pattern = Pattern(Nil),
            parse = segs -> Some((identity, segs)),
            print = k -> k(Nil)
        })

    ///
    /// Returns the path of the single literal segment `s`, matched by exact equality.
    ///
    pub def literal(s: String): Path[a, a] =
        Path({
            pattern = Pattern(Literal(s) :: Nil),
            parse = segs -> match segs {
                case x :: rest if x == s => Some((identity, rest))
                case _ => None
            },
            print = k -> k(s :: Nil)
        })

    ///
    /// Returns the path of the literal segments `ss`, in order.
    ///
    /// `literals(Nil)` is `root()`.
    ///
    pub def literals(ss: List[String]): Path[a, a] =
        List.foldLeft((acc, s) -> acc $$ literal(s), root(), ss)

    ///
    /// Returns the path of a single segment captured as a `v`, using the codec that
    /// the `SegmentCodec` instance of `v` provides. The segment matches only if that
    /// codec decodes it.
    ///
    /// `name` is a label used by `describe` and by route documentation only: a
    /// handler receives its captures by position and by type, never by name, so no
    /// parameter lookup can go wrong at run time.
    ///
    pub def param(name: String): Path[v -> a, a] with SegmentCodec[v] =
        paramWith(name, SegmentCodec.codec())

    ///
    /// Returns the path of a single segment captured as a `v`, using the codec `c`.
    ///
    /// Use this where `v` has no `SegmentCodec` instance, or to override the one it
    /// has.
    ///
    pub def paramWith(name: String, c: Codec[v]): Path[v -> a, a] =
        Path({
            pattern = Pattern(Param(ParamName(name), CodecName(Codec.name(c))) :: Nil),
            parse = segs -> match segs {
                case x :: rest => Codec.decode(c, x) |> Option.map(v -> (f -> f(v), rest))
                case Nil => None
            },
            print = k -> (v -> k(Codec.encode(c, v) :: Nil))
        })

    ///
    /// Matches `segs` against `p`, returning a function that applies a handler of
    /// type `h` to the captured values.
    ///
    /// ```
    /// def showToDo(id: ToDoId, req: Request): Response \ Db = ...
    ///
    /// matchPath(toDoPath(), segs) |> Option.map(h -> h(showToDo))
    /// ```
    ///
    /// `Request` and `Response` belong to the HTTP layer, which does not exist yet, and
    /// `Db` stands for whatever capability the handler needs. `matchPath` is indifferent
    /// to all three: `t` is instantiated at whatever the handler returns.
    ///
    /// Returns `None` unless `p` consumes every segment: a path matches the whole
    /// list or not at all.
    ///
    /// Matching is pure. A handler's own effects occur only once it has received the
    /// arguments that follow its captures, never while routing.
    ///
    pub def matchPath(p: Path[h, t], segs: Segments): Option[h -> t] =
        match Path.parse(p, segs) {
            case Some((f, Nil)) => Some(f)
            case _ => None
        }

    ///
    /// Matches the URI path `uri` against `p`, having split it with `split`.
    ///
    /// Leading, trailing and repeated separators are ignored, so `"/todos/42"`,
    /// `"/todos/42/"` and `"//todos//42"` all match alike. The segments are taken to
    /// be percent-decoded already.
    ///
    pub def matchUri(p: Path[h, t], uri: String): Option[h -> t] =
        matchPath(p, split(uri))

    ///
    /// Returns the URI builder of `p`, which takes the values to interpolate in the
    /// order they appear in the path.
    ///
    /// ```
    /// link(toDoPath())              // ToDoId -> String
    /// link(toDoPath())(ToDoId(42))  // "/todos/42"
    /// ```
    ///
    /// It is total, and it reads the same value that `matchPath` reads, so a link can
    /// neither name a route that does not exist nor disagree with its own pattern.
    ///
    /// A capture whose encoding is empty or contains `/` nevertheless yields a URI
    /// that `matchUri` does not match back; see `Anneau.Router.Codec.string`.
    ///
    pub def link(p: Path[h, String]): h =
        Path.print(p, join)

    ///
    /// Renders the pattern of `p` for display, as in `"/todos/{id: ToDoId}"`.
    ///
    /// A parameter appears as `{name: codecName}`, and the empty path as `"/"`.
    ///
    pub def describe(p: Path[h, t]): String =
        pattern(p)
            |> List.map(seg -> match seg {
                case Literal(s) => s
                case Param(ParamName(pn), CodecName(cn)) => "{${pn}: ${cn}}"
            })
            |> join

    ///
    /// Splits the URI path `uri` into segments, discarding the empty ones.
    ///
    /// `"/a/b"`, `"/a/b/"` and `"//a//b"` all yield `"a" :: "b" :: Nil`, while both
    /// `"/"` and `""` yield `Nil`. Percent-decoding is not performed here.
    ///
    pub def split(uri: String): Segments =
        uri
            |> String.split(regex = "/")
            |> List.filter(String.nonEmpty)

    ///
    /// Joins `segs` into an absolute URI path, which always begins with a separator.
    ///
    def join(segs: Segments): String =
        "/${List.join("/", segs)}"
}
