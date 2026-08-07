pub mod Anneau.Router.Path {
    use Anneau.Router.Codec
    use Anneau.Router.Codec.SegmentCodec
    use Anneau.Router.Path.CodecName.CodecName
    use Anneau.Router.Path.ParamName.ParamName
    use Anneau.Router.Path.Pattern.Pattern
    use Anneau.Router.Path.PatternSegment.{Literal, Param}

    pub enum Path[h, t]({
         pattern = Pattern,
         parse = Parse[h, t],
         print = Print[h, t]}
    )

    mod Pattern {
        use Anneau.Router.Path.PatternSegment

        enum Pattern(List[PatternSegment])

        pub def append(p1: Pattern, p2: Pattern): Pattern =
            let Pattern(s1) = p1;
            let Pattern(s2) = p2;
            Pattern(s1 ::: s2)

        pub def segments(p: Pattern): List[PatternSegment] =
            let Pattern(segments) = p;
            segments
    }

    type alias Segments = List[String]
    type alias Parse[h, t] = Segments -> Option[(h -> t, Segments)]
    type alias Print[h, t] = (Segments -> t) -> h

    pub def pattern(p: Path[h, t]): List[PatternSegment] =
        let Path({pattern | _}) = p;
        Pattern.segments(pattern)

    def parse(p: Path[h, t]): Parse[h, t] =
        let Path({parse | _}) = p;
        parse

    def print(p: Path[h, t]): Print[h, t] =
        let Path({print | _}) = p;
        print

    enum ParamName(String) with  Eq, Order, ToString
    enum CodecName(String) with  Eq, Order, ToString

    enum PatternSegment with Eq, Order, ToString {
        case Literal(String)
        case Param(ParamName, CodecName)
    }

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

    pub def root(): Path[a, a] =
        Path({
            pattern = Pattern(Nil),
            parse = segs -> Some((identity, segs)),
            print = k -> k(Nil)
        })

    pub def literal(s: String): Path[a, a] =
        Path({
            pattern = Pattern(Literal(s) :: Nil),
            parse = segs -> match segs {
                case x :: rest if x == s => Some((identity, rest))
                case _ => None
            },
            print = k -> k(s :: Nil)
        })

    pub def literals(ss: List[String]): Path[a, a] =
        List.foldLeft((acc, s) -> acc $$ literal(s), root(), ss)

    pub def param(name: String): Path[v -> a, a] with SegmentCodec[v] =
        paramWith(name, SegmentCodec.codec())

    pub def paramWith(name: String, c: Codec[v]): Path[v -> a, a] =
        Path({
            pattern = Pattern(Param(ParamName(name), CodecName(Codec.name(c))) :: Nil),
            parse = segs -> match segs {
                case x :: rest => Codec.decode(c, x) |> Option.map(v -> (f -> f(v), rest))
                case Nil => None
            },
            print = k -> (v -> k(Codec.encode(c, v) :: Nil))
        })

    pub def matchPath(p: Path[h, t], segs: Segments): Option[h -> t] =
        match Path.parse(p, segs) {
            case Some((f, Nil)) => Some(f)
            case _ => None
        }

    pub def matchUri(p: Path[h, t], uri: String): Option[h -> t] =
        matchPath(p, split(uri))

    pub def link(p: Path[h, String]): h =
        Path.print(p, join)

    pub def describe(p: Path[h, t]): String =
        pattern(p)
            |> List.map(seg -> match seg {
                case Literal(s) => s
                case Param(ParamName(pn), CodecName(cn)) => "{${pn}: ${cn}}"
            })
            |> join

    pub def split(uri: String): Segments =
        uri
            |> String.split(regex = "/")
            |> List.filter(String.nonEmpty)

    def join(segs: Segments): String =
        "/${List.join("/", segs)}"
}
