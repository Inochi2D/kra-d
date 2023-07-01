/**
   This KRA/KRZ file parser

   This is based https://github.com/2shady4u/libkra
   Structure based on psd-d (https://github.com/inochi2d/psd-d)

   Authors: Luna Neilsen, otrocodigo
   
*/

module kra.parser;
import kra;
import kra.layer : Tile;

import std.file;
import std.exception;
import std.stdio;
import std.path;
import std.conv;
import std.array;
import std.range : iota;
import std.algorithm;
import std.algorithm.mutation : swapRanges;
import core.stdc.string : memcpy;
import dxml.dom;
import std.math : abs;
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

	// Check mimetype
	enforce("mimetype" in kra.fileRef.directory, "Invalid documento: no file 'mimetype'");

	auto mimetypeFile = kra.fileRef.directory["mimetype"];
	kra.fileRef.expand(mimetypeFile);

	enforce(cast(string) mimetypeFile.expandedData == "application/x-krita", "Invalid document: invalid mimetype");

	// Check maindoc
	enforce("maindoc.xml" in kra.fileRef.directory, "Invalid document: no file 'maindoc.xml");

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

	importAttributes(kra, image.children[0]);

	return kra;
}

string buildPathKRA(T...)(T segments)
{
	string o = "";
	static foreach (seg; segments)
	{
		import std.conv : text;

		o ~= "/" ~ seg.text;
	}
	return o[1 .. $];
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
		case "paintlayer":
			auto colorSpacename = getAttrValue(attrs, "colorspacename");
			auto fileName = getAttrValue(attrs, "filename");
			auto compositeOp = getAttrValue(attrs, "compositeop");

			layer.type = LayerType.Any;
			layer.blendModeKey = cast(BlendingMode) compositeOp;
			layer.colorMode = cast(ColorMode) colorSpacename;
			auto layerFile = kra.fileRef.directory[buildPathKRA(kra.name, "layers", fileName)];
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
		default:
			assert(0, "Unsupported nodetype.");
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
	layer.top = int.max;
	layer.left = int.max;
	layer.bottom = 0;
	layer.right = 0;

	uint n_tiles = to!int(layerInfo["DATA"]);

	layer.tiles = new Tile[n_tiles];

	foreach (i; 0 .. n_tiles)
	{
		string tileInfo = readLayerLine(layerData);
		auto infoParts = tileInfo.split(",");

		int left = to!int(infoParts[0]);
		int top = to!int(infoParts[1]);
		int compressedLength = to!int(infoParts[3]);

		ubyte[] compressedData = layerData[1 .. compressedLength + 1];
		layerData += compressedLength;

		layer.tiles[i] = new Tile(left, top, compressedData);

		if (left < layer.left)
			layer.left = left;
		if (left + layer.tileWidth > layer.right)
			layer.right = left + layer.tileWidth;
		if (top < layer.top)
			layer.top = top;
		if (top + layer.tileHeight > layer.bottom)
			layer.bottom = top + layer.tileHeight;
	}
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

	writeln("crop");
	// Initialize the coordinates of the top-left and bottom-right corners of the crop
	int xmin = int.max;
	int ymin = int.max;
	int xmax = 0;
	int ymax = 0;

	foreach (i; 0 .. layer.height)
	{
		size_t layerIdxY = (i * layer.width) * 4;

		foreach (x; 0 .. layer.width)
		{
			size_t layerIdxX = layerIdxY + (x * 4);

			// Check if a pixel is not transparent
			if (layerData[layerIdxX + 3] > 0)
			{
				// Update the coordinates of the top-left and bottom-right corners
				if (xmin > x)
					xmin = x;
				if (ymin > i)
					ymin = i;
				if (xmax < x)
					xmax = x;
				if (ymax < i)
					ymax = i;
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
	ubyte[] outData = new ubyte[cropWidth * cropHeight * layer.pixelSize];

	foreach (y; 0 .. cropHeight)
	{
		// Calculate the byte index of the beginning of the current row in composedData
		size_t lineStart = ((ymin + y) * layer.width + xmin) * layer.pixelSize;

		// Calculate the byte index of the beginning of the current row in outData
		size_t outStart = y * cropWidth * layer.pixelSize;

		// Calculate how many bytes to copy for the current row
		size_t runLength = (cropWidth * layer.pixelSize);

		// Copy the relevant pixels from composedData to outData for the current row
		outData[outStart .. outStart + runLength] = layerData[lineStart .. lineStart + runLength];
	}

	layer.left += xmin;
	layer.top += ymin;
	layer.right = layer.left + cropWidth;
	layer.bottom = layer.top + cropHeight;

	layer.data = outData;
}

public:
void extractLayer(ref Layer layer, bool crop)
{
	uint decompressedLength = layer.pixelSize * layer.tileWidth * layer.tileHeight;

	// number of columns and rows in the layer
	int numberOfColumns = layer.width / layer.tileWidth;
	int numberOfRows = layer.height / layer.tileHeight;

	// length of a row in the layer
	int rowLength = numberOfColumns * layer.pixelSize * layer.tileWidth;

	// total length of the composed data
	int composedLength = numberOfColumns * numberOfRows * decompressedLength;
	ubyte[] composedData = new ubyte[composedLength];

	foreach (tile; layer.tiles)
	{
		// expand (decompress) the tile data
		tile.expand(decompressedLength);

		auto unsortedData = tile.expandedData;

		ubyte[] sortedData = new ubyte[decompressedLength];

		uint bytesPerChannel = 1;
		switch (layer.colorMode)
		{
		case ColorMode.RGBA:
			break;
		case ColorMode.RGBA16:
			bytesPerChannel = 2;
			break;
		default:
			assert(0, "Unsupported colormode.");
		}

		// array of indices representing pixel components
		auto pixelVector = iota(0, layer.pixelSize).array;
		swapRanges(pixelVector[0 .. bytesPerChannel], pixelVector[bytesPerChannel * 2 .. $]);

		// area (number of pixels) in each tile
		auto tileArea = layer.tileHeight * layer.tileWidth;

		foreach (area; 0 .. tileArea)
		{
			uint realIndex = 0;
			foreach (pv; pixelVector)
			{
				sortedData[area * layer.pixelSize + realIndex] =
					unsortedData[pv * tileArea + area];
				realIndex++;
			}
		}

		// relative position of the tile within the layer
		int relativeTileLeft = tile.left - layer.left;
		int relativeTileTop = tile.top - layer.top;

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

	// adjust bounds according to location
	layer.left += layer.x;
	layer.top += layer.y;
	layer.right += layer.x;
	layer.bottom += layer.y;
}
