module sas7bdat.util;

import std.bitmanip : read;
import std.system : Endian;

T readTypeFromBytesAt(T, R)(Endian endianness, R r, size_t offset)
{
    return readBytesAs!T(endianness, r[offset .. offset + T.sizeof]);
}

T readBytesAs(T, R)(Endian endianness, R r)
{
    final switch (endianness)
    {
        case Endian.bigEndian:
            return read!(T, Endian.bigEndian, R)(r);
        case Endian.littleEndian:
            return read!(T, Endian.littleEndian, R)(r);
    }
}
