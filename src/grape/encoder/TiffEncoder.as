package grape.encoder {
    import flash.display.*;
    import flash.filesystem.FileStream;
    import flash.geom.*;
    import flash.utils.*;
        
    public class TiffEncoder {
        
        private var imgCache:Array = new Array(); 

        /**
         * キャッシュから探す
         * @param url エンコード対象のファイルのURL
         */
        private function search(url:String) :Object {
            for each (var obj:Object in imgCache) {
                if (obj.url == url) {
                    return obj;
                } 
            }
            return null;
        }
        
        /**
         * 
         */ 
        public function decode(data:FileStream, interval:int, url:String = null): BitmapData {
            if (url != null) {
                var obj:Object = search(url);
                if (obj != null) {
                    return obj.img;
                }
            }
            
            var c1:uint;
            var c2:uint;
			var c3:uint;
			var c4:uint;				

			// 0 - 1 byte order
            c1 = data.readUnsignedByte();            
            c2 = data.readUnsignedByte();
			if (c1 == 73 && c2 == 73) {
            	data.endian = "littleEndian";			
			} else if (c1 == 79 && c2 == 79) {
				data.endian = "bigEndian";
			} else {
				// unknown byte order
				return null;
			}

			// 2 - 3 TIFF を表す固定値 49 
			data.readUnsignedByte();
			data.readUnsignedByte();
			
			// 4 - 5 IFD pointer
			c1 = data.readUnsignedByte();
			c2 = data.readUnsignedByte();
			
			// IFD pointer まで読み飛ばし
			data.readBytes(new ByteArray(), 0, (c2 * 256 + c1) - 6);

			// IFD: entry count
			c1 = data.readUnsignedByte();
			c2 = data.readUnsignedByte();
			var ifdEntryCount:uint = c2 * 256 + c1;
			// IFD entry の処理
			var ifdEntries:Array = new Array();
			for (var i:int = 0; i < ifdEntryCount; i++) {
				var entry:Object = new Object();
				// tag
				c1 = data.readUnsignedByte();
				c2 = data.readUnsignedByte();
				entry.tag = c2 * 256 + c1;
				// type
				c1 = data.readUnsignedByte();
				
				c2 = data.readUnsignedByte();
				entry.type = c2 * 256 + c1;
				// count field
				c1 = data.readUnsignedByte();
				c2 = data.readUnsignedByte();
				c3 = data.readUnsignedByte();
				c4 = data.readUnsignedByte();
				entry.countField = c4  * 256 * 256 * 256 + c3 * 256 * 256 + c2 * 256 + c1;
				// data field
				c1 = data.readUnsignedByte();
				c2 = data.readUnsignedByte();
				c3 = data.readUnsignedByte();
				c4 = data.readUnsignedByte();
				entry.dataField = c4  * 256 * 256 * 256 + c3 * 256 * 256 + c2 * 256 + c1;
				ifdEntries.push(entry);
			}

			
			function getEntry(entries:Array, tag:uint) :Object {
				var entry:Object;
				entries.forEach(function (elem:Object, index:int, length:int) :void {
 					if (tag == elem.tag) {
						entry =  elem;
					} 
				});	
				return entry;
		    }

			// ImageWidth[256]			
			var ImageWidth = getEntry(ifdEntries, 256).dataField;
            var Width:uint = getEntry(ifdEntries, 256).dataField / interval;
            // 端数 (丸められた横のバイト数)
            var brokenNum:uint = getEntry(ifdEntries, 256).dataField - Width * interval;
            // ImageLength[257] 
            var Height:uint = getEntry(ifdEntries, 257).dataField / interval;
            // StripOffsets[273]
            var StripOffsets = getEntry(ifdEntries, 273).dataField;
            // SamplesPerPixel[277]
            var SamplesPerPixel = getEntry(ifdEntries, 277).dataField;
			// RowsPerStrip[278] 
			var RowsPerStrip = getEntry(ifdEntries, 278).dataField;
			// StripByteCounts[279]
			var StripByteCounts = getEntry(ifdEntries, 279).dataField;

			// bitmapデータの生成
            var img: BitmapData;
			var imgData:ByteArray = new ByteArray();
			imgData.endian = Endian.BIG_ENDIAN;
			data.readBytes(new ByteArray(), 0, StripOffsets - data.position); // StripOffsets まで読み飛ばし
            data.readBytes( imgData, 0, StripByteCounts);
            
            img = new BitmapData( Width, Height, false, 0xFFFFFFFF );
            var ymargin:uint = (interval - 1) * ImageWidth * 3;
            var xmargin:uint = (interval - 1) * SamplesPerPixel;
            var brokenmargin:uint = brokenNum * SamplesPerPixel;
            

            for( var i: int = 0; i < Height; i++ ) {
				imgData.position += ymargin;
                for( var j: int = 0; j < Width; j++ ) {
                    imgData.position += xmargin;
                    var color: uint = imgData.readUnsignedInt() >> 8;
                    img.setPixel( j, i, color );
                    imgData.position--;
                }
            	imgData.position += brokenmargin; 
            }
            
            imgCache.push({url:url, img:img})
            return img;
        }

    }

}