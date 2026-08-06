pub mod Anneau.Router.Codec {
    pub enum Codec[v]({
        name = String,
        decode = String -> Option[v],
        encode = v -> String
    })

    pub def name(c: Codec[v]): String =
        let Codec({name | _}) = c;
        name

    pub def decode(c: Codec[v]): String -> Option[v] =
        let Codec({decode | _}) = c;
        decode

    pub def encode(c: Codec[v]): v -> String =
        let Codec({encode | _}) = c;
        encode

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

    def stringConvertible(name: String): Codec[v] with FromString[v], ToString[v] =
        Codec({
            name = name,
            decode = FromString.fromString,
            encode = ToString.toString
        })

    pub def string(): Codec[String] = stringConvertible("String")

    pub def int32(): Codec[Int32] = stringConvertible("Int32")

    pub def int64(): Codec[Int64] = stringConvertible("Int64")

    pub def bool(): Codec[Bool] = stringConvertible("Bool")

    mod SegmentCodec {
        use Anneau.Router.Codec

        pub trait SegmentCodec[v] {
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
