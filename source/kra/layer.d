/**
    Krita Layers and Tiles

    Copyright:
        Copyright © 2021-2025, otrocodingo
        Copyright © 2021-2025, Inochi2D Project

    License:   Distributed under the 2-Clause BSD License, see LICENSE file.
    Authors:
        Luna Nielsen, otrocodigo, mechPenSketch
*/
module kra.layer;
import kra;
import kra.parser;

import std.file;
import std.stdio;

/** 
	Color-coded labels to distinguish layers in Krita.
	Can also be used in custom UI.
 */
 enum ColorLabel {None, Blue, Green, Yellow, Orange, Brown, Red, Purple, Grey}

/**
    Krita blending modes
*/
enum BlendingMode : string {
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

final class Tile {
private:

    /**
        The left position of the tile
    */
    int _left;

    /**
        The top position of the tile
    */
    int _top;

    /**
        The compressed data
    */
    ubyte[] _compressedData;

    /**
        The expanded (decompressed) data
    */
    ubyte[] _expandedData;

public:
    this(int left, int top, ubyte[] compressedData) {
        this._top = top;
        this._left = left;
        this._compressedData = compressedData;
    }

    /**
        The left position of the tile
    */
    @property int left() const { return _left; }

    /**
        The top position of the tile
    */
    @property int top() const { return _top; }

    /**
        Get the expanded (decompressed) data

        Returns:
            The expanded (decompressed) data
    */
    @property const(ubyte[]) expandedData() const {
        return _expandedData;
    }

    /**
        Method for expanding (decompressing) the compressed data

        Params:
           expandedSize = The expected size after expansion (decompression)
    */
    void expand(int expandedSize) {

        import kra.lzf : lzfDecompress;
        this._expandedData = lzfDecompress(_compressedData, expandedSize);
    }
}

/**
    Encompasses all layers, including masks
    Unused_Parameters:
    - filename: string
    - locked: bool (checks whether the layer is locked from editing)
*/
class Layer {
private:
    File filePtr;

public:

    // Internal properties
    Tile[] tiles;
    int numberOfVersion;
    int pixelSize;
    int tileWidth;
    int tileHeight;
    ubyte* dataPtr;

    /**
        The data of the layer
    */
    ubyte[] data;

    /**
        Name of layer
    */
    string name;

    /**
        Bounding box for layer
    */
    union {
        struct {

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

    /**
        Location for layer
    */
    union {
        struct {
            /**
                X coordinate of layer
            */
            int x;

            /**
                Y coordinate of layer
            */
            int y;
        }

        /**
            Location as array
        */
        int[2] location;
    }

    /**
        Whether the layer is visible or not
    */
    bool isVisible;

    /**
        Sub-layers
    */
    Layer[] children;
    
    /** 
        Constructor using tuples of attributes
    */
    this(T...)(in T attributes) {
        name = getAttrValue!string(attributes, "name", "");
        isVisible = cast(bool) getAttrValue!int(attributes, "visible", 0);
        uuid = getAttrValue!string(attributes, "uuid", "");
        x = getAttrValue!int(attributes, "x", 0);
        y = getAttrValue!int(attributes, "y", 0);

        importAttributes(kra, l.children[0], children);
    }

    /** 
        Constructor using CloneLayerUuid
    */
    this(CloneLayerUuid l) {
        name = l.name;
        isVisible = l.isVisible;
        uuid = l.uuid;
        x = l.x;
        y = l.y;

        children = l.children;
    }

    /**
        Gets the center coordinates of the layer
    */
    uint[2] center() {
        return [
            left + (width / 2),
            top + (height / 2),
        ];
    }

    /**
     * Gets the size of this layer
     */
    uint[2] size() {
        return [
            width,
            height
        ];
    }

    /**
     * Width
     */
    @property uint width() const {
        return right - left;
    }

    /**
     * Height
     */
    @property uint height() const {
        return bottom - top;
    }

    /**
        Is the layer useful?
    */
    bool isLayerUseful() {
        return width != 0 && height != 0;
    }

    /**
        Extracts the layer image
    */
    void extractLayerImage(bool crop = true) {
        extractLayer(this, crop);
    }

    /**
        UUID of layer
    */
    string uuid;
}

/** 
    Base class for all layers, excluding masks
    Unused_Parameters:
    - channelflags: string
    - intimeline: int
*/
class BaseLayer : Layer {

    bool collapsed;

    ColorLabel colorLabel;

    /**
        Opacity of the layer
    */
    int opacity;

    this(T...)(in T attributes) {
        super(attributes);

        collapsed = cast(bool) getAttrValue!int(attributes, "collapsed", 0);
        colorLabel = cast(ColorLabel) getAttrValue!int(attributes, "colorlabel", 0);
        opacity = getAttrValue!int(attributes, "opacity", 255);
    }

    this(CloneLayerUuid l) {
        super(l);

        collapsed = l.collapsed;
        opacity = l.opacity;
    }

	BlendingMode getBlendModeKey(T...)(in T attributes)
	{
		auto compositeOp = getAttrValue!string(attributes, "compositeop", "normal");
		return cast(BlendingMode) compositeOp;
	}

	ColorMode getColorMode(T...)(in T attributes)
	{
		auto colorSpacename = getAttrValue!string(attributes, "colorspacename", "RGBA");
		return cast(ColorMode) colorSpacename;
	}
}

/** 
    For layers with blending mode
*/
class CompositeLayer : BaseLayer
{

    /**
        Blending mode
    */
    BlendingMode blendModeKey;

    this(T...)(in T attributes)
    {
        super(attributes);

		blendModeKey = getBlendModeKey(attributes);
	}

    this(CloneLayerUuid l)
    {
        super(l);

        blendModeKey = l.blendModeKey;
    }
}

/**
    Layer for raster drawing
    Unused_Parameters:
    - channellockflags: int
    - onionskin: int (for viewing other frames in animation)
*/
class PaintLayer : CompositeLayer
{
    /**
        Color mode of layer
    */
    ColorMode colorMode;

    this(T...)(in T attributes)
    {
        super(attributes);

        colorMode = getColorMode(attributes);
    }
}

/** 
    Layer that stores children layers.
*/
class GroupLayer : CompositeLayer
{
    /** 
	    Checks whether its children layers should be rendered individually.
	    This affects how they blend with subsequent layers outside
	    of this group.
	*/
	bool canPassThrough;

	this(T...)(in T attributes)
	{
		super(attributes);

		canPassThrough = cast(bool) getAttrValue!int(attributes, "passthrough", 0);
	}
    
    override bool isLayerUseful()
    {
        return true;
    }
}

/** 
    Layer that clones another. It directly links to the target layer.
*/
class CloneLayer : CompositeLayer
{
    /** 
        The layer it clones from.
    */
    Layer cloneFrom;

    this(CloneLayerUuid l)
    {
        super(l);

        string target_uuid = l.cloneFromUuid;
        cloneFrom = getLayer(kra.layers, target_uuid);
    }

    override bool isLayerUseful()
    {
        return cloneFrom.isLayerUseful();
    }
}

/** 
    Layer with an UUID to its target layer. To be replaced by CloneLayer in parse finalization.
    Unused_Parameters:
    - clonefrom: string (name of the target clone)
    - clonetype: int (layer type of the target clone)
*/
class CloneLayerUuid : CompositeLayer
{
    /** 
        UUID of the layer it clones from.
    */
    string cloneFromUuid;

    this(T...)(in T attributes)
    {
        super(attributes);

        cloneFromUuid = getAttrValue!string(attributes, "clonefromuuid", "");
    }
}

/**
 * Layer for vector drawing.
 */
class VectorLayer : CompositeLayer {}

/**
 * Layer for filling the whole canvas.
 *
 * Unused params:
 * 	* generatorname: string (name of the type of fill used)
 *		* list: color, gradient, multigrid, pattern, screentone, seexpr, simplexnoise
 * 	* generatorversion: string (version of the fill used)
 * 	* selected: bool
 */
class FillLayer : CompositeLayer {}

/**
 * Layer for diaplaying an image file.
 *
 * Unused params:
 * 	* selected: bool
 * 	* scalingmethod: int (an enum of how the file is scaled)
 *		* Enum: None, ToImageSize, ToImagePPI
 * 	* source: string (link to the file)
 */
class FileLayer : CompositeLayer
{
	/**
	 * Color mode of layer
	 */
	ColorMode colorMode;

	this(T...)(in T attributes)
	{
		super(attributes);

		colorMode = getColorMode(attributes);
	}
}

/**
 * Layer for applying filter to subsequent layers.
 *
 * Unused params:
 * 	* filtername: string (name of the type of filter used)
 * 	* filterversion: string (version of the filter used)
 * 	* selected: bool
 */
class FilterLayer : BaseLayer
{
	/**
	 * Blending mode
	 */
	BlendingMode blendModeKey;

	this(T...)(in T attributes)
	{
		super(attributes);

		blendModeKey = getBlendModeKey(attributes);
	}
}

/**
 * Mask for coloring line art.
 *
 * Unused params:
 * 	* cleanup: int (in percentage, the extent the mask removes keys strokes placed outside closed contours)
 * 	* edge-detection-size: int (thinnest line width to seperate different colors)
 *	* edit-keystroke: int (checks whether the mask can be edited by stroke)
 * 	* fuzzy-radius: int (how blurry the edge is)
 * 	* limit-to-device: int (checks whether the coloring is bound by device's screen size)
 * 	* use-edge-detection: int (checks whether there should be a limit to line thickness that seperates different color)
 */
class ColorizeMask : BaseLayer
{
	/**
	 * Blending mode
	 */
	BlendingMode blendModeKey;

	/**
	 * Color mode of layer
	 */
	ColorMode colorMode;

	bool showColoring;

	this(T...)(in T attributes)
	{
		super(attributes);

		blendModeKey = getBlendModeKey(attributes);
		colorMode = getColorMode(attributes);

		showColoring = cast(bool) getAttributes!int(attributes, "show-coloring", 0);
	}
}

/**
 * Mask for applying transform effect.
 */
class TransformMask : BaseLayer {}

/**
 * Mask for applying filter on certain areas.
 *
 * Unused params:
 * 	* filtername: string (name of the type of filter used)
 * 	* filterversion: string (version of the filter used)
 */
class FilterMask : BaseLayer {}

/**
 * Mask for apply transparancy on certain areas.
 */
class TransparancyMask : BaseLayer {}

/**
 * Refernce for selecting certain areas.
 *
 * Unused params:
 * 	* active: bool
 */
class SelectionMask : BaseLayer
{
	/** 
	 * This layer is not useful.
	 */
	override bool isLayerUseful()
	{
		return false;
	}
}