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
    - colorlabel: int
    - intimeline: int
*/
class BaseLayer : Layer {

    bool collapsed;

    /**
        Opacity of the layer
    */
    int opacity;

    this(T...)(in T attributes) {
        super(attributes);

        collapsed = cast(bool) getAttrValue!int(attributes, "collapsed", 0);
        opacity = getAttrValue!int(attributes, "opacity", 255);
    }

    this(CloneLayerUuid l) {
        super(l);

        collapsed = l.collapsed;
        opacity = l.opacity;
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

        auto compositeOp = getAttrValue!string(attributes, "compositeop", "normal");
        blendModeKey = cast(BlendingMode) compositeOp;
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

        auto colorSpacename = getAttrValue!string(attributes, "colorspacename", "RGBA");
        colorMode = cast(ColorMode) colorSpacename;
    }
}

/** 
    Layer that stores children layers.
    Unused_Parameters:
    - passthrough: int (checks whether its children should blend with subsequent layers outside this group)
*/
class GroupLayer : CompositeLayer
{
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