/**
   Distributed under the 2-Clause BSD License, see LICENSE file.

   Authors: otrocodigo

   Structure based on psd-d (https://github.com/inochi2d/psd-d)
*/

module kra;
import std.stdio;
import std.zip;

public import kra.parser : parseDocument;
public import kra.layer;

enum ColorMode : string
{
	RGBA = "RGBA",
	RGBA16 = "RGBA16",// RGBAF16,
	// RGBAF32,
	// CMYK,
	// OTHER
}

struct KRA
{
package(kra):

public:

  /**
     Document source
  */
  ZipArchive fileRef;

  /**
     Name of document
  */
  string name;

  /**
    Layers
   */
  Layer[] layers;

  /**
     Color mode of document
  */
  ColorMode colorMode;

  /**
     Width of document
  */
  int width;

  /**
     Height of document
  */
  int height;

  /**
      Get layer from uuid
  */
   Layer getLayer(string uuid) {
      foreach(l; layers) {
         if (l.uuid == uuid)
            return l;
      }
      
      return null;
   }

}
