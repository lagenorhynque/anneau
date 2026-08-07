mod Anneau.Router.TestPath {
    use Anneau.Router.Codec
    use Anneau.Router.Codec.SegmentCodec
    use Anneau.Router.Path
    use Anneau.Router.Path.{$$, literal, param}
    use Anneau.Router.TestPath.ToDoId.ToDoId

    enum ToDoId(Int32) with Eq, ToString
    instance SegmentCodec[ToDoId] {
        pub def codec(): Codec[ToDoId] =
            Codec.int32() |> Codec.wrap(
                "ToDoId",
                decode = ToDoId,
                encode = id -> let ToDoId(v) = id; v
            )
    }

    def todoPath(): Path[ToDoId -> a, a] =
        literal("todos") $$ param("id")

    def userPostPath(): Path[Int32 -> Int32 -> a, a] =
        literal("users") $$ param("uid") $$ literal("posts") $$ param("pid")

    mod Parsing {
        use Anneau.Router.Path
        use Anneau.Router.Path.root
        use Anneau.Router.TestPath.{capturedPair, capturedValue, todoPath, userPostPath}
        use Anneau.Router.TestPath.ToDoId.ToDoId
        use Assert.{assertEq, assertNone}

        @Test
        def testCaptureOrder(): Unit \ Assert =
            let matched = Path.matchPath(userPostPath(), List#{"users", "1", "posts", "2"});
            assertEq(expected = Some((1, 2)), matched |> capturedPair)

        @Test
        def testRoot(): Unit \ Assert =
            assertEq(expected = Some("r"), Path.matchPath(root(), Nil) |> Option.map(h -> h("r")))

        @Test
        def testRejectsLiteralMismatch(): Unit \ Assert =
            assertNone(Path.matchPath(todoPath(), List#{"todo", "42"}))

        @Test
        def testRejectsUndecodableParam(): Unit \ Assert =
            assertNone(Path.matchPath(todoPath(), List#{"todos", "foo"}))

        @Test
        def testRequiresFullConsumption(): Unit \ Assert =
            // too many
            assertNone(Path.matchPath(todoPath(), List#{"todos", "42", "x"}));
            // too few
            assertNone(Path.matchPath(todoPath(), List#{"todos"}))

        @Test
        def testSplit(): Unit \ Assert =
            assertEq(expected = Nil, Path.split("/"));
            assertEq(expected = Nil, Path.split(""));
            assertEq(expected = Nil, Path.split("//"));
            assertEq(expected = List#{"a", "b", "c"}, Path.split("/a/b/c"));
            assertEq(expected = List#{"a", "b"}, Path.split("/a/b/"));
            assertEq(expected = List#{"a", "b"}, Path.split("/a//b"));
            assertEq(expected = List#{"a", "b"}, Path.split("a/b"))

        @Test
        def testUriNormalization(): Unit \ Assert =
            assertEq(
                expected = Some(ToDoId(42)),
                Path.matchUri(todoPath(), "/todos/42/") |> capturedValue
            );
            assertEq(
                expected = Some(ToDoId(42)),
                Path.matchUri(todoPath(), "//todos//42") |> capturedValue
            );
            assertEq(expected = Some("r"), Path.matchUri(root(), "/") |> Option.map(h -> h("r")))
    }

    mod Printing {
        use Anneau.Router.Path
        use Anneau.Router.Path.root
        use Anneau.Router.TestPath.{todoPath, userPostPath}
        use Anneau.Router.TestPath.ToDoId.ToDoId
        use Assert.assertEq

        @Test
        def testLink(): Unit \ Assert =
            assertEq(expected = "/todos/42", Path.link(todoPath())(ToDoId(42)))

        @Test
        def testLinkOrder(): Unit \ Assert =
            assertEq(expected = "/users/1/posts/2", Path.link(userPostPath())(1)(2))

        @Test
        def testLinkLiterals(): Unit \ Assert =
            assertEq(expected = "/api/users", Path.link(Path.literals(List#{"api", "users"})));
            assertEq(expected = "/", Path.link(Path.literals(Nil)))

        @Test
        def testLinkRoot(): Unit \ Assert =
            assertEq(expected = "/", Path.link(root()))
    }

    mod Pattern {
        use Anneau.Router.Codec
        use Anneau.Router.Path
        use Anneau.Router.Path.{$$, literal, root}
        use Anneau.Router.TestPath.{todoPath, userPostPath}
        use Assert.assertEq

        @Test
        def testDescribe(): Unit \ Assert =
            assertEq(expected = "/todos/{id: ToDoId}", Path.describe(todoPath()));
            assertEq(
                expected = "/users/{uid: Int32}/posts/{pid: Int32}",
                Path.describe(userPostPath())
            )

        @Test
        def testDescribeRoot(): Unit \ Assert =
            assertEq(expected = "/", Path.describe(root()))

        @Test
        def testDescribeUsesCodecName(): Unit \ Assert =
            let p = literal("todos") $$ Path.paramWith("id", Codec.int32());
            assertEq(expected = "/todos/{id: Int32}", Path.describe(p))

        @Test
        def testPatternLength(): Unit \ Assert =
            assertEq(expected = 0, List.length(Path.pattern(root())));
            assertEq(expected = 2, List.length(Path.pattern(todoPath())));
            assertEq(expected = 4, List.length(Path.pattern(userPostPath())))
    }

    mod Handlers {
        use Anneau.Router.Path
        use Anneau.Router.Path.{$$, literal, param}
        use Anneau.Router.TestPath.userPostPath
        use Assert.assertEq

        def multiParamHandler(uid: Int32, pid: Int32, req: String): String =
            "${req}:${uid}:${pid}"

        @Test
        def testMultiParamHandler(): Unit \ Assert =
            let matched = Path.matchPath(userPostPath(), List#{"users", "1", "posts", "2"})
                |> Option.map(h -> h(multiParamHandler));
            assertEq(expected = Some("r:1:2"), matched |> Option.map(h -> h("r")))

        def echoHandler(n: Int32, req: String): String \ Logger =
            Logger.info("n=${n}");
            "${req}/${n}"

        @Test
        def testEffectfulHandler(): Unit \ {Assert, Logger} =
            let matched = Path.matchPath(literal("todos") $$ param("id"), List#{"todos", "42"})
                |> Option.map(h -> h(echoHandler));
            assertEq(expected = Some("r/42"), matched |> Option.map(h -> h("r")))
    }

    mod Laws {
        use Anneau.Router.Codec
        use Anneau.Router.Path
        use Anneau.Router.Path.{$$, literal, param, root}
        use Anneau.Router.TestPath.{capturedPair, capturedValue, todoPath}
        use Anneau.Router.TestPath.ToDoId.ToDoId
        use Assert.{assertEq, assertNone}

        @Test
        def testCategoryIdentity(): Unit \ Assert =
            let id = ToDoId(42);
            // describe
            assertEq(expected = Path.describe(todoPath()), Path.describe(root() $$ todoPath()));
            assertEq(expected = Path.describe(todoPath()), Path.describe(todoPath() $$ root()));
            // link
            assertEq(expected = Path.link(todoPath())(id), Path.link(root() $$ todoPath())(id));
            assertEq(expected = Path.link(todoPath())(id), Path.link(todoPath() $$ root())(id));
            let segments = List#{"todos", "42"};
            // match
            assertEq(
                expected = Path.matchPath(todoPath(), segments) |> capturedValue,
                Path.matchPath(root() $$ todoPath(), segments) |> capturedValue
            );
            assertEq(
                expected = Path.matchPath(todoPath(), segments) |> capturedValue,
                Path.matchPath(todoPath() $$ root(), segments) |> capturedValue
            )

        def leftAssoc(): Path[Int32 -> Int32 -> a, a] =
            (param("x") $$ literal("m")) $$ param("y")
        def rightAssoc(): Path[Int32 -> Int32 -> a, a] =
            param("x") $$ (literal("m") $$ param("y"))

        @Test
        def testCategoryAssociativity(): Unit \ Assert =
            assertEq(expected = Path.describe(leftAssoc()), Path.describe(rightAssoc()));
            assertEq(expected = Path.link(leftAssoc())(1)(2), Path.link(rightAssoc())(1)(2));
            let segments = List#{"1", "m", "2"};
            assertEq(
                expected = Path.matchPath(leftAssoc(), segments) |> capturedPair,
                Path.matchPath(rightAssoc(), segments) |> capturedPair
            )

        @Test
        def testUriRoundTrip(): Unit \ Assert =
            let id = ToDoId(42);
            let uri = Path.link(todoPath())(id);
            assertEq(expected = Some(id), Path.matchUri(todoPath(), uri) |> capturedValue)

        def stringParamPath(): Path[String -> a, a] =
            literal("q") $$ Path.paramWith("s", Codec.string())

        @Test
        def testRoundTripFailsOnEmptyEncoding(): Unit \ Assert =
            assertEq(expected = "/q/", Path.link(stringParamPath())(""));
            assertNone(Path.matchUri(stringParamPath(), Path.link(stringParamPath())("")))

        @Test
        def testRoundTripFailsOnSeparator(): Unit \ Assert =
            assertEq(expected = "/q/a/b", Path.link(stringParamPath())("a/b"));
            assertNone(Path.matchUri(stringParamPath(), Path.link(stringParamPath())("a/b")))
    }

    def capturedValue(matched: Option[(a -> a) -> a]): Option[a] =
        Option.map(h -> h(identity), matched)

    def capturedPair(matched: Option[(a -> b -> (a, b)) -> (a, b)]): Option[(a, b)] =
        Option.map(h -> h(x -> y -> (x, y)), matched)
}
