mod Anneau.Router.Codec.TestSegmentCodec {
    use Anneau.Router.Codec
    use Anneau.Router.Codec.SegmentCodec
    use Anneau.Router.Codec.TestSegmentCodec.BazId.BazId
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
