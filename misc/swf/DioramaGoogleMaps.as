// Diorama Google Maps
//-------------------------------------------------------------------
// This flash changes google maps to tilt-shift photography.
// inspired by http://reinit.info/blog/archive/2011/02/23/tiltshift_2/
package {
import flash.events.*;
import flash.display.*;
import flash.geom.*;
import flash.filters.*;
import com.google.maps.*;
import com.google.maps.geom.*;
import com.google.maps.controls.*;
import com.google.maps.services.*;
import com.bit101.components.*;
import caurina.transitions.Tweener;

public class DioramaGoogleMaps extends Sprite {
    private static var WIDTH:Number = 475;
    private static var HEIGHT:Number = 475;
    private static var BLUR_PARAM:Number = 160;
    private static var CONTROL_ALPHA:Number = 0.3;

    private var maps:Array = [];
    private var controls:Sprite;

    public function DioramaGoogleMaps():void {
        stage.scaleMode = "noScale";
        stage.align = "TL";
        stage.stageFocusRect = false;

        // blured map
        var map1:Map3D = createMap(true);
        map1.filters = [new BlurFilter(10, 10), getSaturationFilter(2.8)];
        addChild(map1);

        // normal map
        var map2:Map3D = createMap(false);
        map2.filters = [getSaturationFilter(1.4)];
        map2.cacheAsBitmap = true;
        addChild(map2);

        var msk:Sprite = new Sprite();
        msk.graphics.beginFill(0);
        msk.graphics.drawEllipse(-WIDTH * 0.5, -HEIGHT * 0.3, WIDTH * 1.0, HEIGHT * 0.6);
        msk.graphics.endFill();
        msk.x = WIDTH * 0.5
        msk.y = HEIGHT * 0.5
        msk.filters = [new BlurFilter(BLUR_PARAM, BLUR_PARAM)];
        msk.cacheAsBitmap = true;
        addChild(msk);
        map2.mask = msk;

        maps = [map1, map2];

        // limb darkening
        filters = [new GlowFilter(0, 0.3, BLUR_PARAM, BLUR_PARAM, 1, 1, true)];

        // add control
        initControl();
    }

    private function initControl():void{
        controls = new Sprite();
        var search:Sprite = new Sprite();
        search.x = 240; search.y = 10;
        search.scaleX = search.scaleY = 1.5;

        // text
        var txt:InputText = new InputText(controls, 0, 0);
        txt.width = 100;
        txt.addEventListener("keyDown", function(event:KeyboardEvent):void{
            if (event.keyCode == 13) { btn.dispatchEvent(new Event("click")); }
        });
        search.addChild(txt);

        // button
        var btn:PushButton = new PushButton(search, 100, 0, "Search", function(event:Event):void{
            var geo:ClientGeocoder = new ClientGeocoder();
            geo.geocode(txt.text);
            geo.addEventListener("geocodingsuccess", function(event:GeocodingEvent):void{
                var marks:Array = event.response.placemarks;
                var map:Map3D = maps[0] as Map3D;
                if (marks.length > 0){
                    map.flyTo(marks[0].point, 15, new Attitude(20, 30, 0), 1);
                }
            });
            geo.addEventListener("geocodingfailure", function(event:GeocodingEvent):void{
                txt.text = "NOT FOUND";
            });
        });
        btn.width = 50; btn.height = txt.height;
        controls.addChild(search);
        addChild(controls);

        controls.alpha = CONTROL_ALPHA;
        controls.addEventListener("mouseOver", function(event:Event):void { Tweener.addTween(controls, {alpha: 0.9, time: 0.5 }); });
        controls.addEventListener("mouseOut",  function(event:Event):void { Tweener.addTween(controls, {alpha: CONTROL_ALPHA, time: 0.5 }); })
    }

    // create a map
    private function createMap(isBlur:Boolean):Map3D{
        var map:Map3D = new Map3D();
        map.key = "ABQIAAAA6de2NwhEAYfH7t7oAYcX3xRWPxFShKMZYAUclLzloAj2mNQgoRQZnk8BRyG0g_m2di3bWaT-Ji54Lg";
        map.sensor = "false";
        map.setSize(new Point(WIDTH, HEIGHT));
        map.addEventListener(MapEvent.MAP_PREINITIALIZE, function(event:Event):void{
            map.setInitOptions(new MapOptions({
                zoom: 17,
                center: new LatLng(48.873847, 2.29502),
                mapType: MapType.SATELLITE_MAP_TYPE,
                viewMode: View.VIEWMODE_ORTHOGONAL,
                attitude: new Attitude(20,30,0),
                doubleClickMode: MapAction.ACTION_PAN_ZOOM_IN,
                mouseClickRange: 2
            }));
        });

        map.addEventListener(MapEvent.MAP_READY, function(event:Event):void{
            if (!isBlur){
                var control:NavigationControl = new NavigationControl(new NavigationControlOptions({
                    position: new ControlPosition(ControlPosition.ANCHOR_TOP_LEFT, 5)
                }));
                map.addControl(control);

                // move to control sprite
                var obj:DisplayObject = control.getDisplayObject();
                if (obj.parent){
                    obj.parent.removeChild(obj);
                    controls.addChild(obj);
                }
            }
        });

        map.addEventListener("mapevent_movestep", changeHandler);
        map.addEventListener("mapevent_moveend", changeHandler);
        map.addEventListener("mapevent_zoomend", changeHandler);
        map.addEventListener("mapevent_attitudechangeend", changeHandler);
        map.addEventListener("mapevent_attitudechangestep", changeHandler);

        return map;
    }

    // sync two map
    private function changeHandler(event:Event):void{
        if(maps.length != 2) return;

        var me:Map3D = event.target as Map3D;
        var other:Map3D = (me == maps[0] ? maps[1] : maps[0]) as Map3D;

        var c1:LatLng = me.getCenter();
        var z1:Number = me.getZoom();
        var a1:Attitude = me.getAttitude();

        if(!c1.equals(other.getCenter())){
            other.setCenter(c1);
        }
        if(z1 != other.getZoom()){
            other.setZoom(z1);
        }
        if(!a1.equals(other.getAttitude())){
            other.setAttitude(a1)
        }
    }

    private static var LUMINANCE_R:Number = 0.212671;
    private static var LUMINANCE_G:Number = 0.715160;
    private static var LUMINANCE_B:Number = 0.072169;

    private function getSaturationFilter(saturation:Number):BitmapFilter{
        var sf:Number = saturation;
        var nf:Number = 1-sf;
        var nr:Number = LUMINANCE_R * nf;
        var ng:Number = LUMINANCE_G * nf;
        var nb:Number = LUMINANCE_B * nf;
        return new ColorMatrixFilter([
            nr+sf,  ng,     nb,     0,  0,
            nr,     ng+sf,  nb,     0,  0,
            nr,     ng,     nb+sf,  0,  0,
            0,      0,      0,      1,  0
        ]);
    }
}
}