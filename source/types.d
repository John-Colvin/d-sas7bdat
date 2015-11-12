module sas7bdat.types;

import std.system : Endian;
import std.datetime : DateTime;

package enum SasColumnType : byte
{
	NUMERIC,
	CHARACTER,
	DATE,
	DATETIME,
	TIME
}

package enum SasOSType : byte
{
	UNIX,
	WIN
}

package struct SasHeader
{
	bool isU64;
	ubyte[] unknown1;
	byte padding;
	byte unknown2;
	Endian endianness;
	byte unknown3;
	SasOSType os;
	ubyte[] unknown4;
	ubyte[] unknown5;
	ubyte[] unknown6;
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
