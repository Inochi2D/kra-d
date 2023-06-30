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

final class Tile
{
package(kra):
private:
	/**
	 * The left position of the tile
	 */
	int _left;

	/**
	 * The top position of the tile
	 */
	int _top;

	/**
	 *  The compressed data
	 */
	ubyte[] _compressedData;

	/**
	 * The expanded (decompressed) data
	 */
	ubyte[] _expandedData;

public:
	this(int left, int top, ubyte[] compressedData)
	{
		this._top = top;
		this._left = left;
		this._compressedData = compressedData;
	}

	/**
	 * Get the left position of the tile
	 *
	 * Returns: The left position of the tile
	 */
	@property int left() const
	{
		return _left;
	}

	/**
	 * Get the top position of the tile
	 *
	 * Returns: The top position of the tile
	 */
	@property int top() const
	{
		return _top;
	}

	/**
	 * Get the expanded (decompressed) data
	 *
	 * Returns: The expanded (decompressed) data
	 */
	@property const(ubyte[]) expandedData() const
	{
		return _expandedData;
	}

	/**
	 * Method for expanding (decompressing) the compressed data
	 *
	 * Params:
	 *     expandedSize = The expected size after expansion (decompression)
	 */
	void expand(int expandedSize)
	{
		import kra.lzf;

		this._expandedData = lzfDecompress(_compressedData, _compressedData.length, expandedSize);
	}
}

struct Layer
{
package(kra):
	File filePtr;

public:
	// Internal properties
	Tile[] tiles;
	uint numberOfVersion;
	uint pixelSize;
	uint tileWidth;
	uint tileHeight;
	ubyte* dataPtr;

	/**
	 * The data of the layer
	 */
	ubyte[] data;

	/**
	 *  Name of layer
	*/
	string name;

	/**
	 * Bounding box for layer
	 */
	union
	{
		struct
		{

			/**
			 * Top X coordinate of layer
			 */
			int top;

			/**
			 * Left X coordinate of layer
			 */
			int left;

			/**
			 * Bottom Y coordinate of layer
			 */
			int bottom;

			/**
			 * Right X coordinate of layer
			 */
			int right;
		}

		/**
		 * Bounds as array
		 */
		int[4] bounds;
	}

	/**
	 * The type of layer
	 */
	LayerType type;

	/**
	 * Blending mode
	 */
	BlendingMode blendModeKey;

	/**
	 * Opacity of the layer
	*/
	int opacity;

	/**
	 * Whether the layer is visible or not
	*/
	bool isVisible;

	/**
	 * Color mode of layer
	 */
	ColorMode colorMode;

	/**
	 * Gets the center coordinates of the layer
	 */
	uint[2] center()
	{
		return [
			left + (width / 2),
			top + (height / 2),
		];
	}

	/**
	 * Gets the size of this layer
	 */
	uint[2] size()
	{
		return [
			width,
			height
		];
	}

	/**
	 * Width
	 */
	@property uint width() const
	{
		return right - left;
	}

	/**
	 * Height
	 */
	@property uint height() const
	{
		return bottom - top;
	}

	/**
	 * Check if the layer is a group
	 * Returns: if the layer is a group
	 */
	bool isLayerGroup()
	{
		return type == LayerType.OpenFolder || type == LayerType.ClosedFolder;
	}

	/**
	 * Is the layer useful?
	 */
	bool isLayerUseful()
	{
		return !isLayerGroup() && (width != 0 && height != 0);
	}

	/**
	 * Extracts the layer image
	 */
	void extractLayerImage(bool crop = true)
	{
		extractLayer(this, crop);
	}

	/**
	 * UUID of layer
	 */
	string uuid;
}
