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
        wrapDecode: a -> b,
        wrapEncode: b -> a,
        c: Codec[a]
    ): Codec[b] =
        Codec({
            name = name,
            decode = s -> Option.map(wrapDecode, decode(c, s)),
            encode = v -> encode(c, wrapEncode(v))
        })

    pub def refine(
        name: String,
        wrapDecode: a -> Option[b],
        wrapEncode: b -> a,
        c: Codec[a]
    ): Codec[b] =
        Codec({
            name = name,
            decode = s -> Option.flatMap(wrapDecode, decode(c, s)),
            encode = v -> encode(c, wrapEncode(v))
        })

    pub def string(): Codec[String] =
        Codec({
            name = "String",
            decode = Some,
            encode = identity
        })

    pub def int32(): Codec[Int32] =
        Codec({
            name = "Int32",
            decode = FromString.fromString,
            encode = ToString.toString
        })

    pub def int64(): Codec[Int64] =
        Codec({
            name = "Int64",
            decode = FromString.fromString,
            encode = ToString.toString
        })

    pub def bool(): Codec[Bool] =
        Codec({
            name = "Bool",
            decode = FromString.fromString,
            encode = ToString.toString
        })

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
