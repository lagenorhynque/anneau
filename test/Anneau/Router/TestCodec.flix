mod Anneau.Router.TestCodec {
    use Anneau.Router.Codec
    use Assert.assertEq

    mod Name {
        use Anneau.Router.Codec
        use Assert.assertEq

        @Test
        def testName(): Unit \ Assert =
            assertEq(expected = "String", Codec.name(Codec.string()));
            assertEq(expected = "Int32", Codec.name(Codec.int32()));
            assertEq(expected = "Int64", Codec.name(Codec.int64()));
            assertEq(expected = "Bool", Codec.name(Codec.bool()))
    }

    mod DecodeAndEncode {
        use Anneau.Router.Codec
        use Anneau.Router.TestCodec.assertRoundTrips
        use Assert.assertEq

        @Test
        def testString(): Unit \ Assert =
            let c = Codec.string();
            assertEq(expected = Some("foo"), Codec.decode(c, "foo"));
            assertEq(expected = "foo", Codec.encode(c, "foo"));
            assertRoundTrips(c, List#{"", "foo", "a/b", "a b", "あいう"})

        @Test
        def testInt32(): Unit \ Assert =
            let c = Codec.int32();
            assertEq(expected = Some(42), Codec.decode(c, "42"));
            assertEq(expected = Some(42i32), Codec.decode(c, "42"));
            assertEq(expected = None, Codec.decode(c, "42i32"));
            assertEq(expected = Some(7), Codec.decode(c, "007"));
            // Int32.minValue() - 1
            assertEq(expected = None, Codec.decode(c, "-2147483649"));
            // Int32.maxValue() + 1
            assertEq(expected = None, Codec.decode(c, "2147483648"));
            assertEq(expected = None, Codec.decode(c, "foo"));
            assertEq(expected = "42", Codec.encode(c, 42));
            assertEq(expected = "42", Codec.encode(c, 42i32));
            assertRoundTrips(c, List#{Int32.minValue(), -1, 0, 1, Int32.maxValue()})

        @Test
        def testInt64(): Unit \ Assert =
            let c = Codec.int64();
            assertEq(expected = Some(42i64), Codec.decode(c, "42"));
            assertEq(expected = None, Codec.decode(c, "42i64"));
            assertEq(expected = Some(7i64), Codec.decode(c, "007"));
            // Int64.minValue() - 1
            assertEq(expected = None, Codec.decode(c, "-9223372036854775809"));
            // Int64.maxValue() + 1
            assertEq(expected = None, Codec.decode(c, "9223372036854775808"));
            assertEq(expected = None, Codec.decode(c, "foo"));
            assertEq(expected = "42", Codec.encode(c, 42i64));
            assertRoundTrips(c, List#{Int64.minValue(), -1i64, 0i64, 1i64, Int64.maxValue()})

        @Test
        def testBool(): Unit \ Assert =
            let c = Codec.bool();
            assertEq(expected = Some(true), Codec.decode(c, "true"));
            assertEq(expected = None, Codec.decode(c, "True"));
            assertEq(expected = None, Codec.decode(c, "1"));
            assertEq(expected = Some(false), Codec.decode(c, "false"));
            assertEq(expected = None, Codec.decode(c, "False"));
            assertEq(expected = None, Codec.decode(c, "0"));
            assertEq(expected = "true", Codec.encode(c, true));
            assertEq(expected = "false", Codec.encode(c, false));
            assertRoundTrips(c, List#{true, false})
    }

    mod Wrap {
        use Anneau.Router.Codec
        use Anneau.Router.TestCodec.Wrap.FooId.FooId
        use Anneau.Router.TestCodec.Wrap.FooIdWrapper.FooIdWrapper
        use Anneau.Router.TestCodec.assertRoundTrips
        use Assert.assertEq

        enum FooId(Int32) with Eq, ToString

        @Test
        def testWrapCustomType(): Unit \ Assert =
            let c = Codec.int32() |> Codec.wrap(
                "FooId",
                decode = FooId,
                encode = id -> let FooId(v) = id; v
            );
            assertEq(expected = "FooId", Codec.name(c));
            assertEq(expected = Some(FooId(42)), Codec.decode(c, "42"));
            assertEq(expected = None, Codec.decode(c, "foo"));
            assertEq(expected = "42", Codec.encode(c, FooId(42)));
            assertRoundTrips(c, List.map(FooId, List#{-1, 0, 1}))

        @Test
        def testIdentity(): Unit \ Assert =
            let c = Codec.int32() |> Codec.wrap(
                "Int32",
                decode = identity,
                encode = identity
            );
            assertEq(expected = Codec.name(Codec.int32()), Codec.name(c));
            assertEq(expected = Codec.decode(Codec.int32(), "42"), Codec.decode(c, "42"));
            assertEq(expected = Codec.encode(Codec.int32(), 42), Codec.encode(c, 42))

        enum FooIdWrapper(FooId) with Eq, ToString

        @Test
        def testComposition(): Unit \ Assert =
            let fooIdC = {
                name = "FooId",
                decode = FooId,
                encode = id -> let FooId(v) = id; v
            };
            let fooIdWrapperC = {
                name = "FooIdWrapper",
                decode = FooIdWrapper,
                encode = id -> let FooIdWrapper(v) = id; v
            };
            let c1 = Codec.int32()
                |> Codec.wrap(fooIdC#name, decode = fooIdC#decode, encode = fooIdC#encode)
                |> Codec.wrap(fooIdWrapperC#name, decode = fooIdWrapperC#decode, encode = fooIdWrapperC#encode);
            let c2 = Codec.int32()
                |> Codec.wrap(
                    fooIdWrapperC#name,
                    decode = fooIdC#decode >> fooIdWrapperC#decode,
                    encode = fooIdWrapperC#encode >> fooIdC#encode
                );
            // c |> wrap(n1, f1, g1) |> wrap(n2, f2, g2) == wrap(n2, f1 >> f2, g2 >> g1, c)
            assertEq(expected = Codec.name(c1), Codec.name(c2));
            assertEq(expected = Codec.decode(c1, "42"), Codec.decode(c2, "42"));
            assertEq(
                expected = Codec.encode(c1, FooIdWrapper(FooId(42))),
                Codec.encode(c2, FooIdWrapper(FooId(42)))
            )
    }

    mod Refine {
        use Anneau.Router.Codec
        use Anneau.Router.TestCodec.Refine.BarId.BarId
        use Anneau.Router.TestCodec.assertRoundTrips
        use Assert.assertEq

        enum BarId(Int32) with Eq, ToString

        @Test
        def testRefineCustomType(): Unit \ Assert =
            let c = Codec.int32() |> Codec.refine(
                "BarId",
                decode = v -> if (v > 0) Some(BarId(v)) else None,
                encode = id -> let BarId(v) = id; v
            );
            assertEq(expected = "BarId", Codec.name(c));
            assertEq(expected = Some(BarId(42)), Codec.decode(c, "42"));
            assertEq(expected = None, Codec.decode(c, "0"));
            assertEq(expected = "42", Codec.encode(c, BarId(42)));
            assertRoundTrips(c, List.map(BarId, List#{1, 2, 3}))

        @Test
        def testIdentity(): Unit \ Assert =
            let c = Codec.int32() |> Codec.refine(
                "Int32",
                decode = Some,
                encode = identity
            );
            assertEq(expected = Codec.name(Codec.int32()), Codec.name(c));
            assertEq(expected = Codec.decode(Codec.int32(), "42"), Codec.decode(c, "42"));
            assertEq(expected = Codec.encode(Codec.int32(), 42), Codec.encode(c, 42))
    }

    mod SegmentCodec {
        use Anneau.Router.Codec
        use Anneau.Router.Codec.SegmentCodec
        use Anneau.Router.TestCodec.SegmentCodec.BazId.BazId
        use Assert.assertEq

        @Test
        def testDefaultName(): Unit \ Assert =
            let stringC: Codec[String] = SegmentCodec.codec();
            assertEq(expected = "String", Codec.name(stringC));
            let int32C: Codec[Int32] = SegmentCodec.codec();
            assertEq(expected = "Int32", Codec.name(int32C));
            let int64C: Codec[Int64] = SegmentCodec.codec();
            assertEq(expected = "Int64", Codec.name(int64C));
            let boolC: Codec[Bool] = SegmentCodec.codec();
            assertEq(expected = "Bool", Codec.name(boolC))

        enum BazId(Int32) with Eq, ToString
        instance SegmentCodec[BazId] {
            pub def codec(): Codec[BazId] =
                Codec.int32() |> Codec.wrap(
                    "BazId",
                    decode = BazId,
                    encode = id -> let BazId(v) = id; v
                )
        }

        @Test
        def testCustomSegmentCodec(): Unit \ Assert =
            let c: Codec[BazId] = SegmentCodec.codec();
            assertEq(expected = "BazId", Codec.name(c));
            assertEq(expected = Some(BazId(42)), Codec.decode(c, "42"));
            assertEq(expected = "42", Codec.encode(c, BazId(42)))
    }

    def assertRoundTrip(c: Codec[v], x: v): Unit \ Assert with Eq[v], ToString[v] =
        assertEq(expected = Some(x), Codec.decode(c, Codec.encode(c, x)))

    def assertRoundTrips(c: Codec[v], xs: List[v]): Unit \ Assert with Eq[v], ToString[v] =
        List.forEach(x -> assertRoundTrip(c, x), xs)
}
