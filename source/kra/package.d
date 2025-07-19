/**
   Krita for DLang

   This module provides facilities for importing and manipulating Krita documents.

   Copyright:
      Copyright © 2021-2025, otrocodingo
      Copyright © 2021-2025, Inochi2D Project

   License:   Distributed under the 2-Clause BSD License, see LICENSE file.
   Authors:
      Luna Nielsen, otrocodigo
*/

module kra;
import std.stdio;
import std.zip;

public import kra.parser : parseDocument;
public import kra.layer;

/**
   Possible color modes that a Krita document may be using.
*/
enum ColorMode : string {
   RGBA = "RGBA",
   RGBA16 = "RGBA16", // RGBAF16,
   // RGBAF32,
   // CMYK,
   // OTHER
}

/**
   A Krita Document
*/
struct KRA {
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

      Params:
         uuid = The uuid to query
      
      Returns:
         A layer with the given UUID,
         $(D null) on failure.
   */
   Layer getLayer(string uuid) {
      foreach (l; layers) {
         if (l.uuid == uuid)
            return l;
      }

      return null;
   }
}
