/**
   Structure based on psd-d (https://github.com/inochi2d/psd-d)
*/

module kra.layer;
import kra;
import kra.parser;

import std.file;
import std.stdio;

/**
    Krita blending modes
*/
enum BlendingMode : string
{
	PassThrough = "pass through",
	Normal = "normal",
	Dissolve = "dissolve",
	Darken = "darken",
	Multiply = "multiply",
	ColorBurn = "burn",
	LinearBurn = "linear_burn",
	DarkerColor = "darker color",
	Lighten = "lighter color",
	Screen = "screen",
	ColorDodge = "dodge",
	LinearDodge = "linear_dodge",
	LighterColor = "lighter color",
	Overlay = "overlay",
	SoftLight = "soft_light",
	HardLight = "hard_light",
	VividLight = "vivid_light",
	LinearLight = "linear light",
	PinLight = "pin_light",
	HardMix = "hard mix",
	Difference = "diff",
	Exclusion = "exclusion",
	Subtract = "subtract",
	Divide = "divide",
	Hue = "hue",
	Saturation = "saturation",
	Color = "color",
	Luminosity = "luminize"
}

/**
    The different types of layer
*/
enum LayerType
{
	/**
        Any other type of layer
    */
	Any = 0,

	/**
        An open folder
    */
	OpenFolder = 1,

	/**
        A closed folder
    */
	ClosedFolder = 2,

	/**
        A bounding section divider
    
        Hidden in the UI
    */
	SectionDivider = 3
}

struct Tile
{
package(kra):
public:
	int left;
	int top;
	int compressedLenght;
	ubyte[] compressedData;
}

struct Layer
{
package(kra):
	File filePtr;

public:
	Tile[] tiles;

	Layer[] children;

	/**
     Name of layer
  */
	string name;

	/**
     Bounding box for layer
  */
	union
	{
		struct
		{

			/**
                Top X coordinate of layer
            */
			int top;

			/**
                Left X coordinate of layer
            */
			int left;

			/**
                Bottom Y coordinate of layer
            */
			int bottom;

			/**
                Right X coordinate of layer
            */
			int right;
		}

		/**
            Bounds as array
        */
		int[4] bounds;
	}

	uint numberOfVersion;
	uint pixelSize;
	uint tileWidth;
	uint tileHeight;

	int width;
	int height;

	ubyte[] data;
	ubyte* dataPtr;

	/**
        The type of layer
    */
	LayerType type;

	/**
        Blending mode
    */
	BlendingMode blendModeKey;

	/**
        Opacity of the layer
    */
	int opacity;

	/**
        Whether the layer is visible or not
    */
	bool isVisible;

	/**
     Color mode of layer
  */
	ColorMode colorMode;

	/**
         Gets the size of this layer
     */
	uint[2] size()
	{
		return [
			width,
			height
		];
	}

	/**
        Extracts the layer image
    */
	void extractLayerImage()
	{
		extractLayer(this);
	}

	int x;
	int y;

	string uuid;
}
