///
/// The default codec of a segment type.
///
pub mod Anneau.Router.Codec.SegmentCodec {
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
