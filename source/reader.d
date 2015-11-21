module sas7bdat.reader;

public import std.Variant;
import std.stdio;
import std.algorithm;
import std.file;
import std.conv;
import std.exception;
import core.stdc.errno;
import std.system;
import std.datetime;
import std.string;
import std.encoding;

import sas7bdat.types;
import sas7bdat.util;

class Sas7bdatReader
{
    SasHeader header;

    this(string path)
    {
        this.read(path);
    }

    Variant getCell(size_t row, size_t col)
    {
        return table[row][col];
    }

    Variant[] getRow(size_t row)
    {
        return table[row];
    }

    Variant[] getColumn(size_t col)
    {
        return table[][col];
    }

    Variant[][] getTable()
    {
        return table;
    }

    private:
        // MAGIC_NUMBER is just a property used to validate the sas data file is in fact a sas data file.
        File file;
        Variant[][] table;

        void read(string path)
        {
            const ubyte[32] MAGIC_NUMBER = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
                                            0x00, 0x00, 0x00, 0x00, 0xC2, 0xEA, 0x81, 0x60,
                                            0xB3, 0x14, 0x11, 0xCF, 0xBD, 0x92, 0x08, 0x00,
                                            0x09, 0xC7, 0x31, 0x8C, 0x18, 0x1F, 0x10, 0x11];

            const ubyte[] ROW_SIZE_SUBHEADER = [0xF7, 0xF7, 0xF7, 0xF7];
            const ubyte[] COL_SIZE_SUBHEADER = [0xF6, 0xF6, 0xF6, 0xF6];
            const ubyte[] COUNTS_SUBHEADER   = [0x00, 0xFC, 0xFF, 0xFF];
            const ubyte[] COL_TEXT_SUBHEADER = [0xFD, 0xFF, 0xFF, 0xFF];
            const ubyte[] COL_NAME_SUBHEADER = [0xFF, 0xFF, 0xFF, 0xFF];
            const ubyte[] COL_ATTR_SUBHEADER = [0xFC, 0xFF, 0xFF, 0xFF];
            const ubyte[] COL_FRMT_SUBHEADER = [0xFE, 0xFB, 0xFF, 0xFF];
            const ubyte[] COL_LIST_SUBHEADER = [0xFE, 0xFF, 0xFF, 0xFF];

            try
            {
                // Enforce valid the MAGIC_NUMBER
                enforce(std.file.read(path, 32) == MAGIC_NUMBER, "File not recognized.");
                // Open file for reading
                file = File(path, "r");
            }
            catch (ErrnoException ex)
            {
                switch(ex.errno)
                {
                    case EPERM:
                    case EACCES:
                        // Permission denied
                        // TODO(csmith): handle file permission
                        break;
                    case ENOENT:
                        // File does not exist
                        // TODO(csmith): handle file existence
                        break;
                    default:
                        //TODO(csmith): handle general exception
                        break;
                }
            }

            // Read the header for the file to extract some basic metadata
            {
                scope(failure) throw new Exception("Failed to read header.");

                ubyte[] buffer;
                // In principle, the length of the header is at most 336 bytes long; however, it appears there's some
                // space reserved
                buffer.length = 8192;
                auto rawHeader = file.rawRead(buffer);

                header.a2 = rawHeader[32] == 0x33;
                header.unknown1 = rawHeader[33 .. 35];
                header.a1 = rawHeader[35] == 0x33 ? 4 : 0;
                header.unknown2 = rawHeader[36];
                header.endianness = rawHeader[37] == 0x00 ? Endian.bigEndian : Endian.littleEndian;
                header.unknown3 = rawHeader[38];
                header.fileFormat = cast(SasFileFormat)(rawHeader[39] - '0');
                header.unknown4 = rawHeader[40 .. 48];
                header.unknown5 = rawHeader[48 .. 56];
                header.unknown6 = rawHeader[56 .. 62];
                switch (readTypeFromBytesAt!SasEncoding(header.endianness, rawHeader, 70))
                {
                    case SasEncoding.WINDOWS_1252:
                        header.encodingScheme = EncodingScheme.create("WINDOWS-1252");
                        break;
                    case SasEncoding.WINDOWS_1250:
                        header.encodingScheme = EncodingScheme.create("WINDOWS-1250");
                        break;
                    case SasEncoding.ISO_8859_1:
                        header.encodingScheme = EncodingScheme.create("ISO-8859-1");
                        break;
                    case SasEncoding.ISO_8859_2:
                        header.encodingScheme = EncodingScheme.create("ISO-8859-2");
                        break;
                    case SasEncoding.UTF8:
                        header.encodingScheme = EncodingScheme.create("UTF-8");
                        break;
                    default:
                        header.encodingScheme = EncodingScheme.create("WINDOWS-1252");
                        break;
                }

                header.sasFile = rawHeader[84 .. 92].map!(x => x.to!char).to!string.strip;
                header.name = rawHeader[92 .. 156].map!(x => x.to!char).to!string.strip;
                header.fileType = rawHeader[156 .. 164].map!(x => x.to!char).to!string.strip;
                header.paddedSpace = rawHeader[164 .. 164 + header.a1];
                // SAS uses a ridiculous date format that's the number of seconds since Jan 1, 1960, stored as a double
                header.createdAt = DateTime(1960,1,1) + dur!"seconds"(
                        readTypeFromBytesAt!double(header.endianness, rawHeader, 164 + header.a1).to!long);
                header.modifiedAt = DateTime(1960,1,1) + dur!"seconds"(
                        readTypeFromBytesAt!double(header.endianness, rawHeader, 172 + header.a1).to!long);
                header.unknown7 = rawHeader[180 + header.a1 .. 196 + header.a1];
                header.headerLength = readTypeFromBytesAt!int(header.endianness, rawHeader, 196 + header.a1);
                header.pageSize = readTypeFromBytesAt!int(header.endianness, rawHeader, 200 + header.a1);
                // At this point, more padding can be introduced to fit numbers stored with the unix 64 bit format
                if (header.a2)
                {
                    header.a1 += 4;
                    header.pageCount = readTypeFromBytesAt!long(header.endianness, rawHeader, 204 + header.a1);
                } else {
                    header.pageCount = readTypeFromBytesAt!int(header.endianness, rawHeader, 204 + header.a1).to!long;
                }
                header.unknown8 = rawHeader[208 + header.a1 .. 216 + header.a1];
                header.sasRelease = rawHeader[216 + header.a1 .. 224 + header.a1]
                                        .map!(x => x.to!char).to!string.strip;
                header.serverType = rawHeader[224 + header.a1 .. 240 + header.a1]
                                        .map!(x => x.to!char).to!string.strip;
                header.osVersion = rawHeader[240 + header.a1 .. 256 + header.a1]
                                        .map!(x => x.to!char).to!string.strip;
                header.osMaker = rawHeader[256 + header.a1 .. 272 + header.a1]
                                        .map!(x => x.to!char).to!string.strip;
                header.osName = rawHeader[272 + header.a1 .. 288 + header.a1]
                                        .map!(x => x.to!char).to!string.strip;
                header.unknown9 = rawHeader[288 + header.a1 .. 320 + header.a1];
                header.pageSeqSignature = readTypeFromBytesAt!int(header.endianness, rawHeader, 320 + header.a1);
                header.unknown10 = rawHeader[324 + header.a1 .. 328 + header.a1];
                header.unknownTimestamp = DateTime(1960, 1, 1) + dur!"seconds"(
                        readTypeFromBytesAt!double(header.endianness, rawHeader, 328 + header.a1).to!long);

                assert(sum(rawHeader[336 + header.a1 ..
                      (header.headerLength < buffer.length) ? header.headerLength : buffer.length]) == 0,
                       "Data in header unaccounted for");
            }

            // Read pages
            {
                scope(failure) throw new Exception("Failed to read page in dataset " ~ header.name);

                SasSubheader[] subheaders;
                int[] columnOffsets;
                int[] columnLengths;
                SasColumnType[] columnTypes;

                auto subheadersParsed = false;

                auto pageNumber = 0;
                auto rowCount = 0;

                auto row_count = -1;
                auto row_count_fp = -1;
                auto row_length = -1;
                auto col_count = -1;

                file.seek(header.headerLength, SEEK_SET);
                foreach(pageData; file.byChunk(header.pageSize))
                {
                    ++pageNumber;
                    auto pageType = pageData[17];
                    switch (pageType)
                    {
                        // Known page types
                        case 0, 1, 2:
                            break;
                        //TODO(csmith): Known page type, unsupported
                        case 4:
                            continue;
                        default:
                            assert(0, "Page has unknown type");
                    }

                    if (pageType == 0 || pageType == 2)
                    {
                        uint subheaderCount = readTypeFromBytesAt!int(header.endianness, pageData, 20);
                        foreach (immutable subheaderNumber; 0 .. subheaderCount)
                        {
                            uint base = 24 + subheaderNumber * 12;
                            uint offset = readTypeFromBytesAt!int(header.endianness, pageData, base);
                            uint length = readTypeFromBytesAt!int(header.endianness, pageData, base + 4);

                            if (length > 0)
                            {
                                SasSubheader subheader;
                                subheader.rawData = pageData[offset .. offset + length];
                                subheader.signature = subheader.rawData[0 .. 4];

                                subheaders ~= subheader;
                            }
                        }
                        
                        version(unittest) {
                            foreach (subheader; subheaders) {
                                subheader.signature.writeln;
                                foreach (e; std.range.zip(std.range.iota(0, subheader.rawData.length), subheader.rawData))
                                    writeln(e[0], ": ", e[1]);
                            }
                        }
                        
                    }

                    if (pageType == 1 || pageType == 2)
                    {
                        if (! subheadersParsed)
                        {
                            SasSubheader rowSize = getSubheader(subheaders, ROW_SIZE_SUBHEADER);
                            row_length = readTypeFromBytesAt!int(header.endianness, rowSize.rawData, 20);
                            row_count = readTypeFromBytesAt!int(header.endianness, rowSize.rawData, 24);
                            int col_count_7 = readTypeFromBytesAt!int(header.endianness, rowSize.rawData, 36);
                            row_count_fp = readTypeFromBytesAt!int(header.endianness, rowSize.rawData, 60);

                            SasSubheader colSize = getSubheader(subheaders, COL_SIZE_SUBHEADER);
                            int col_count_6 = readTypeFromBytesAt!int(header.endianness, colSize.rawData, 4);
                            col_count = col_count_6;

                            assert(col_count_7 == col_count_6, "Column count mismatched");

                            SasSubheader colText = getSubheader(subheaders, COL_TEXT_SUBHEADER);

                            SasSubheader[] colAttrHeaders = getSubheaders(subheaders, COL_ATTR_SUBHEADER);
                            SasSubheader colAttr;
                            assert(colAttrHeaders.length > 0, "No column attribute subheader found");
                            if (colAttrHeaders.length == 1)
                            {
                                colAttr = colAttrHeaders[0];
                            } else {
                                colAttr = spliceColAttrSubheaders(colAttrHeaders);
                            }

                            SasSubheader colName = getSubheader(subheaders, COL_NAME_SUBHEADER);

                            SasSubheader[] colFormats = getSubheaders(subheaders, COL_FRMT_SUBHEADER);

                            assert(colFormats.length == 0 || colFormats.length == col_count, "Unexpected column label count");

                            foreach (immutable colNumber; 0 .. col_count)
                            {
                                int base = 12 + colNumber * 8;
                                string columnName;
                                string format;
                                string label;

                                auto amd = colName.rawData[base];
                                if (amd == 0)
                                {
                                    auto offset = readTypeFromBytesAt!short(header.endianness, colName.rawData, base + 2) + 4;
                                    auto length = readTypeFromBytesAt!short(header.endianness, colName.rawData, base + 4);

                                    columnName = colText.rawData[offset .. offset + length].map!(x => x.to!char).to!string;
                                } else {
                                    columnName = "COL" ~ colNumber.to!string;
                                }

                                if (colFormats.length > 0)
                                {
                                    base = 36;
                                    auto formatOffset = readTypeFromBytesAt!short(header.endianness, colFormats[colNumber].rawData, base + 0) + 4;
                                    auto formatLength = readTypeFromBytesAt!short(header.endianness, colFormats[colNumber].rawData, base + 2);
                                    auto labelOffset = readTypeFromBytesAt!short(header.endianness, colFormats[colNumber].rawData, base + 6) + 4;
                                    auto labelLength = readTypeFromBytesAt!short(header.endianness, colFormats[colNumber].rawData, base + 8);

                                    if (formatLength > 0)
                                    {
                                        format = colText.rawData[formatOffset .. formatOffset + formatLength]
                                                        .map!(x => x.to!char).to!string.strip;
                                    }

                                    if (labelLength > 0)
                                    {
                                        label = colText.rawData[labelOffset .. labelOffset + labelLength].map!(x => x.to!char).to!string.strip;
                                    } else {
                                        label = null;
                                    }
                                } else {
                                    label = null;
                                }

                                base = 12 + colNumber * 12;

                                int offset = readTypeFromBytesAt!int(header.endianness, colAttr.rawData, base);
                                columnOffsets ~= offset;

                                int length = readTypeFromBytesAt!int(header.endianness, colAttr.rawData, base + 4);
                                columnLengths ~= length;

                                short columnTypeCode = readTypeFromBytesAt!short(header.endianness, colAttr.rawData, base + 10);
                                SasColumnType columnType;
                                if (columnTypeCode == 1)
                                {
                                    switch(format.toUpper)
                                    {
                                        case "DATETIME":
                                            columnType = SasColumnType.DATETIME;
                                            break;
                                        case "DATE":
                                            columnType = SasColumnType.DATE;
                                            break;
                                        case "TIME":
                                            columnType = SasColumnType.TIME;
                                            break;
                                        default:
                                            columnType = SasColumnType.NUMERIC;
                                            break;
                                    }
                                } else {
                                    columnType = SasColumnType.CHARACTER;
                                }

                                columnTypes ~= columnType;
                            }

                            subheadersParsed = true;
                        }

                        // Read data
                        int row_count_p;
                        int base;
                        if (pageType == 2)
                        {
                            row_count_p = row_count_fp;
                            base = 24 + subheaders.length * 12 + 12;
                            base = base + base % 8;
                        } else {
                            row_count_p = readTypeFromBytesAt!int(header.endianness, pageData, 18);
                            base = 24;
                        }

                        if (row_count_p > row_count)
                        {
                            row_count_p = row_count;
                        }

                        foreach (rowNumber; 0 .. row_count_p)
                        {
                            Variant[] rowData;
                            foreach (col; 0 .. col_count)
                            {
                                int offset = base + columnOffsets[col];
                                int length = columnLengths[col];
                                SasColumnType columnType = columnTypes[col];

                                if (length > 0)
                                {
                                    ubyte[] raw = pageData[offset .. offset + length];
                                    if (columnType == SasColumnType.NUMERIC && length < 8)
                                    {
                                        if (header.endianness == Endian.bigEndian)
                                        {
                                            raw.length = 8;
                                        } else {
                                            ubyte[] tmp;
                                            tmp.length = 8 - length;
                                            tmp ~= raw;
                                            raw = tmp;
                                        }

                                        length = 8;
                                    }

                                    Variant value;
                                    final switch (columnType)
                                    {
                                        case SasColumnType.NUMERIC:
                                            value = readBytesAs!double(header.endianness, raw);
                                            break;
                                        case SasColumnType.CHARACTER:
                                            value = cast(dchar[])[];
                                            const(ubyte)[] buffer = raw[0 .. length];
                                            while (buffer.length > 0)
                                                value ~= header.encodingScheme.decode(buffer);
                                            break;
                                        case SasColumnType.DATE:
                                            value = DateTime(1960, 1, 1) +
                                                    dur!"days"(readBytesAs!double(header.endianness, raw).to!long);
                                            break;
                                        case SasColumnType.DATETIME:
                                            value = DateTime(1960, 1, 1) +
                                                    dur!"seconds"(readBytesAs!double(header.endianness, raw).to!long);
                                            break;
                                        case SasColumnType.TIME:
                                            value = TimeOfDay(0,0,0) +
                                                    dur!"seconds"(readBytesAs!double(header.endianness, raw).to!long);
                                            break;
                                    }

                                    rowData ~= value;
                                }
                            }

                            ++rowCount;
                            table ~= rowData;

                            base = base + row_length;
                        }
                    }
                }
            }
            file.close();
        }
        unittest
        {
            import std.range;
            foreach (path; dirEntries("tests/sasFiles", SpanMode.breadth).filter!(f => f.name.endsWith(".sas7bdat")).array.sort!"a < b")
            {

                try
                {
                    auto sasFile = new Sas7bdatReader(path);
                    assert(sasFile.header.sasFile == "SAS FILE");
                    assert(sasFile.header.headerLength % 1024 == 0, "Header size isn't recognized.");
                    sasFile.header.name.writeln;
                    if(sasFile.table.length > 0)
                        sasFile.getRow(0).writeln;
                    else
                        writeln("No data in table");
                } catch (Exception e) {
                    writeln("File ", path, " didn't pass, with the following error: ");
                    e.msg.writeln;
                }
            }
        }

        SasSubheader spliceColAttrSubheaders(SasSubheader[] colAttrHeaders)
        {
            auto bytes = colAttrHeaders[0].rawData[0 .. colAttrHeaders[0].rawData.length - 8];
            foreach (immutable i; 1 .. colAttrHeaders.length)
                bytes ~= colAttrHeaders[i].rawData[12 .. colAttrHeaders[i].rawData.length - 20];

            SasSubheader result;
            result.rawData = bytes;

            return result;
        }

        SasSubheader[] getSubheaders(SasSubheader[] subheaders, const(ubyte[]) signature)
        {
            SasSubheader[] result;
            foreach(subheader; subheaders)
                if (subheader.signature == signature)
                    result ~= subheader;

            return result;
        }

        SasSubheader getSubheader(SasSubheader[] subheaders, const(ubyte[]) signature)
        {
            return getSubheaders(subheaders, signature)[0];
        }
}
