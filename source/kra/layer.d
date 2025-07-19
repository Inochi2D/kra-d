/**
    Krita Layers and Tiles

    Copyright:
        Copyright © 2021-2025, otrocodingo
        Copyright © 2021-2025, Inochi2D Project

    License:   Distributed under the 2-Clause BSD License, see LICENSE file.
    Authors:
        Luna Nielsen, otrocodigo
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

/**
    The different types of layer
*/
enum LayerType {

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
    SectionDivider = 3,

    /**
        A layer cloned from another
    */
    Clone = 4
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
    A Krita Layer
*/
struct Layer {
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
        Clone data
    */
    string cloneFromUuid;
    Layer* target;

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
        Checks if the layer is a group
        
         Returns:
             Whether the layer is a group
    */
    bool isLayerGroup() {
        return type == LayerType.OpenFolder || type == LayerType.ClosedFolder;
    }

    /** 
        Check whether the layer is useful to clone

        Returns:
            $(D true) if the layer is a clone layer, the layer it clones is available 
            and whether that layer is useful,
            $(D false) otherwise.
    */
    bool isCloneLayerUseful() {
        if (type == LayerType.Clone) {
            if (*target == null)
                return false;
            else
                return *target.isLayerUseful();
        }

        return false;
    }

    /**
        Is the layer useful?
    */
    bool isLayerUseful() {
        return isLayerGroup() || isCloneLayerUseful() || (width != 0 && height != 0);
    }

    /**
        Extracts the layer image
    */
    void extractLayerImage(bool crop = true) {
        extractLayer(this, crop);
    }

    /**
        Sets the cloning target for this layer to the layer
        with the UUID that was provided during load time.
    */
    void setCloneTarget() {
        *target = &getLayer(uuid);
    }

    /**
        UUID of layer
    */
    string uuid;
}
