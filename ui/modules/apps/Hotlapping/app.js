angular.module('beamng.apps')
.directive('hotlapping', ['$filter', '$log', '$interval', function ($filter, $log, $interval) {
  return {
    templateUrl: '/ui/modules/apps/Hotlapping/app.html',
    replace: true,
    restrict: 'EA',
    scope: true,
    link: function (scope, element, $mdDialog)  {

        scope.controlsEnabled = false
        scope.started = false
        scope.times = []
        scope.times.normal = []
        scope.times.snapshot = []
        scope.times.detail = []
        scope.times.best = {lap:'ui.apps.hotlapping.bestLap', duration:'', diff:'', diffColor:''}

        scope.scenarioInfo = {lap:'',wp:''}

        scope.saved = false
        scope.tracklist = [null]

        scope.showSettings = false
        scope.showMarkers = true
        scope.activeAi = false
        scope.detailed = !scope.controlsEnabled
        scope.closed = false
        scope.stop = false
        scope.timer = 0

        scope.manualStopped = false
        scope.noSaveAllowed = false
        scope.noTracks = true
        scope.tackSelectPlaceholder = "..."

        scope.renaming = false
        var originalFilename = ''

        scope.startHotlapping = function () {
            bngApi.engineLua('scenario_quickRaceLoader.uiEventStartHotlapping()')
            scope.resetTimes()

            scope.timer = 0
            scope.started = true
            scope.saved = false
            scope.noSaveAllowed = false
            scope.bestTime = {lap:'ui.apps.hotlapping.bestLap', duration:'', diff:'', diffColor:''}
            bngApi.engineLua('setCEFFocus(false)')
        }

        scope.toggleSettings = function () {
            scope.$evalAsync(() => {
              scope.showSettings = !scope.showSettings
              scope.cancelRename()
              return
            })
        }

        scope.toggleAi = function () {
            scope.activeAi = !scope.activeAi
            if (scope.activeAi) {
                bngApi.engineLua('core_hotlapping.startAi()')
            } else {
                bngApi.engineLua('core_hotlapping.stopAi()')
            }
        }

        scope.toggleVisibility = function () {
            scope.showMarkers = !scope.showMarkers
            bngApi.engineLua('core_hotlapping.setVisible(' + scope.showMarkers + ')')
        }

        scope.$on('RaceLapChange', function (event, data) {
            if(data === null) return
            scope.$applyAsync(function () {
              scope.scenarioInfo.lap = "Lap " + data.current  + " / " + data.count
            })
        })

        scope.$on('WayPoint', function (event, data) {
            if(data === null) return
            scope.$applyAsync(function () {
              scope.scenarioInfo.wp = data
            })
        })

        scope.sizeDown = function () {
            bngApi.engineLua('core_hotlapping.changeSize(-1,true)')
        }

         scope.sizeUp = function () {
            bngApi.engineLua('core_hotlapping.changeSize(1,true)')
        }

         scope.resetSize = function () {
            bngApi.engineLua('core_hotlapping.changeSize(0,true)')
        }

        scope.clearAllCP = function () {
            bngApi.engineLua('core_hotlapping.stopHotlapping()')
            scope.$evalAsync(() => {scope.current=null;})
            scope.started = false
            scope.closed = false
            scope.saved = false
            scope.renaming = false
            scope.activeAi = false
            scope.loadedFile = null
            if(scope.currentLapTimerPromise != null) {
                $interval.cancel(scope.currentLapTimerPromise)
                scope.currentLapTimerPromise = null
            }
        }

        scope.addCheckPoint = function () {
            bngApi.engineLua('core_hotlapping.addCheckPoint()')
            bngApi.engineLua('setCEFFocus(false)')
        }

        scope.stopTimer = function () {
            bngApi.engineLua('core_hotlapping.stopTimer()')
            //scope.manualStopped = true
            scope.started = false
            scope.renaming = false
            scope.activeAi = false
            if(scope.currentLapTimerPromise != null) {
                $interval.cancel(scope.currentLapTimerPromise)
                scope.currentLapTimerPromise = null
            }
        }

        scope.resetTimes = function () {
            scope.$evalAsync(() => {
                scope.timesNormal = []
                scope.timesDetail = []
                scope.timesNormalSnapshot = []
                scope.stop = false
                scope.current = null
                scope.timer = 0
                return
            })
            bngApi.engineLua('core_hotlapping.stopTimer()')
            scope.renaming = false
        }


        /////////////// Problem code begins here /////////////////



        // Gets the tracklist.
         scope.refreshTracklist = function() {
            bngApi.engineLua('core_hotlapping.refreshTracklist()', function(data) {
                if (!data.hasOwnProperty("length")) data = [null]
                scope.$evalAsync(function () {
                    scope.tracklist = data
                    scope.noTracks = data.isEmpty()
                    if(scope.noTracks) {
                        scope.tackSelectPlaceholder = "No tracks found."
                    } else {
                        scope.tackSelectPlaceholder = "Select track..."
                    }
                  })
            })
        }

        // to debug, tries to fill the textbox with "stop".
        scope.stop = function () {
            scope.$evalAsync(function () {
                scope.loadedFile = "stop"
                if(scope.currentLapTimerPromise != null) {
                    $interval.cancel(scope.currentLapTimerPromise)
                    scope.currentLapTimerPromise = null
                }
                return
            })
        }

        // when hovering the textfield, so that you can type
        scope.hoverRenaming = function () {
            scope.$evalAsync(function () {
                if (!scope.renaming) return
                bngApi.engineLua('setCEFFocus(true)')
            })
          }

        //when clicking the textbox
        scope.startRenaming = function () {
            scope.$evalAsync(function () {
                scope.renaming = true
                originalFilename = scope.loadedFile
                bngApi.engineLua('setCEFFocus(true)')
            })
          }

          scope.cancelRename = function () {
            scope.$evalAsync(function () {
                scope.renaming = false
                bngApi.engineLua('setCEFFocus(false)')
                $log.debug('Cancelled rename')
                scope.loadedFile = originalFilename
            })
          }

          scope.acceptRename = function (newName) {
            scope.$evalAsync(function () {
                scope.renaming = false
                if (newName == originalFilename) return
                bngApi.engineLua('core_hotlapping.rename("' + originalFilename + '","' + newName + '")')
                scope.loadedFile = newName
            })

          }

        scope.load = function (selectedFile) {
            bngApi.engineLua('core_hotlapping.load("' + selectedFile + '")')
            scope.loadedFile = selectedFile
            scope.saved = true
        }




        /////////////// Problem code ends here /////////////////

        scope.$on('HotlappingSuccessfullyLoaded',function(event,data) {
            scope.started = true
            scope.closed = true
            scope.saved = true
            scope.noSaveAllowed = true
            scope.bestTime = {lap:'ui.apps.hotlapping.bestLap', duration:'', diff:'', diffColor:''}
            scope.loadedFile = data
        })

        scope.save = function () {
            bngApi.engineLua('core_hotlapping.save()')
        }

        scope.$on('HotlappingSuccessfullySaved',function(event,data) {
             scope.$evalAsync(() => {
                scope.saved = true
                scope.loadedFile = data
                scope.startRenaming()
             })
        })

        scope.lastHotlappingTimerTime = -1
        scope.currentLapTimerPromise = null
        scope.currentLapTimer = function() {
            if (typeof scope.times.snapshot[0] === 'undefined') scope.times.snapshot[0] = {'durationMillis':0}; //FIXME this line just tries to avoid log flooding with errors, needs a proper fix
            var timer = scope.times.snapshot[0]['durationMillis'] + ((new Date).getTime() - scope.lastHotlappingTimerTime)
            var sec_num = parseInt(timer, 10); // don't forget the second param

            var minutes = Math.floor(sec_num / 60000)
            var seconds = Math.floor(sec_num/1000) - (minutes * 60)
            var millis = sec_num % 1000

            if (minutes < 10) {minutes = "0"+minutes;}
            if (seconds < 10) {seconds = "0"+seconds;}
            if (millis < 10)  {millis  = "0"+millis;}
            if (millis < 100) {millis  = "0"+millis;}
            scope.$applyAsync(function() {
                scope.times.snapshot[0]['duration'] = minutes + ":" + seconds + "." + millis
            })
        }

        scope.$on('HotlappingTimerPause', function(event,data) {
            if(scope.currentLapTimerPromise != null) {
                $interval.cancel(scope.currentLapTimerPromise)
                scope.currentLapTimerPromise = null
            }

        })

        scope.$on('HotlappingTimerUnpause', function(event,data) {
            if(scope.currentLapTimerPromise == null) {
                scope.currentLapTimerPromise = $interval(function() {
                    scope.currentLapTimerPromise = $interval(scope.currentLapTimer,50,0)
                },4950,1)
            }

        })
        scope.$on('HotlappingTimer',function (event, data) {
            $log.debug(data)
            var normal = data['normal'].reverse()
            var detail = data['detail'].reverse()



            /**if(scope.manualStopped) {
                //Sync Problem with the "StopHotlapping"-Button,
                //catch this so the state will be set correctly
                scope.started = false
                scope.manualStopped = false
                return
            }**/
            scope.$evalAsync(() => {
                //if(data['stop']) {
                    scope.times.snapshot = normal
                    //scope.stop = true
                    //scope.timer = 5000

                    scope.lastHotlappingTimerTime = (new Date).getTime()
                    if(scope.currentLapTimerPromise != null) {
                        $interval.cancel(scope.currentLapTimerPromise)
                    }
                    if(data['running']) {
                        if(data['justStarted'] || data['justLapped']) {
                            scope.currentLapTimerPromise = $interval(scope.currentLapTimer,50,0)
                        }
                        else {
                            scope.currentLapTimerPromise = $interval(function() {
                                scope.currentLapTimerPromise = $interval(scope.currentLapTimer,50,0)
                            },4950,1)
                        }
                    }
              //  }
                scope.times.normal = normal
                scope.times.detail = detail
                scope.timer -= data['delta']
                scope.closed = data['closed']
                scope.started = true
                if(data['justLapped']) {
                    scope.times.snapshot = normal
                    //scope.stop = false
                    //scope.timer = 0
                    var hasBest = false
                    for (t in normal) {
                        if(normal[t].best) {
                            scope.times.best = normal[t]
                            hasBest = true
                            break
                        }
                    }
                    if(!hasBest)
                        scope.times.best = {lap:'ui.apps.hotlapping.bestLap', duration:'', diff:'', diffColor:''}
                }

               /** if(scope.timer <= 0) {
                    scope.times.snapshot = normal
                    scope.stop = false
                } **/
            })
        })

        scope.$on('HotlappingClosedTrigger',function (event, data) {
            scope.$evalAsync(() => {scope.closed = true;})
        })


        scope.toggleDetail = function () {
            scope.$evalAsync(() => {
               scope.detailed = !scope.detailed
            })
        }


        scope.skip = function () {
            bngApi.engineLua("core_hotlapping.skipLap()")
            if(scope.currentLapTimerPromise != null) {
                $interval.cancel(scope.currentLapTimerPromise)
                scope.currentLapTimerPromise = null
            }
        }

        scope.$on('HotlappingResetApp',function(event, data) {
            $log.debug('ResetApp')
           scope.resetVariables()

        })

        scope.$on('ChangeState',function(event, data) {
            if(data === 'scenario-start') {
                scope.timesNormal=[]
                scope.timesDetail=[]
                scope.timesNormalSnapshot=[]
                scope.stop=false
                scope.current=null
                scope.timer=0
                bngApi.engineLua('core_hotlapping.stopTimer()')
            }
            reevaluateControls()

        })

        scope.$on('setQuickRaceMode',function(event, data) {
            $log.debug('SetQuickRace')
           scope.controlsEnabled = false
        })

        let reevaluateControls = function(){
             bngApi.engineLua('core_gamestate.state and core_gamestate.state.state', function(ret) {
              //console.log("Reevaluating on my own.. State = " + ret)
              scope.controlsEnabled = ret == 'freeroam' || ret == 'multiplayer'
            })
        }

        scope.$on('hotlappingReevaluateControlsEnabled',function(event, data) {
          reevaluateControls()
        })
        reevaluateControls()



        scope.resetVariables = function() {
            scope.started = false
            //scope.selectedFile = null
            scope.times = []
            scope.times.normal = []
            scope.times.snapshot = []
            scope.times.detail = []
            scope.times.best = {lap:'ui.apps.hotlapping.bestLap', duration:'', diff:'', diffColor:''}

            scope.saved = false
            scope.tracklist = []

            scope.showSettings = false
            scope.detailed = false
            scope.closed = false
            scope.stop = false
            scope.timer = 0

            scope.manualStopped = false
            scope.noSaveAllowed = false
            scope.noTracks = true
            scope.tackSelectPlaceholder = "..."
            bngApi.engineLua('core_hotlapping.refreshTracklist()')
            scope.cancelRename()
            if(scope.currentLapTimerPromise != null) {
                $interval.cancel(scope.currentLapTimerPromise)
                scope.currentLapTimerPromise = null
            }
        }

        scope.$on('ChangeState',function(event, data) {
            if(data == 'menu')
                scope.controlsEnabled = true
            else
                scope.controlsEnabled = false
            if(data == 'loading')
                bngApi.engineLua('scenario_quickRaceLoader.uiHotlappingAppDestroyed()')
        })

        scope.$on('newBestRound',function(event,data) {
            if(data.place == 1)
                scope.bestTime = {lap:'ui.apps.hotlapping.bestLap', duration:'', diff:'', diffColor:''}
            scope.loadedFile = data
        })

        bngApi.engineLua('extensions.load("core_hotlapping")')
    }
  }
}]);