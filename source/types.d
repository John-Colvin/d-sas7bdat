module sas7bdat.types;

import std.system : Endian;
import std.datetime : DateTime;
import std.encoding : EncodingScheme;

package enum SasColumnType : byte
{
    NUMERIC,
    CHARACTER,
    DATE,
    DATETIME,
    TIME
}

package enum SasFileFormat : byte
{
    UNIX,
    WIN
}

package enum SasEncoding : ubyte
{
    UTF8         = 20,
    US_ASCII     = 28,
    ISO_8859_1   = 29,
    ISO_8859_2   = 30,
    ISO_8859_3   = 31,
    ISO_8859_6   = 34,
    ISO_8859_7   = 35,
    ISO_8859_8   = 36,
    ISO_8859_9   = 40,
    ISO_8859_11  = 39,
    WINDOWS_1250 = 60,
    WINDOWS_1251 = 61,
    WINDOWS_1252 = 62,
    WINDOWS_1253 = 63,
    WINDOWS_1254 = 64,
    WINDOWS_1255 = 65,
    WINDOWS_1256 = 66,
    EUC_TW       = 119,
    BIG_5        = 123,
    EUC_CN       = 125,
    EUC_JP       = 134,
    SHIFT_JIS    = 138,
    EUC_KR       = 140,
}

package struct SasHeader
{
    bool a2;
    ubyte[] unknown1;
    byte a1;
    byte unknown2;
    Endian endianness;
    byte unknown3;
    SasFileFormat fileFormat;
    ubyte[] unknown4;
    ubyte[] unknown5;
    ubyte[] unknown6;
    EncodingScheme encodingScheme;
    string sasFile;
    string name;
    string fileType;
    ubyte[] paddedSpace;
    DateTime createdAt;
    DateTime modifiedAt;
    ubyte[] unknown7;
    int headerLength;
    int pageSize;
    long pageCount;
    ubyte[] unknown8;
    string sasRelease;
    string serverType;
    string osVersion;
    string osMaker;
    string osName;
    ubyte[] unknown9;
    int pageSeqSignature;
    ubyte[] unknown10;
    DateTime unknownTimestamp;
}

package struct SasSubheader
{
    ubyte[] rawData;
    ubyte[] signature;
}
