///
/// Codecs for single URI path segments.
///
/// A `Codec[v]` bundles the partial decoding and the total encoding of one path
/// segment, so that a captured segment reaches a handler as a value of type `v`
/// rather than as a `String`.
///
pub mod Anneau.Router.Codec {
    ///
    /// A bidirectional conversion between a single path segment and a value of type `v`.
    ///
    /// `decode` is partial: it returns `None` for a segment that does not denote a
    /// value of `v`. `encode` is total. A codec is expected to round-trip, that is
    /// `decode(c, encode(c, x)) == Some(x)` for every `x`.
    ///
    /// `name` is a display label such as `"Int32"` or `"ToDoId"`. It carries no
    /// semantics and is used only by `Anneau.Router.Path.describe`.
    ///
    pub enum Codec[v]({
        name = String,
        decode = String -> Option[v],
        encode = v -> String
    })

    ///
    /// Returns the display name of `c`.
    ///
    pub def name(c: Codec[v]): String =
        let Codec({name | _}) = c;
        name

    ///
    /// Returns the decoder of `c`, which maps a path segment to `Some(v)`, or to
    /// `None` if the segment does not denote a value of `v`.
    ///
    pub def decode(c: Codec[v]): String -> Option[v] =
        let Codec({decode | _}) = c;
        decode

    ///
    /// Returns the encoder of `c`, which maps a value of `v` to a path segment.
    ///
    pub def encode(c: Codec[v]): v -> String =
        let Codec({encode | _}) = c;
        encode

    ///
    /// Returns a codec for `b` obtained from `c` by a total conversion, named `name`.
    ///
    /// Use this to lift a codec to a single-case wrapper type, so that two
    /// identifiers backed by the same primitive cannot be mistaken for each other:
    ///
    /// ```
    /// enum ToDoId(Int32) with Eq, ToString
    ///
    /// Codec.int32() |> Codec.wrap(
    ///     "ToDoId",
    ///     decode = ToDoId,
    ///     encode = id -> let ToDoId(v) = id; v
    /// )
    /// ```
    ///
    /// See `refine` for a conversion that may reject values.
    ///
    pub def wrap(
        name: String,
        wrapDecode: {decode = a -> b},
        wrapEncode: {encode = b -> a},
        c: Codec[a]
    ): Codec[b] =
        refine(
            name,
            decode = wrapDecode#decode >> Some,
            encode = wrapEncode#encode,
            c
        )

    ///
    /// Returns a codec for `b` obtained from `c` by a partial conversion, named `name`.
    ///
    /// `wrapDecode` may return `None` to reject an otherwise well-formed `a`, which
    /// makes the resulting codec reject the corresponding segments. This is how a
    /// validated identifier is expressed — where `wrap` admits every `Int32` as a
    /// `ToDoId`, `refine` admits only the positive ones:
    ///
    /// ```
    /// enum ToDoId(Int32) with Eq, ToString
    ///
    /// Codec.int32() |> Codec.refine(
    ///     "ToDoId",
    ///     decode = v -> if (v > 0) Some(ToDoId(v)) else None,
    ///     encode = id -> let ToDoId(v) = id; v
    /// )
    /// ```
    ///
    /// The result round-trips as long as `wrapDecode(wrapEncode(x)) == Some(x)`.
    ///
    pub def refine(
        name: String,
        wrapDecode: {decode = a -> Option[b]},
        wrapEncode: {encode = b -> a},
        c: Codec[a]
    ): Codec[b] =
        Codec({
            name = name,
            decode = s -> Option.flatMap(wrapDecode#decode, decode(c, s)),
            encode = v -> encode(c, wrapEncode#encode(v))
        })

    ///
    /// Returns a codec named `name` that delegates to the `FromString` and
    /// `ToString` instances of `v`.
    ///
    def stringConvertible(name: String): Codec[v] with FromString[v], ToString[v] =
        Codec({
            name = name,
            decode = FromString.fromString,
            encode = ToString.toString
        })

    ///
    /// Returns the codec for `String` segments.
    ///
    /// Every segment decodes and every string encodes. Note that a value which is
    /// empty or which contains `/` encodes to something that
    /// `Anneau.Router.Path.split` does not read back as a single segment.
    ///
    pub def string(): Codec[String] = stringConvertible("String")

    ///
    /// Returns the codec for `Int32` segments, in the format accepted by
    /// `Int32.fromString`.
    ///
    /// Leading zeros are accepted; a segment denoting a number outside the range of
    /// `Int32` is rejected.
    ///
    pub def int32(): Codec[Int32] = stringConvertible("Int32")

    ///
    /// Returns the codec for `Int64` segments, in the format accepted by
    /// `Int64.fromString`.
    ///
    /// Leading zeros are accepted; a segment denoting a number outside the range of
    /// `Int64` is rejected.
    ///
    pub def int64(): Codec[Int64] = stringConvertible("Int64")

    ///
    /// Returns the codec for `Bool` segments.
    ///
    /// Only the exact segments `"true"` and `"false"` decode.
    ///
    pub def bool(): Codec[Bool] = stringConvertible("Bool")

    ///
    /// The default codec of a segment type.
    ///
    mod SegmentCodec {
        use Anneau.Router.Codec

        ///
        /// A type whose values can be captured from a single path segment.
        ///
        /// `Anneau.Router.Path.param` picks up the instance, so giving one to a
        /// domain-specific identifier type is what lets a path be written as
        /// `param("id")` while still capturing a `ToDoId` rather than an `Int32`.
        ///
        pub trait SegmentCodec[v] {
            ///
            /// Returns the codec of `v`.
            ///
            pub def codec(): Codec[v]
        }

        instance SegmentCodec[String] {
            pub def codec(): Codec[String] = Codec.string()
        }

        instance SegmentCodec[Int32] {
            pub def codec(): Codec[Int32] = Codec.int32()
        }

        instance SegmentCodec[Int64] {
            pub def codec(): Codec[Int64] = Codec.int64()
        }

        instance SegmentCodec[Bool] {
            pub def codec(): Codec[Bool] = Codec.bool()
        }
    }
}
