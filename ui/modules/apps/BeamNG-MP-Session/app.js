var app = angular.module('beamng.apps');
app.directive('multiplayersession', ['UiUnits', function (UiUnits) {
	return {
		templateUrl: 'modules/apps/BeamNG-MP-Session/app.html',
		replace: true,
		restrict: 'EA',
		scope: true
	}
}]);
app.controller("Session", ['$scope', 'bngApi', function ($scope, bngApi) {
	$scope.init = function() {
		bngApi.engineLua('UI.ready("MP-SESSION")');
	};

	$scope.mpquit = function() {
		bngApi.engineLua('CoreNetwork.resetSession(1)');
	};

	$scope.reset = function() {
		$scope.init();
	};

	$scope.select = function() {
		bngApi.engineLua('setCEFFocus(true)');
	};
}]);

function setPing(ping) {
	document.getElementById("Session-Ping").innerHTML = ping;
}

function setStatus(status) {
	document.getElementById("Session-Status").innerHTML = formatServerName(sanitizeString(status));
}

function setPlayerCount(count) {
	document.getElementById("Session-PlayerCount").innerHTML = count;
}

function sanitizeString(str) {  // VERY basic sanitization.
    console.log(str)
	str = str.replace(/<script.*?<\/script>/g, '');
	str = str.replace(/<button.*?<\/button>/g, '');
	str = str.replace(/<iframe.*?<\/iframe>/g, '');
	str = str.replace(/<a.*?<\/a>/g, '');
    console.log(str)
    return str
}

function formatServerName(string) {
    console.log(string)
    var codes = string.match(/\^.{1}/g) || [],
        indexes = [],
        apply = [],
        tmpStr,
        deltaIndex,
        noCode,
        final = document.createDocumentFragment(),
        i;
    for(i = 0, len = codes.length; i < len; i++) {
        indexes.push( string.indexOf(codes[i]) );
        string = string.replace(codes[i], '\x00\x00');
    }
    if(indexes[0] !== 0) {
        final.appendChild( applyCode( string.substring(0, indexes[0]), [] ) );
    }
    for(i = 0; i < len; i++) {
    	indexDelta = indexes[i + 1] - indexes[i];
        if(indexDelta === 2) {
            while(indexDelta === 2) {
                apply.push ( codes[i] );
                i++;
                indexDelta = indexes[i + 1] - indexes[i];
            }
            apply.push ( codes[i] );
        } else {
            apply.push( codes[i] );
        }
        if( apply.lastIndexOf('^r') > -1) {
            apply = apply.slice( apply.lastIndexOf('^r') + 1 );
        }
        tmpStr = string.substring( indexes[i], indexes[i + 1] );
        final.appendChild( applyCode(tmpStr, apply) );
    }
	$('#TEMPAREA').html(final);
    console.log($('#TEMPAREA').html())
    return $('#TEMPAREA').html();
}
