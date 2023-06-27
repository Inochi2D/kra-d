/**
   This KRA/KRZ file parser

   This is based https://github.com/2shady4u/libkra
   Structure based on psd-d (https://github.com/inochi2d/psd-d)

   Authors: Luna Neilsen, otrocodigo
   
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
	return parseKRAFile(file);
}

package(kra):
private:
KRA parseKRAFile(ZipArchive file)
{
	KRA kra;
	kra.fileRef = file;

	auto mainDoc = kra.fileRef.directory["maindoc.xml"];
	kra.fileRef.expand(mainDoc);

	auto dom = parseDOM!simpleXML(cast(string) mainDoc.expandedData);

	auto doc = dom.children[0];
	auto image = doc.children[0];

	auto attrs = image.attributes;

	kra.width = to!int(getAttrValue(attrs, "width"));
	kra.height = to!int(getAttrValue(attrs, "height"));
	kra.name = getAttrValue(attrs, "name");
	kra.colorMode = cast(ColorMode) getAttrValue(attrs, "colorspacename");

	auto layerEntity = image.children[0];

	importAttributes(kra, layerEntity);

	return kra;
}

auto getAttrValue(T...)(in T attributes, string attribute)
{
	auto vals = attributes.filter!(x => x[0] == attribute).front;
	return (vals.length > 1) ? vals[1] : null;
}

void importAttributes(ref KRA kra, ref DOMEntity!string layerEntity)
{
	auto layers = layerEntity.children.filter!(x => x.name == "layer");

	foreach (l; layers)
	{
		Layer layer;

		auto attrs = l.attributes;

		layer.name = getAttrValue(attrs, "name");
		layer.isVisible = cast(bool) to!int(getAttrValue(attrs, "visible"));
		layer.opacity = to!int(getAttrValue(attrs, "opacity"));
		layer.uuid = getAttrValue(attrs, "uuid");
		layer.x = to!int(getAttrValue(attrs, "x"));
		layer.y = to!int(getAttrValue(attrs, "y"));

		switch (getAttrValue(attrs, "nodetype"))
		{
		default: //"paintlayer":
			auto colorSpacename = getAttrValue(attrs, "colorspacename");
			auto fileName = getAttrValue(attrs, "filename");
			auto compositeOp = getAttrValue(attrs, "compositeop");

			layer.type = LayerType.Any;
			layer.blendModeKey = cast(BlendingMode) compositeOp;
			layer.colorMode = cast(ColorMode) colorSpacename;

			auto layerFile = kra.fileRef.directory[buildPath(kra.name, "layers", fileName)];
			kra.fileRef.expand(layerFile);
			parseLayerData(layerFile.expandedData.ptr, layer);

			kra.layers ~= layer;
			break;
		case "grouplayer":
			importAttributes(kra, l.children[0]);

			auto collapsed = cast(bool) to!int(getAttrValue(attrs, "collapsed"));
			layer.type = (collapsed) ? LayerType.ClosedFolder : LayerType.OpenFolder;
			kra.layers ~= layer;

			Layer groupEnd;
			groupEnd.type = LayerType.SectionDivider;
			kra.layers ~= groupEnd;
			break;
		}

	}
}

void parseLayerData(ubyte* layerData, ref Layer layer)
{
	auto layerInfo = readLayerInfo(layerData);

	layer.numberOfVersion = to!int(layerInfo["VERSION"]);
	layer.tileWidth = to!int(layerInfo["TILEWIDTH"]);
	layer.tileHeight = to!int(layerInfo["TILEHEIGHT"]);
	layer.pixelSize = to!int(layerInfo["PIXELSIZE"]);

	uint n_tiles = to!int(layerInfo["DATA"]);

	foreach (i; 0 .. n_tiles)
	{
		string tileInfo = readLayerLine(layerData);

		auto sm = tileInfo.split(",");

		Tile tile;

		tile.left = to!int(sm[0]);
		tile.top = to!int(sm[1]);
		int compressedLength = to!int(sm[3]);

		tile.compressedData = layerData[1 .. compressedLength + 1];
		tile.compressedLenght = compressedLength;

		layerData += compressedLength;

		layer.tiles ~= tile;
	}

	int tileWidth = cast(int) layer.tileWidth;
	int tileHeight = cast(int) layer.tileHeight;

	layer.top = 0;
	layer.left = 0;
	layer.bottom = 0;
	layer.right = 0;

	foreach (tile; layer.tiles)
	{
		if (tile.left < layer.left)
			layer.left = tile.left;
		if (tile.left + tileWidth > layer.right)
			layer.right = tile.left + tileWidth;
		if (tile.top < layer.top)
			layer.top = tile.top;
		if (tile.top + tileHeight > layer.bottom)
			layer.bottom = tile.top + tileHeight;
	}

	layer.width = layer.right - layer.left;
	layer.height = layer.bottom - layer.top;
}

string readLayerLine(ref ubyte* layerData)
{
	string header;
	while (*layerData != 10)
		header ~= *layerData++;
	layerData++;
	return header;
}

string[string] readLayerInfo(ref ubyte* layerData)
{
	string[string] headers;
	foreach (i; 0 .. 5)
	{
		auto parts = readLayerLine(layerData).split(" ");
		headers[parts[0]] = parts[1];
	}
	return headers;
}

void cropLayer(ubyte[] layerData, ref Layer layer)
{
	// Initialize the coordinates of the top-left and bottom-right corners of the crop
	int xmin = int.max;
	int ymin = int.max;
	int xmax = 0;
	int ymax = 0;

	foreach (y; 0 .. layer.height)
	{
		size_t layerIdxY = (y * layer.width) * 4;

		foreach (x; 0 .. layer.width)
		{
			size_t layerIdxX = layerIdxY + (x * 4);

			// Check if a pixel is not completely transparent
			if (layerData[layerIdxX .. layerIdxX + 3] != [
				0, 0, 0
			]
					&& layerData[layerIdxX + 3] >= 0)
			{
				// Update the coordinates of the top-left and bottom-right corners
				if (xmin > x)
					xmin = x;
				if (ymin > y)
					ymin = y;
				if (xmax < x)
					xmax = x;
				if (ymax < y)
					ymax = y;
			}
		}
	}

	// Adjust xmax and ymax to include the last column and row of pixels
	xmax += 1;
	ymax += 1;

	// Calculate the width and height of the crop
	int cropWidth = xmax - xmin;
	int cropHeight = ymax - ymin;

	// Copy the relevant pixels from composedData to outData for each row in the cropped
	ubyte[] outData = new ubyte[cropWidth * cropHeight * layer
			.pixelSize];

	foreach (y; 0 .. cropHeight)
	{
		// Calculate the byte index of the beginning of the current row in composedData
		size_t lineStart = ((ymin + y) * layer.width + xmin) * layer
			.pixelSize;

		// Calculate the byte index of the beginning of the current row in outData
		size_t outStart = y * cropWidth * layer
			.pixelSize;

		// Calculate how many bytes to copy for the current row
		size_t runLength = (cropWidth * layer.pixelSize);

		// Copy the relevant pixels from composedData to outData for the current row
		outData[outStart .. outStart + runLength] = layerData[lineStart .. lineStart + runLength];
	}

	layer.width = cropWidth;
	layer.height = cropHeight;
	layer.left = xmin;
	layer.top = ymin;

	layer.data = outData;
}

public:
void extractLayer(ref Layer layer, bool crop)
{
	uint decompressedLength = layer.pixelSize * layer.tileWidth * layer.tileHeight;
	uint numberOfColumns = cast(uint) layer.width / layer.tileWidth;
	uint numberOfRows = cast(uint) layer.height / layer.tileHeight;
	uint rowLength = numberOfColumns * layer.pixelSize * layer.tileWidth;

	uint composedLength = numberOfColumns * numberOfRows * decompressedLength;

	ubyte[] composedData = new ubyte[composedLength];

	foreach (tile; layer.tiles)
	{
		auto unsortedData = lzfDecompress(tile.compressedData, tile.compressedLenght, decompressedLength);

		auto pixelVector = iota(0, layer.pixelSize).array;

		switch (layer.colorMode)
		{
		default:
		case ColorMode.RGBA:
			uint bytesPerChannel = 1;
			swapRanges(pixelVector[0 .. bytesPerChannel], pixelVector[bytesPerChannel * 2 .. $]);
			break;
		case ColorMode.RGBA16:
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

	if (crop)
	  cropLayer(composedData, layer);
	else
	  layer.data = composedData;
}
