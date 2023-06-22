# KRA-D
`kra-d` is a port of [libkra](https://github.com/2shady4u/libkra) to D to support basic extraction of layer info and layer data from krita files.

### Dependencies

`dxml` by jmdavis is required

- [https://github.com/jmdavis/dxml](https://github.com/jmdavis/dxml)
- [https://code.dlang.org/packages/dxml](https://github.com/jmdavis/dxml)

## Parsing a document
To parse a Krita document, use `parseDocument` in `kra`.
```d
KRA document = parseDocument("myFile.kra");
```

## Extracting layer data from layer
To extract layer data (textures) from a layer use `Layer.extractLayerImage()`
```d
KRA doc = parseDocument("myfile.kra");
foreach(layer; doc.layers) {
    
    // Skip non-image layers
    if (layer.type != LayerType.Any) continue;

    // Extract the layer image data.
    // The output RGBA output is stored in Layer.data
    layer.extractLayerImage();

    // write_image from imagefmt is used here to export the layer as a PNG
    write_image(buildPath(outputFolder, layer.name~".png"), layer.width, layer.height, layer.data, 4);
}
```
## Current Limitations
The current implementation does not calculate the initial position of the texture, getting the entire layer with a size greater than the size of the visible texture.

---

**Thanks to LunaTheFoxgirl** for the inspiration for the project.
