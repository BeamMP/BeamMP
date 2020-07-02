angular.module('beamng.apps')
.directive('radialmenu', ['bngApi', 'mdx', '$http',"$translate", function (bngApi, mdx, $http,$translate) {
  return {
    template: `
    <div ng-show="rvisible" ng-cloak ng-mousemove='mouseMove($event)' ng-mousedown='mouseDown($event)' style="position:relative;width:100%; height:100%;text-align:center;">
        <svg style="width:100%; height:100%; margin:0px 0px; padding:0; /*-webkit-filter: url(#f1);*/" version="2" xmlns="http://www.w3.org/2000/svg"  ng-mouseleave="mouseLeave($event)" >
          <defs>
            <filter id="grayscale">
              <feColorMatrix type="saturate" values="0"/>
            </filter>
            <!--<filter id="f1" x="0" y="0" height="200%" width="200%">
              <feOffset result="offOut" in="SourceAlpha" dx="0" dy="0"></feOffset>
              <feGaussianBlur result="blurOut" in="offOut" stdDeviation="10"></feGaussianBlur>
              <feBlend in="SourceGraphic" in2="blurOut" mode=""></feBlend>
            </filter>-->
          </defs>
        </svg>
        <div ng-if="false" ng-cloak style="padding:5px; bottom:0; left:0; width:auto; position:absolute; pointer-events:none;background-color:rgba(0,0,0,0.4);color:white;" layout="row" layout-align="start center">
          <div ng-if="controller == 'gamepad'  && false">
            <binding action="menu_item_select" style="margin: 0 5px;"></binding> select
            <binding action="menu_item_back" style="margin: 0 5px;"></binding> back
          </div>
          <div ng-if="controller != 'gamepad' && false">
            Left click: select - Right click: back
          </div>
        </div>
    </div>`,
    replace: true,
    restrict: 'EA',
    link: function (scope, element, attrs) {
      var root = element[0];
      var svg  = root.children[0];
      var svgDef = svg.children[0];

      var size = 400; // BeamMP Edit, Original Value: 200
      var centerX = size * 0.5;
      var centerY = size * 0.5;

      var deadZone = 0.3;
      var deadZoneOrg = deadZone;
      var radius1 = size * deadZone;
      var radius2 = size * 0.45;
      var sliceCount = 8;
      var sliceOffsetAngle = size/220 * Math.PI*2 / 360;
      var fontSizeTXT;

      var accent     = "rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][600].value.toString()+", 1.00)"
      var accentLight= "rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][400].value.toString()+", 0.85)"
      var accentLight2="rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][200].value.toString()+", 0.85)"
      var accentLight3="rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][100].value.toString()+", 0.85)"
      var primary    = "rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().primary   ][400].value.toString()+", 0.85)"
      var primaryLight="rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().primary   ][100].value.toString()+", 0.85)"
      var background = 'rgba(0,0,0,0.9)'; // "rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().background][700].value.toString()+", 0.85)"
      var warn       = "rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().warn      ][400].value.toString()+", 0.85)"
      var sliceFocusColor = accentLight;
      sliceUnfocusColor = background;
      var backgroundColor = "rgba(130,131,134,0.9)";
      var backgroundBars = 'rgba(0,0,0,0.7)';
      var NewAccentLight= "rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][400].value.toString()+", 0.35)";
      var NewAccentLight2LeRetour= "rgba("+mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][400].value.toString()+", 0.7)";
      var rgb = mdx.mdxThemeColors._PALETTES[mdx.getCurrentTheme().accent    ][400].value;
      var NewAccentLight3= "rgba(" + (rgb[0]*.40).toFixed(0) + ", ";
      NewAccentLight3+= (rgb[1]*.37).toFixed(0) + ", ";
      NewAccentLight3+= (rgb[2]*.37).toFixed(0) + ", 0.8)";

      var angleOffset = 0; // - 45 deg

      var slices = [];
      var sliceTexts = [];
      var slicesSelected=[];
      var DescTexts = [];

      var itm = []; // all hu items
      var circle = null; // middle user thingy
      //var userLine = null;
      var iconSlices = [];

      var catBG = null;
      var catText = null;
      var descBG = null;
      var descText = null;
      var menuTxt = [];
      var itemTxt = null;
      var itemSecLineTxt = null;
      var descTxt = null;
      var descMaxSize = size;

      var focus = null;
      var initialized = false;

      var lx = 0;
      var ly = 0;

      // var currSlowMo = 1;   // value used to store current slowmo speed

      scope.rvisible = false;
      scope.enabled = false;
      scope.data = null;


      var luaIconMap = {
        'radial_Drift_ESC': 'radial_drift_ESC',
        'radial_Sport_ESC': 'radial_sport_ESC',
        'radial_Regular_ESC': 'radial_regular_ESC',
        'radial_ESC': 'radial_regular_ESC'
      }

      function getIconName (name) {
        return luaIconMap[name] || name;
      }

      bngApi.engineLua('core_quickAccess and core_quickAccess.isEnabled()', (enabled) => {
        scope.enabled = enabled;
      });

      // Enable slowmo when radial menu is opened
      scope.$on('quickAccessEnabled', (ev, d) => {
        // bngApi.engineLua('bullettime.requestValue()')
        // if (d) {
        //   bngApi.engineLua('bullettime.get()', (val) => {   // get slowmo speed before entering menu (to ensure users current speed is kept consistent)
        //     currSlowMo = val;
        //   })
        //   bngApi.engineLua('bullettime.set(' + 0.1 + ')');
        // }
        // else {
        //   bngApi.engineLua('bullettime.set(' + currSlowMo + ')');
        // }
        scope.enabled = d;
        // console.log(d);
      });


      function hide() {
        console.log("HIDE");
        bngApi.engineLua('core_quickAccess.resetTitle()');
        // for now, dashboard JS is the authoritative source for whether menues are open or not. always hide radial menu through it
        HookManager.trigger('MenuToggle', false);
      }

      function paintSVG(svgdata, color){
        if(svgdata.childNodes === 'undefined'){return;}
        for( si in svgdata.childNodes){
          var e = svgdata.childNodes[si]
          if(typeof e.style !== 'undefined'){
            if(typeof e.style.fill !== 'undefined' && e.style.fill !== "none" && e.style.fill !== ""){e.style.fill = color;}
            if(typeof e.style.stroke !== 'undefined' && e.style.stroke !== "none" && e.style.stroke !== ""){e.style.stroke = color;}
          }
          paintSVG(e, color)
        }
      }

      //use the parent element of ElTxt (element from hu)
      function cssTextHighlight(ElTXT, bool)
      {
        var elst = ElTXT.n.parentElement.style;
        elst['fill'] = bool?"white":'grey';
        elst['font-size'] = fontSizeTXT* (bool?1:0.75);
        elst['font-family'] = 'Play';
        elst['color']= bool?"white":'grey';
        elst['white-space']= "normal";
        elst['margin']="0px";
      }

      function SvgTextLimit(El, m)
      {
        while(El.n.getComputedTextLength() > m){
          El.n.style.fontSize = (parseFloat(window.getComputedStyle(El.n, null).fontSize)*0.9).toFixed(1)+"px";
          //t =El.n.innerHTML;
          //El.text(t.substr(0,t.length-5)+"..."  );
        }
      }

      function refreshMenuTitle()
      {
        var max = size * (0.39*2+0.212)/2 * 2* Math.PI /12;
        if( menuTxt=== [] || menuTxt.length !== 3 ){console.log("refreshMenuTitle not ready");return;}
        if(scope.data.title.length < 3){
          cssTextHighlight(menuTxt[0], true);
          cssTextHighlight(menuTxt[2], false);
        }
        else{
          cssTextHighlight(menuTxt[0], false);
          cssTextHighlight(menuTxt[2], true);
        }

        switch(scope.data.title.length){
          case 0:
            scope.data.title =["MAIN Err"];
          case 1:
            menuTxt[0].text($translate.instant(scope.data.title[0]));
            menuTxt[2].text("");
            menuTxt[1].text("");
          break;
          case 2:
            menuTxt[1].text($translate.instant(scope.data.title[0]));
            menuTxt[0].text($translate.instant(scope.data.title[1]));
            menuTxt[2].text("");
          break;
          default: //3 or more
            var l = scope.data.title.length;
            menuTxt[1].text($translate.instant(scope.data.title[l-3]));
            menuTxt[0].text($translate.instant(scope.data.title[l-2]));
            menuTxt[2].text($translate.instant(scope.data.title[l-1]));
          break;
        }

        for(var i=0; i<menuTxt.length; i++ )
        {
          SvgTextLimit(menuTxt[i], max)
        }
      }

      function format4itemTXT(txt,max)
      {
        if(txt.indexOf('\\n') !==-1){
          var sp = txt.split('\\n');
          itemTxt.text(sp[0]);
          itemTxt.n.style.fontSize = fontSizeTXT;
          SvgTextLimit(itemTxt, max);
          itemSecLineTxt.text(sp[1]);
          itemSecLineTxt.n.style.fontSize = fontSizeTXT;
          SvgTextLimit(itemSecLineTxt, max*0.9);
        }
        else{
          itemTxt.text(txt);
          itemTxt.n.style.fontSize = fontSizeTXT;
          SvgTextLimit(itemTxt, max);
          itemSecLineTxt.text("");
        }
      }

      function redraw() {
        centerX = size * 0.5;
        centerY = size * 0.5;
        offset = size * 0.02;
        radius1 = size * 0.212 - offset;
        radius2 = size * 0.39 - offset;
        radius4 = size * 0.19;
        radius1noOf = size * 0.212;
        radius2noOf = size * 0.39;
        //console.log("r1",radius1,"r2",radius2,"r3",radius3,"r4",radius4,'r1o',radius1noOf,'r2o',radius2noOf);

        var radius3 = radius1 + (radius2 - radius1) * 0.6;

        fontSizeTXT = size / 22;


        // remove any old items
        for(var it in itm) {
          itm[it].remove();
        }
        itm = [];
        slices = [];
        sliceTexts = [];
        slicesSelected = [];
        DescTexts = [];
        iconSlices = [];
        menuTxt = [];

        /*var s = hu('<style>', svg).text("@font-face {font-family: 'Material_Icons'; font-style: normal; font-weight: 400; src: local('Material Icons'), url(common/MaterialIcons-Regular.ttf);}");
        itm.push(s);


        //defs for icon*/
        var svgSize = size * 0.1;
        var fontSizeMat = svgSize;
        var textMatCSS = {};
        textMatCSS['fill'] = 'grey';
        textMatCSS['font-size'] = fontSizeMat;
        textMatCSS['font-family'] = 'Material_Icons';

        // empty?
        //console.log('redrawing with data:', scope.data)
        if(scope.data === null) {
          //hide();
          return;
        }


        sliceCount = scope.data.items.length
        if(sliceCount == 0) {
          //hide();
          return;
        }
        /*if(sliceCount <= 2 || sliceCount > 4) {
          if (sliceCount%2===0 && sliceCount > 4 ){
            angleOffset = - Math.PI * 2/sliceCount;} // - fix back button to be in the middle
          else{
            angleOffset = - Math.PI * 0.5;} // - 90 deg
        } else if (sliceCount === 4) {
          angleOffset = - Math.PI * 0.25; // - 45 deg
        }else{
          angleOffset = -Math.PI * 0.5}; // - 90 deg*/

        if(sliceCount%2 ===0){
          if(sliceCount===2){
            angleOffset = 0;
          }else{
            angleOffset = -Math.PI * 0.5 + (scope.data.canGoBack?Math.PI/sliceCount:0);}
          }
        else{
          angleOffset = -Math.PI * 0.5;
        }

        //console.log("canGoBack",scope.data.canGoBack, "sliceCount", sliceCount , "angleOffset", angleOffset, (angleOffset*180/Math.PI));

        // if we have only one item, preselect it
        if(sliceCount == 1) {
          focus = 0;
        }

        //backgroundcircle
        circle = hu('<circle>', svg).attr({
            cx: centerX,
            cy: centerY,
            r: radius2noOf,
            fill: backgroundColor,
            stroke: 'white',
            strokeWidth: 0,
        });
        itm.push(circle);

        sliceOffsetAngle = offset/20 * Math.PI / 180;

        var animationTranslation = 15;
        for(i = 0; i < sliceCount; i++) {
          var d = scope.data.items[i];
          var sliceAngle = (Math.PI * 2) / sliceCount;
          var startAngle = i * sliceAngle + angleOffset;
          var endAngle = (i + 1) * sliceAngle + angleOffset;
          var midAngle = startAngle + (endAngle - startAngle) * 0.5;
          if (sliceCount == 1) endAngle -= 0.001; // allow svg path to determine arc position if start/end are equal

          var sx2 = (centerX) + Math.cos(startAngle+sliceOffsetAngle) * radius2noOf;
          var sy2 = (centerY) + Math.sin(startAngle+sliceOffsetAngle) * radius2noOf;

          var sx1 = (sx2) - Math.cos(startAngle) * (radius2-radius4);
          var sy1 = (sy2) - Math.sin(startAngle) * (radius2-radius4);

          var ex2 = (centerX) + Math.cos(endAngle-sliceOffsetAngle) * radius2noOf;
          var ey2 = (centerY) + Math.sin(endAngle-sliceOffsetAngle) * radius2noOf;

          var ex1 = (ex2) - Math.cos(endAngle) * (radius2-radius4);
          var ey1 = (ey2) - Math.sin(endAngle) * (radius2-radius4);

          //console.log(sx1,sy1,sx2,sy2,ex1,ey1,ex2,ey2);
          // the animation translation
          var animTransX = Math.cos(midAngle) * animationTranslation;
          var animTransY = Math.sin(midAngle) * animationTranslation;

          var textX = centerX + Math.cos(midAngle) * radius3;
          var textY = centerY + Math.sin(midAngle) * radius3;

          var largeArcFlag = sliceCount < 2 ? 1 : 0; // draw bigger arc if there's just one item in menu (180+deg arc), or small arc otherwise

          var fillColor = sliceUnfocusColor;
          //if(d.color) fillColor = d.color;
          //console.log("size/500",size/500);
          var s = hu('<path>', svg).attr({
            d: "M " + sx1 + "," + sy1 + " L" + sx2 + "," + sy2 +
            " A" + radius2noOf  + "," + radius2noOf  + " 0 "+largeArcFlag+",1 " + ex2 + "," + ey2 +
            " L " + ex1 + "," + ey1 +
            " A" + (radius1noOf-(sliceCount===2?radius1-radius4:0)) + "," + (radius1noOf-(sliceCount===2?radius1-radius4:0)) + " 0 "+largeArcFlag+",0 " + sx1 + "," + sy1
            ,
            //fill: "#"+((1<<24)*Math.random()|0).toString(16),
            fill: fillColor,
            orgColor: fillColor,
            stroke: '#333',
            strokeWidth: 0,
            strokeLinecap: "round",
            animTranslate: 'translate(' + animTransX  + ',' + animTransY + ')'
          });
          slices.push(s);
          itm.push(s);

          //css clip path
          /*var def = hu('<defs>', svg).attr({ });
          itm.push(def);
          var mask = hu('<mask>', def).attr({
            id: "mask"+i,
          });
          itm.push(mask);
          var s = hu('<path>', mask).attr({
            d: "M " + (centerX+offsetx) + "," + (centerY+offsety) + " L" + sx2 + "," + sy2 +
            " A" + (radius2) + "," + radius2 + " 0 "+largeArcFlag+",1  " + ex2 + "," + ey2 +
            " L " + (centerX+offsetx) + "," + (centerY+offsety)
            ,
            fill: 'rgba(255,0,0,1)',
            stroke: '#rgba(255,0,255,1)',
            strokeWidth: 0,
            strokeLinecap: "round",
            //animTranslate: 'translate(' + animTransX  + ',' + animTransY + ')'
          });
          itm.push(s);

          circle = hu('<circle>', mask).attr({
            cx: centerX,
            cy: centerY,
            r: radius4,
            fill: 'rgba(0,0,255,1)',
            stroke: 'white',
            strokeWidth: 0,
          });
          itm.push(circle);

          circle = hu('<circle>', svg).attr({
            cx: centerX,
            cy: centerY,
            r: radius2noOf,
            fill: 'green',
            orgColor: 'green'/,
            stroke: 'white',
            strokeWidth: 0,
            mask : "url(#mask"+i+")",
          });
          itm.push(circle);
          slices.push(circle);
          break;*/

          // slice text
          /*var g = hu('<g>', svg).attr({
            transform: `translate(${textX}, ${textY})`
          })

          itm.push(g);

          var textCSS = {};
          textCSS['fill'] = 'white';
          textCSS['font-size'] = fontSizeTXT;
          textCSS['font-family'] = 'Roboto';
          //textCSS['font-weight'] = 'bold';
          textCSS['text-anchor'] = 'middle';

          var s = hu('<text>', g).css(textCSS);
          s.text(d.title)*/
          //sliceTexts.push(s);
          //itm.push(s);
          sliceTexts.push(d.title);
          if( d.desc === undefined){
            DescTexts.push("");
          }else{
            DescTexts.push(d.desc);
          }

          // console.log(s);
        }


        //selected pie thing
        var sliceAngle = (Math.PI * 2) / sliceCount;
        var startAngle = -sliceAngle/2;
        var endAngle = sliceAngle/2;
        var midAngle = startAngle + (endAngle - startAngle) * 0.5;
        var largeArcFlag = sliceCount < 2 ? 1 : 0;
        var sx2 = (centerX) + Math.cos(startAngle+sliceOffsetAngle) * radius2noOf;
        var sy2 = (centerY) + Math.sin(startAngle+sliceOffsetAngle) * radius2noOf;

        var sx1 = (sx2) - Math.cos(startAngle) * (radius2-radius4);
        var sy1 = (sy2) - Math.sin(startAngle) * (radius2-radius4);

        var ex2 = (centerX) + Math.cos(endAngle-sliceOffsetAngle) * radius2noOf;
        var ey2 = (centerY) + Math.sin(endAngle-sliceOffsetAngle) * radius2noOf;

        var ex1 = (ex2) - Math.cos(endAngle) * (radius2-radius4);
        var ey1 = (ey2) - Math.sin(endAngle) * (radius2-radius4);
        //console.log(centerX, Math.cos(startAngle),startAngle , radius1)
        var s = hu('<path>', svg).attr({
            d: "M " + sx1 + "," + sy1 + " L" + sx2 + "," + sy2 +
            " A" + radius2noOf  + "," + radius2noOf  + " 0 "+largeArcFlag+",1 " + ex2 + "," + ey2 +
            " L " + ex1 + "," + ey1 +
            " A" + (radius1noOf-(sliceCount===2?radius1-radius4:0)) + "," + (radius1noOf-(sliceCount===2?radius1-radius4:0)) + " 0 "+largeArcFlag+",0 " + sx1 + "," + sy1
            ,
            //fill: "#"+((1<<24)*Math.random()|0).toString(16),
            fill: NewAccentLight,
            orgColor: NewAccentLight,
            stroke: '#333',
            strokeWidth: 0,
            strokeLinecap: "round",
          }).css({cursor:"pointer"});
        slicesSelected.push(s)
        itm.push(s);

        //little thingy between slices and center
        //console.log("radius int", radius4, "radius ext", radius1, "radius ext+off", radius1+offset);
        var sx2 = sx1;
        var sy2 = sy1;

        var sx1 = (sx2) - Math.cos(startAngle) * offset;
        var sy1 = (sy2) - Math.sin(startAngle) * offset;
        //console.log("s1", sx1,sy1,Math.cos(startAngle) * (radius1-offset), Math.sin(startAngle) * (radius1-offset));

        var ex2 = ex1;
        var ey2 = ey1;

        var ex1 = (ex2) - Math.cos(endAngle) * offset;
        var ey1 = (ey2) - Math.sin(endAngle) * offset;

        var s = hu('<path>', svg).attr({
            d: "M " + sx1 + "," + sy1 + " L" + sx2 + "," + sy2 +
            " A" + (radius1noOf-(sliceCount===2?radius1-radius4:0))  + "," + (radius1noOf-(sliceCount===2?radius1-radius4:0))  + " 0 "+largeArcFlag+",1 " + ex2 + "," + ey2 +
            " L " + ex1 + "," + ey1 +
            " A" + (radius1-(sliceCount===2?radius1-radius4:0)) + "," + (radius1-(sliceCount===2?radius1-radius4:0)) + " 0 0,0 " + sx1 + "," + sy1
            ,
            //fill: "#"+((1<<24)*Math.random()|0).toString(16),
            fill: NewAccentLight2LeRetour,
            orgColor: NewAccentLight2LeRetour,
            stroke: '#333',
            strokeWidth: 0,
            strokeLinecap: "round",
            "transition-property": "transform" ,
            "transition-duration": "5s",
            "transition-timing-function": "linear",
          }).css({cursor:"pointer"});
        slicesSelected.push(s)
        itm.push(s);


        // TODO: icons
        for(i = 0; i < sliceCount; i++) {
          var d = scope.data.items[i];
          var sliceAngle = (Math.PI * 2) / sliceCount;
          var startAngle = i * sliceAngle + angleOffset;
          var endAngle = (i + 1) * sliceAngle + angleOffset;
          var midAngle = startAngle + (endAngle - startAngle) * 0.5;
          if (sliceCount == 1) endAngle -= 0.001; // allow svg path to determine arc position if start/end are equal

          var textX = centerX + Math.cos(midAngle) * radius3;
          var textY = centerY + Math.sin(midAngle) * radius3;

          if (d.icon  !== undefined) {
            iconFound = false;
            if(d.icon.indexOf(".svg")!==-1 ){
              iconFound = true;
              var g = hu('<g>', svg).attr({
                transform: `translate(${textX-svgSize/2}, ${textY-svgSize/2})`
              });
              itm.push(g);
              $http({
                    method: 'GET',
                    url: "modules/apps/RadialMenu/mods_icons/"+d.icon,
                    parentEl: g,
                    name: d.icon.substring(0, d.icon.length - 4),
                    indexSlices: i,
                    selected: d.color
                  }).then(function successCallback(response) {
                      var template = document.createElement('template');
                      template.innerHTML = response.data;
                      template.content.firstElementChild.id = response.config.name;
                      template.content.firstElementChild.width.baseVal.value = svgSize;
                      template.content.firstElementChild.height.baseVal.value = svgSize;
                      if(response.config.selected||focus===response.config.indexSlices){paintSVG(template.content.firstElementChild, response.config.selected);}else{paintSVG(template.content.firstElementChild, "grey");}
                      response.config.parentEl.n.appendChild(template.content.firstElementChild);
                      response.config.parentEl.n.firstElementChild.style.cursor ="pointer";
                      iconSlices[response.config.indexSlices]=response.config.parentEl.n.firstElementChild;
                      updateFocus();
                    }, function errorCallback(response) {
                      console.log("Failed to load SVG Icon for a mod. URL=",response.config.url);
                    });
            }else{ if(d.icon.indexOf(".png")!==-1){
              iconFound = true;
              var g = hu('<image>', svg).attr({
                transform: `translate(${textX-svgSize}, ${textY-svgSize})`,
                /*"max-width": svgSize,
                "max-height": svgSize,*/
                width: svgSize*2,
                height: svgSize*2,
              }).css({cursor:"pointer"});
              itm.push(g);
              g.n.setAttributeNS("http://www.w3.org/1999/xlink", "href", "../"+d.icon);
              g.n.setAttribute("filter", "url(#grayscale)");
              iconSlices[i]=g.n;
            }else{
              //new method svg symbol
              var u = hu('<use>', svg).attr({
                x: textX-svgSize/2,
                y: textY-svgSize/2,
                href: "#" + getIconName(d.icon),
                width: svgSize,
                height: svgSize,
              }).css({fill: d.color?d.color:"grey"});
              u.n.setAttributeNS("http://www.w3.org/1999/xlink", "href", "#"+getIconName(d.icon)); //xlink: deprecaded in svg2
              itm.push(u);
              iconSlices[i]=u.n;
              iconFound = true;
              //old method
            /*for(il in IconList){
              if(IconList[il].name.toLowerCase() === d.icon.toLowerCase()){
                if(IconList[il].material === undefined || IconList[il].material === null){
                  var g = hu('<g>', svg).attr({
                    transform: `translate(${textX-svgSize/2}, ${textY-svgSize/2})`
                  });
                  itm.push(g);
                  $http({
                    method: 'GET',
                    url: IconList[il].url,
                    parentEl: g,
                    Index: il,
                    indexSlices: i,
                    selected: d.color
                  }).then(function successCallback(response) {
                      var template = document.createElement('template');
                      template.innerHTML = response.data;
                      template.content.firstElementChild.id = IconList[response.config.Index].name;
                      template.content.firstElementChild.width.baseVal.value = svgSize;
                      template.content.firstElementChild.height.baseVal.value = svgSize;
                      if(response.config.selected||focus===response.config.indexSlices){paintSVG(template.content.firstElementChild, "white");}else{paintSVG(template.content.firstElementChild, "grey");}
                      response.config.parentEl.n.appendChild(template.content.firstElementChild);
                      response.config.parentEl.n.firstElementChild.style.cursor ="pointer";
                      iconSlices[response.config.indexSlices]=response.config.parentEl.n.firstElementChild;
                      updateFocus();
                    }, function errorCallback(response) {
                      // called asynchronously if an error occurs
                      // or server returns response with an error status.
                    });
                  iconFound = true;
                }
                else{
                  var g = hu('<g>', svg).attr({
                    transform: `translate(${textX-fontSizeMat/2}, ${textY+fontSizeMat/2})`
                  });
                  itm.push(g);
                  var t = hu('<text>', g).attr({id: IconList[il].name}).css(textMatCSS).text(IconList[il].material);
                  t.n.innerHTML = IconList[il].material; //fix HU library escaping the & to &amp;
                  t.n.style.cursor ="pointer";
                  if(typeof d.color !== undefined){t.n.style.fill="grey";}
                  itm.push(t);
                  iconSlices[i]=t.n;
                  iconFound = true;
                }
                break;
              }
            }*/
          }}
            if(!iconFound)console.log("Waning: Icon not found for :",d.icon);

          }


        }

        //Category selected
        var radiusCat1 = size *0.43;
        var radiusCat2 = size *0.5;
        var radiusCat3 = radiusCat1 + (radiusCat2 - radiusCat1) * 0.5;
        var startAngle = (-Math.PI /4) *3;
        var endAngle = -Math.PI /4;

        var sx1 = (centerX) + Math.cos(startAngle) * radiusCat1;
        var sy1 = (centerY) + Math.sin(startAngle) * radiusCat1;

        var sx2 = (centerX) + Math.cos(startAngle) * radiusCat2;
        var sy2 = (centerY) + Math.sin(startAngle) * radiusCat2;

        var ex1 = centerX + Math.cos(endAngle) * radiusCat1;
        var ey1 = centerY + Math.sin(endAngle) * radiusCat1;

        var ex2 = centerX + Math.cos(endAngle) * radiusCat2;
        var ey2 = centerY + Math.sin(endAngle) * radiusCat2;

        var textX = centerX ;
        var textY = centerY - radiusCat3;

        catBG = hu('<path>', svg).attr({
          d: "M" + sx1 + "," + sy1 + " L" + sx2 + "," + sy2 +
          " A" + radiusCat2 + "," + radiusCat2 + " 0 0,1 " + ex2 + "," + ey2 +
          " L " + ex1 + "," + ey1 +
          " A" + radiusCat1 + "," + radiusCat1 + " 0 0,0 " + sx1 + "," + sy1
          ,
          fill: backgroundBars,
          orgColor: backgroundBars,
          stroke: '#333',
          strokeWidth: 0,
          strokeLinecap: "round",
        });
        itm.push(catBG);

        var p1 = hu('<path>', svgDef).attr({
          d: "M" + ((sx1*2+sx2)/3) + "," + ((sy1*2+sy2)/3) +
          " A" + ((radiusCat2+radiusCat1*2)/3) + "," + ((radiusCat2+radiusCat1*2)/3) + " 0 0,1 " + ((ex1*2+ex2)/3) + "," + ((ey1*2+ey2)/3)   ,
          id:"pathCat",
        });
        //console.log("sx1",sx1,"sx2",sx2,"sy1",sy1,"sy2",sy2,"ex1",ex1,"ex2",ex2);
        itm.push(p1);


        var textCSS = {};
        textCSS['fill'] = 'white';
        textCSS['font-size'] = fontSizeTXT;
        textCSS['font-family'] = 'Play';
        //textCSS['font-weight'] = 'bold';
        textCSS['text-anchor'] = 'middle';
        textCSS['color']= "white";
        textCSS['white-space']= "normal";
        textCSS['margin']="0px";
        textCSS['vertical-align']= "middle";

        //text simple
        /*var g = hu('<g>', svg).attr({
          transform: `translate(${textX}, ${textY+fontSizeTXT/3})`
        })
        itm.push(g);

        menuTxt = hu('<text>', g).css(textCSS);
        itm.push(menuTxt);
        menuTxt.text(scope.data.title);*/

        //hu attrib only work for svg namespace
        var g = hu('<text>', svg).css({
          'text-anchor': 'middle',
          'vertical-align': "middle",
        });
        itm.push(g);
        menuTxt[0]= hu('<textPath>', g) ;
        menuTxt[0].n.setAttributeNS("http://www.w3.org/1999/xlink", "href", "#pathCat");
        menuTxt[0].n.setAttribute("startOffset","50%");
        itm.push(menuTxt[0]);
        //menuTxt[0].text(scope.data.title);
        cssTextHighlight(menuTxt[0], true);

        var g = hu('<text>', svg)/*.css(textCSS2)*/;
        itm.push(g);
        menuTxt[1]= hu('<textPath>', g) ;
        menuTxt[1].n.setAttributeNS("http://www.w3.org/1999/xlink", "href", "#pathCat");
        menuTxt[1].n.setAttribute("startOffset","2%");
        menuTxt[1].n.setAttribute("text-anchor","start");
        itm.push(menuTxt[1]);
        cssTextHighlight(menuTxt[1], false);

        var g = hu('<text>', svg)/*.css(textCSS2)*/;
        itm.push(g);
        menuTxt[2]= hu('<textPath>', g) ;
        menuTxt[2].n.setAttributeNS("http://www.w3.org/1999/xlink", "href", "#pathCat");
        menuTxt[2].n.setAttribute("startOffset","98%");
        menuTxt[2].n.setAttribute("text-anchor","end");
        itm.push(menuTxt[2]);
        cssTextHighlight(menuTxt[2], false);

        refreshMenuTitle();

        //description bottom
        startAngle = Math.PI /4;
        endAngle = (Math.PI /4) *3;

        sx1 = (centerX) + Math.cos(startAngle) * radiusCat1;
        sy1 = (centerY) + Math.sin(startAngle) * radiusCat1;

        sx2 = (centerX) + Math.cos(startAngle) * radiusCat2;
        sy2 = (centerY) + Math.sin(startAngle) * radiusCat2;

        ex1 = centerX + Math.cos(endAngle) * radiusCat1;
        ey1 = centerY + Math.sin(endAngle) * radiusCat1;

        ex2 = centerX + Math.cos(endAngle) * radiusCat2;
        ey2 = centerY + Math.sin(endAngle) * radiusCat2;

        textX = centerX + Math.cos(midAngle) * radiusCat3;
        textY = centerY + Math.sin(midAngle) * radiusCat3;

        descBG = hu('<path>', svg).attr({
          d: "M" + sx1 + "," + sy1 + " L" + sx2 + "," + sy2 +
          " A" + radiusCat2 + "," + radiusCat2 + " 0 0,1 " + ex2 + "," + ey2 +
          " L " + ex1 + "," + ey1 +
          " A" + radiusCat1 + "," + radiusCat1 + " 0 0,0 " + sx1 + "," + sy1
          ,
          fill: backgroundBars,
          orgColor: backgroundBars,
          stroke: '#333',
          strokeWidth: 0,
          strokeLinecap: "round",
        });
        itm.push(descBG);

        var p1 = hu('<path>', svgDef).attr({
          d: "M" + ((ex1+ex2*2)/3) + "," + ((ey1+ey2*2)/3) +
          " A" + ((radiusCat2*2+radiusCat1)/3) + "," + ((radiusCat2*2+radiusCat1)/3) + " 0 0,0 " + ((sx1+sx2*2)/3) + "," + ((sy1+sy2*2)/3)   ,
          id:"pathDesc",
        });
        itm.push(p1);

        var g = hu('<text>', svg).css({fill:"white",'font-family':'News Cycle','font-size': fontSizeTXT*0.75, 'letter-spacing':"1px" });
        itm.push(g);
        descTxt= hu('<textPath>', g) ;
        descTxt.n.setAttributeNS("http://www.w3.org/1999/xlink", "href", "#pathDesc");
        descTxt.n.setAttribute("startOffset","50%");
        descTxt.n.setAttribute("text-anchor","middle");
        itm.push(descTxt);
        descMaxSize = ((radiusCat2+radiusCat1*2)/3) * Math.PI / 2;

/*
        userLine = hu('<line>', svg).attr({
          x1: centerX,
          y1: centerY,
          x2: centerX,
          y2: centerY,
          stroke: 'rgba(200,200,200,0.8)',
          strokeWidth: 12,
          strokeLinecap: "round",
        });
        itm.push(userLine);

*/

        //center circle
        circle = hu('<circle>', svg).attr({
            cx: centerX,
            cy: centerY,
            r: radius4,
            fill: fillColor,
            stroke: 'white',
            strokeWidth: 0,
        });
        itm.push(circle);

        var w = radius4*1.8;
        g = hu('<g>', svg).attr({
          transform: `translate(${centerX}, ${centerY+fontSizeTXT/3})`
        })
        itm.push(g);
        itemTxt = hu('<text>', g).css(textCSS);
        itm.push(itemTxt);
        g = hu('<g>', svg).attr({
          transform: `translate(${centerX}, ${centerY+fontSizeTXT*1.6})`
        })
        itm.push(g);
        itemSecLineTxt = hu('<text>', g).css(textCSS);
        itm.push(itemSecLineTxt);

        /*mainText.style.left = (centerX - radius4) + "px";
        mainText.style.top = (centerY-radius4/3) + "px";
        mainText.style.width = radius4*2 + "px";
        mainText.style.height = radius4 + "px";
        mainText.style.fontSize = fontSizeTXT + "px";*/

        /*var f = hu('<foreignObject>', g).attr({
           width:200,
           height:200,
           requiredFeatures:"http://www.w3.org/TR/SVG11/feature#Extensibility",
        })
        itm.push(f);
        itemTxt = document.createElement('p');
        itemTxt.style.color="white";
        itemTxt.style.fontSize= fontSizeTXT+"px";
        console.log("fontSizeTXT",fontSizeTXT);
        itemTxt.style.fontFamily= "Play";
        itemTxt.style.textAlign= "middle";
        itemTxt.style.whiteSpace= "normal";
        itemTxt.style.margin="0px";
        itemTxt.style.verticalAlign= "middle";
        f.n.appendChild(itemTxt)*/


        /*circle = hu('<circle>', svg).attr({ //removed cursor
            cx: centerX,
            cy: centerY,
            r: size * 0.015,
            fill: '#333',
            stroke: 'white',
            strokeWidth: 2,
        });
        itm.push(circle);*/

        initialized = true;

        updateFocus();
      }

      function updateFocus() {

        if(!initialized) return;
        var px = centerX;
        var py = centerY;
        var valid = false;

        if(scope.controller == 'gamepad') {
          var x = lx;
          var y = ly;
          // console.log(lx, ly, deadZoneOrg);

          deadZone = deadZoneOrg;
          valid = true;

          // console.log(x, y);

          px = centerX + (size * 0.3) * x; //(2 * x - 1);
          py = centerY - (size * 0.3) * y; //(2 * y - 1);
          // console.log(px, py);
        } else if(scope.controller == 'mouse') {
          px = lx;
          py = ly;
          valid = true;
          if(deadZone != 0.1) {
            deadZone = 0.1;
            redraw();
          }
        }

        // disable the slice selection in the deadzone
        var dx = Math.pow(Math.abs(px - centerX), 2) + Math.pow(Math.abs(py - centerY), 2);
        if(Math.abs(dx) < radius1noOf * radius1noOf || Math.abs(dx)>(radius2noOf*radius2noOf)) {
          valid = false;
        }

        /*circle.attr({ //removed cursor
         cx: px,
         cy: py,
         fill: valid ? 'white' : '#333',
        });*/
        circle.attr({ //removed cursor
         fill: valid/*||(Math.abs(dx)>(radius2*radius2))*/ ? sliceUnfocusColor : NewAccentLight3,
        });

        //console.log(px,py," int=",(Math.abs(dx) < radius1noOf * radius1noOf), " ext=",( Math.abs(dx)>(radius2noOf*radius2noOf)) );

        var radius3 = size * 0.4;
        var angle_draw = Math.atan2(py - centerY, px - centerX);

        // the comparison angle is a bit spacial as we need to rotate it correctly to match up with the drawn slices
        // also we need to fix the atan going from -PI to PI whereas we want from 0 to 2 PI
        var angle_comp = angle_draw - angleOffset;
        if(angle_comp < 0) {
          angle_comp += Math.PI * 2;
        }
        var x2 = centerX + Math.cos(angle_draw) * radius3;
        var y2 = centerY + Math.sin(angle_draw) * radius3;


        if(!valid) {
          // if not moving put the line in the middle
          x2 = centerX;
          y2 = centerY;

          // defocus old slice
          if(focus !== null && iconSlices[focus]) {
            /*slices[focus].attr({
              fill: slices[focus].attr('orgColor'),
            });*/
            if(iconSlices[focus].nodeName === "text"){
              iconSlices[focus].style.fill = scope.data.items[focus].color?scope.data.items[focus].color:"grey";}
            else{if(iconSlices[focus].nodeName === "svg"){
              paintSVG(iconSlices[focus], scope.data.items[focus].color?scope.data.items[focus].color:"grey");}
              else{if(iconSlices[focus].nodeName === "image"){
                iconSlices[focus].setAttribute("filter", scope.data.items[focus].color?"":"url(#grayscale)");
              }else{if(iconSlices[focus].nodeName === "use"){
                iconSlices[focus].style.fill = scope.data.items[focus].color?scope.data.items[focus].color:"grey";
              }}}
            }
          }
          focus = null;
          itemTxt.text("");
          itemSecLineTxt.text("");
          descTxt.text("");
          //itemTxt.innerHTML="";
          slicesSelected[0].attr({visibility:  'hidden'});
          slicesSelected[1].attr({visibility:  'hidden'});
        }


        if(scope.controller == 'gamepad') {
          /*
          userLine.attr({
            x2: x2,
            y2: y2
          });
          */
        }

        // now detect which slice got the focus
        var oldFocus = focus;
        if(valid) {
          focus = null;
          for(i = 0; i < sliceCount; i++) {
            var sliceAngle = (Math.PI * 2) / sliceCount;
            var startAngle = i * sliceAngle;
            var endAngle = (i + 1) * sliceAngle;
            if(angle_comp >= startAngle && angle_comp < endAngle) {
              focus = i;
              break;
            }
          }
          //we get the svg a bit late so we need to apply the colr latter when the svg is loaded
          if(iconSlices[focus] && iconSlices[focus].nodeName === "svg"){paintSVG(iconSlices[focus], "white");}
        }
        if(focus != oldFocus) {
          // defocus old
          if(/*oldFocus !== null &&*/ iconSlices[oldFocus]) {
            /*slices[oldFocus].attr({
              fill: slices[oldFocus].attr('orgColor'),
            });*/
            if(iconSlices[oldFocus].nodeName === "text"){
              iconSlices[oldFocus].style.fill = scope.data.items[oldFocus].color?scope.data.items[oldFocus].color:"grey";}
            else{if(iconSlices[oldFocus].nodeName === "svg"){
              paintSVG(iconSlices[oldFocus], scope.data.items[oldFocus].color?scope.data.items[oldFocus].color:"grey");}
              else{if(iconSlices[oldFocus].nodeName === "image"){
                iconSlices[oldFocus].setAttribute("filter", scope.data.items[oldFocus].color?"":"url(#grayscale)");
              }else{if(iconSlices[oldFocus].nodeName === "use"){
                iconSlices[oldFocus].style.fill = scope.data.items[oldFocus].color?scope.data.items[oldFocus].color:"grey";
              }}}
            }

          }
          itemTxt.text("");
          itemSecLineTxt.text("");
          descTxt.text("");
          //itemTxt.innerHTML="";
          // focus new
          if(focus !== undefined && sliceTexts[focus] !== undefined) {
            /*slices[focus].attr({
              fill: sliceFocusColor,
            });*/
            if( sliceTexts[focus].indexOf("ui.radialmenu2.") !== -1){
              format4itemTXT($translate.instant(sliceTexts[focus]), radius4*1.95);
              descTxt.text($translate.instant(sliceTexts[focus]+".desc"));
            }
            else{
              format4itemTXT(sliceTexts[focus], radius4*1.95);
              descTxt.text(DescTexts[focus]);
            }
            SvgTextLimit(descTxt, descMaxSize);

            //itemTxt.innerHTML=sliceTexts[focus];
            var sliceAngle = (360/slices.length);
            var angle = sliceAngle*focus+ (angleOffset*180/Math.PI) + sliceAngle/2;
            var angleold = sliceAngle*oldFocus+ (angleOffset*180/Math.PI) + sliceAngle/2 ;
            //console.log("oldFocus=", oldFocus, "focus=", focus, "  slice angle=", sliceAngle, " angle=", angle );
            slicesSelected[0].attr({visibility: 'visible',
            transform: 'rotate( '+angle+' , '+centerX+', '+centerY+' )' });
            slicesSelected[1].attr({visibility: 'visible',
            transform: 'rotate( '+angle+' , '+centerX+', '+centerY+' )' });
            ///transform rotation
            if(iconSlices[focus] !== undefined){
              if(iconSlices[focus].nodeName === "text"){
                iconSlices[focus].style.fill = "white";}
              else{if(iconSlices[focus].nodeName === "svg"){
                paintSVG(iconSlices[focus], "white");}
                else{if(iconSlices[focus].nodeName === "image"){
                  iconSlices[focus].setAttribute("filter", "");
                }else{if(iconSlices[focus].nodeName === "use"){
                iconSlices[focus].style.fill = "white";
                }}}
              }
            }
            else{console.log("no icon ",sliceTexts[focus],"#",focus);}

            if(iconSlices[oldFocus] !== undefined) {
              if(iconSlices[oldFocus].nodeName === "text"){
                iconSlices[oldFocus].style.fill = scope.data.items[oldFocus].color?scope.data.items[oldFocus].color:"grey";}
              else{if(iconSlices[oldFocus].nodeName === "svg"){
                paintSVG(iconSlices[oldFocus], scope.data.items[oldFocus].color?scope.data.items[oldFocus].color:"grey");}
                else{if(iconSlices[oldFocus].nodeName === "image"){
                  iconSlices[oldFocus].setAttribute("filter", scope.data.items[oldFocus].color?"":"url(#grayscale)");
                }else{if(iconSlices[oldFocus].nodeName === "use"){
                  iconSlices[oldFocus].style.fill = scope.data.items[oldFocus].color?scope.data.items[oldFocus].color:"grey";
                }}}
              }

            }
          }

        }

      }

      function selectItem() {
        if(!scope.rvisible) return;
        //console.log('selectItem', focus)
        if(focus === null) return;
        /*slices[focus].attr({
          transform: slices[focus].attr('animTranslate')
        })*/
        /*sliceTexts[focus].attr({
          transform: slices[focus].attr('animTranslate')
        })*/
        //setTimeout(function() {
        bngApi.engineLua('core_quickAccess.selectItem(' + (focus + 1) + ')'); // js arrays start at 0, Lua's at 1
        //}, 200)
      }

      function goBack() {
        if(!scope.rvisible) return;
        bngApi.engineLua('core_quickAccess.back()');
      }


      // direct binding via the input system
      scope.$on('MenuItemNavigation', function (event, action, value) {
        // console.log(scope.enabled);
        if(!scope.rvisible || !scope.enabled) return;

        switch (action) {
          case 'radial-x':
             scope.controller = 'gamepad';
             ly = Math.max(Math.min(ly ,1),-1);
             lx = Math.max(Math.min( value * Math.sqrt(1 - 0.5* Math.pow(ly, 2) ) ,1),-1);
             bngApi.engineLua('core_quickAccess.moved()');
             break;
          case 'radial-y':
             scope.controller = 'gamepad';
             lx = Math.max(Math.min(lx ,1),-1);
             ly = Math.max(Math.min( value * Math.sqrt(1 - 0.5* Math.pow(lx, 2) ) ,1),-1);
             bngApi.engineLua('core_quickAccess.moved()');
             break;
          case 'back':
            goBack();
            break;
          case 'confirm':
            selectItem();
            break;
        }

        updateFocus();
        //console.log('Got action: ', action, value);
      });

      scope.mouseMove = function(event) {
        if(!scope.rvisible) return;
        if(scope.$parent.$parent.editMode)return;
        scope.controller = 'mouse';
        //console.log('mouseMove: ', event);
        lx = event.layerX;
        ly = event.layerY;
        updateFocus();
      }

      scope.mouseDown = function(event) {
        //console.log(event);
        if(!scope.rvisible) return;
        if(scope.$parent.$parent.editMode)return;
        if(event.button == 0) {
          // left click
          selectItem();
        } else if(event.button == 2) {
          // right click
          goBack();
        }
      }

      scope.mouseLeave = function(event){
        if(!scope.rvisible) return;
        if(scope.$parent.$parent.editMode)return;
        scope.controller = 'mouse';
        //console.log('mouseLeave: ', event);
        lx = event.layerX;
        ly = event.layerY;
        updateFocus();
      }

      var container = element[0].closest('.bng-app');
      /*if (!scope.$parent.$parent.editMode)
        container.classList.add('no-mouse');*/

      scope.$on('QuickAccessMenu', function (event, data) {
        //console.log('QuickAccessMenu', data);
        // reset some things

        scope.$apply(function(){

          focus = null;
          scope.rvisible = (data !== null && data !== undefined);
          if (!scope.rvisible) return;
          scope.data = data;
          if (data !== null || scope.$parent.$parent.editMode) {
            container.classList.remove('no-mouse');
          } else {
            container.classList.add('no-mouse');
          }
        });
        redraw();
      });

      scope.$on('app:resized', function (event, data) {
        var help = Math.min(data.width, data.height);
        size = help > 0 ? help : 0;
        var leftVal = data.width-40>size?(data.width-size)/2:0;
        angular.element(root).css({
          height: `${size}px`,
          width: `${size}px`,
          left: `${leftVal}px`,
        });

        redraw();
      });
    }
  };
}]);
