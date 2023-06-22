/**
   This KRA/KRZ file parser

   This is based https://github.com/2shady4u/libkra
   Structure based on psd-d (https://github.com/inochi2d/psd-d)
   
*/
   

module kra.parser;
import kra;
import kra.lzf;
import kra.layer : Tile;

import std.file;
import std.stdio;
import std.path;
import std.conv;
import std.regex;
import std.array;
import std.range : iota;
import std.algorithm;
import std.algorithm.mutation : swapRanges;
import core.stdc.string;
import dxml.dom;
import std.zip;

/**
   Parses a Krita document
*/
KRA parseDocument(string fileName)
{
	auto file = new ZipArchive(read(fileName));
	KRA kra;
	kra.fileRef = file;

	auto mainDoc = kra.fileRef.directory["maindoc.xml"];
	kra.fileRef.expand(mainDoc);

	auto dom = parseDOM!simpleXML(cast(string) mainDoc.expandedData);

	auto doc = dom.children[0];
	auto image = doc.children[0];

	auto imageAttributes = image.attributes;
	auto width = imageAttributes.filter!(x => x[0] == "width").front[1];
	auto height = imageAttributes.filter!(x => x[0] == "height").front[1];

	auto name = imageAttributes.filter!(x => x[0] == "name").front[1];
	kra.name = name;

	auto colorspacename = imageAttributes.filter!(x => x[0] == "colorspacename").front[1];

	kra.width = to!int(width);
	kra.height = to!int(height);
	kra.colorMode = cast(ColorMode) colorspacename;

	DOMEntity!string layerEntity = image.children[0];

	importAttributes(kra, layerEntity);

	return kra;
}

package(kra):
private:
void importAttributes(ref KRA kra, ref DOMEntity!string layerEntity)
{
	auto layers = layerEntity.children.filter!(x => x.name == "layer");

	foreach (l; layers)
	{
		Layer layer;

		auto att = l.attributes;
		auto nodeType = att.filter!(x => x[0] == "nodetype").front[1];

		auto fileName = att.filter!(x => x[0] == "filename").front[1];
		auto layerName = att.filter!(x => x[0] == "name").front[1];
		auto uuid = att.filter!(x => x[0] == "uuid").front[1];

		auto compositeOp = att.filter!(x => x[0] == "compositeop").front[1];

		auto x = to!int(att.filter!(x => x[0] == "x").front[1]);
		auto y = to!int(att.filter!(x => x[0] == "y").front[1]);
		auto opacity = to!int(att.filter!(x => x[0] == "opacity").front[1]);

		auto visible = cast(bool) to!int(att.filter!(x => x[0] == "visible").front[1]);
		auto collapsed = cast(bool) to!int(att.filter!(x => x[0] == "collapsed").front[1]);

		layer.name = layerName;
		layer.isVisible = visible;
		layer.opacity = opacity;
		layer.uuid = uuid;
		layer.x = x;
		layer.x = y;

		if (nodeType == "paintlayer")
		{
			auto colorSpacename = att.filter!(x => x[0] == "colorspacename").front[1];

			layer.type = LayerType.Any;

			auto layerFile = kra.fileRef.directory[buildPath(kra.name, "layers", fileName)];
			kra.fileRef.expand(layerFile);
			layer.dataPtr = layerFile.expandedData.ptr;

			layer.blendModeKey = cast(BlendingMode) compositeOp;
			layer.colorMode = cast(ColorMode) colorSpacename;
			parseLayer(layer);
			kra.layers ~= layer;
		}
		else if (nodeType == "grouplayer")
		{
			importAttributes(kra, l.children[0]);

			layer.type = (collapsed) ? LayerType.ClosedFolder : LayerType.OpenFolder;
			kra.layers ~= layer;

			Layer groupEnd;
			groupEnd.type = LayerType.SectionDivider;
			kra.layers ~= groupEnd;
		}

	}
}

Layer parseLayer(ref Layer layer)
{
	parseLayerHeader(layer);

	uint n_tiles = elementValue(layer, "DATA");

	layer.tiles = new Tile[n_tiles];

	foreach (i; 0 .. n_tiles)
	{
		Tile tile;

		string header;

		while (*++layer.dataPtr != 10)
			header ~= *layer.dataPtr;

		auto e = ctRegex!("(-?\\d*),(-?\\d*),(\\w*),(\\d*)");
		auto sm = matchFirst(header, e);

		tile.left = to!int(sm[1]);
		tile.top = to!int(sm[2]);

		int compressed_length = to!int(sm[4]);

		ubyte[] input = layer.dataPtr[1 .. compressed_length + 1].array;

		layer.dataPtr += compressed_length;

		tile.compressedLenght = compressed_length;
		tile.compressedData = input;

		layer.tiles[i] = tile;
	}

	layer.top = 0;
	layer.left = 0;
	layer.bottom = 0;
	layer.right = 0;

	foreach (tile; layer.tiles)
	{
		if (tile.left < layer.left)
		{
			layer.left = tile.left;
		}
		if (tile.left + cast(int) layer.tileWidth > layer.right)
		{
			layer.right = tile.left + cast(int) layer.tileWidth;
		}

		if (tile.top < layer.top)
		{
			layer.top = tile.top;
		}

		if (tile.top + cast(int) layer.tileHeight > layer.bottom)
		{
			layer.bottom = tile.top + cast(int) layer.tileHeight;
		}
	}

	layer.width = layer.right - layer.left;
	layer.height = layer.bottom - layer.top;

	return layer;
}

uint elementValue(ref Layer layer, const string element_name)
{
	layer.dataPtr += element_name.length + 1;
	string v;
	while (*++layer.dataPtr != 10)
		v ~= *layer.dataPtr;
	return to!int(v);
}

/*
  KRITA LAYER HEADER
 */
void parseLayerHeader(ref Layer layer)
{
	layer.numberOfVersion = elementValue(layer, "VERSIO");
	layer.tileWidth = elementValue(layer, "TILEWIDTH");
	layer.tileHeight = elementValue(layer, "TILEHEIGHT");
	layer.pixelSize = elementValue(layer, "PIXELSIZE");
}

public:
void extractLayer(ref Layer layer)
{
	uint decompressedLength = layer.pixelSize * layer.tileWidth * layer.tileHeight;
	uint numberOfColumns = cast(uint) layer.width / layer.tileWidth;
	uint numberOfRows = cast(uint) layer.height / layer.tileHeight;
	uint rowLength = numberOfColumns * layer.pixelSize * layer.tileWidth;

	uint composedLength = numberOfColumns * numberOfRows * decompressedLength;

	ubyte[] composedData = new ubyte[composedLength];

	foreach (tile; layer.tiles)
	{
		ubyte[] unsortedData = new ubyte[decompressedLength];

		lzfDecompress(tile.compressedData[1 .. $], tile.compressedLenght, unsortedData, decompressedLength);

		auto pixelVector = iota(0, layer.pixelSize).array;

		if (layer.colorMode == ColorMode.RGBA)
		{
			uint bytesPerChannel = 1;
			swapRanges(pixelVector[0 .. bytesPerChannel], pixelVector[bytesPerChannel * 2 .. $]);

		}
		else if (layer.colorMode == ColorMode.RGBA16)
		{
			uint bytesPerChannel = 2;
			swapRanges(pixelVector[0 .. bytesPerChannel], pixelVector[bytesPerChannel * 2 .. $]);
		}

		ubyte[] sortedData = new ubyte[decompressedLength];
		int tile_area = layer.tileHeight * layer.tileWidth;

		foreach (i; 0 .. tile_area)
		{
			uint realIndex = 0;
			foreach (j; pixelVector)
			{
				sortedData[i * layer.pixelSize + realIndex] =
					unsortedData[j * tile_area + i];
				realIndex++;
			}
		}

		int relativeTileTop = tile.top - layer.top;
		int relativeTileLeft = tile.left - layer.left;
		auto size = layer.pixelSize * layer.tileWidth;

		foreach (rowIndex; 0 .. layer.tileHeight)
		{
			auto destination = composedData.ptr + rowIndex * rowLength;
			destination += relativeTileLeft * layer.pixelSize;
			destination += relativeTileTop * rowLength;
			auto source = sortedData.ptr + size * rowIndex;

			/* Copy the row of the tile to the composed data */
			memcpy(destination, source, size);
		}

	}
	layer.data = composedData;
}
