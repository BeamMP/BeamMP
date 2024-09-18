import { onCondition, inPath } from "./resourceLoader.js"

const paths = {
  MAIN_ENTRYPOINT: '/ui/entrypoints/main',
  EXTERNAL_LIBS: '/ui/lib/ext',
  INTERNAL_LIBS: '/ui/lib/int',
  VUE_DIST: '/ui/ui-vue/dist',
  ANGULAR_MODULES: '/ui/modules',
}

const conditions = {
  VUE_DEV: env => env.isVueDev,
  NOT_VUE_DEV : env => !env.isVueDev
}


export default [

  // for external clients: emulation over websocket
  `${paths.MAIN_ENTRYPOINT}/comms.js`,

  // Vue START
  ...onCondition(conditions.NOT_VUE_DEV,
    inPath(paths.VUE_DIST, [
      { type: "module", src: '/index.js' },
      '/index.css'
    ])
  ),
  ...onCondition(conditions.VUE_DEV,
    // main entrypoint from Vite
    {src:'http://localhost:9000/src/main.js', type: 'module'},
  ),
  {src: `${paths.EXTERNAL_LIBS}/vue-i18n-next/vue-i18n.global.prod.js`}, // , defer: true},
  {src: `${paths.EXTERNAL_LIBS}/tiny-emitter/tinyemitter.js`, defer: true},
  {src: `${paths.INTERNAL_LIBS}/vueService.js`}, //, defer: true},


  {src: `${paths.MAIN_ENTRYPOINT}/angularModules.js`, defer: true},


  // 3rd party includes
  ...inPath(paths.EXTERNAL_LIBS, [
    // ResizeObserver polyfill for Ultralight
    '/resize-observer-polyfill/ResizeObserver.global.js',

    // :focus-visible polyfill for controller focus frame (see _focus.scss)
    '/focus-visible-polyfill/dist/focus-visible.js',

    '/angular/angular.js',
    '/angular/angular-animate.js',
    '/angular/angular-aria.js',
    '/angular/angular-sanitize.js',

    '/angular-ui-router.min.js',
    '/angular-material/angular-material.js',
    '/smoothie.min.js',
    '/angular-translate/angular-translate-beamng.js',
    '/angular-translate/angular-translate-loader-static-files/angular-translate-loader-static-files.js',
    '/angular-translate/angular-translate-handler-log/angular-translate-handler-log.js',

    '/ocLazyLoad.min.js',
    '/angular-toastr.tpls.min.js',
    '/spine-canvas.js',
    '/angular-material-paging.js',
    '/jk-rating-stars.min.js',
    '/chartist.min.js',
    '/hu.js',

    '/qrcode.min.js',

    // 3rd party test
    '/ng-FitText.js',

    '/angular-toastr.min.css',
    '/angular-material-paging.css',
    '/jk-rating-stars.min.css',
    '/chartist.min.css',

  ]),


  // BeamNG UI
  `${paths.MAIN_ENTRYPOINT}/main.js`,

  ...inPath(paths.INTERNAL_LIBS, [
    '/beamng-core.js',
    '/utilities.js',
    '/beamng-data.js'
  ]),
  ...inPath(paths.EXTERNAL_LIBS, [
    '/mdx.js',

    // TODO - remove when we're sure moved version is working OK and not needed to be included
    // '/crossfire-chrome.js',

  ]),

  // Controls
  ...inPath(paths.INTERNAL_LIBS, [
    '/beamng.controls.js',
    '/beamng.controls.css',
  ]),

  // Angular Modules
  ...inPath(paths.ANGULAR_MODULES, [
    '/levelselect/levelselect.js',
    '/photomode/photomode.js',
    '/replay/replay.js',
    '/environment/environment.js',
    '/scenarioselect/scenarioselect.js',
    '/scenariocontrol/scenariocontrol.js',
    '/comic/comic.js',
    '/vehicleselect/vehicleselect.js',
    '/options/options.js',
    '/startScreen/startScreen.js',
    '/vehicleconfig/vehicleconfig.js',
    '/loading/loading.js',
    '/repository/repository.js',
    '/automation/automation.js',
    '/quickrace/quickrace.js',
    '/lightrunner/lightrunner.js',
    '/dragrace/dragrace.js',
    '/mapview/mapview.js',
    '/gameContext/gameContext.js',
    '/missionGenericDataDisplay/genericDataDisplay.js',
    '/bigmap/bigmap.js',
    '/stat/statControllers.js',

    '/mainmenu/mainmenu.js',
    '/menu/menu.js',
    '/onlineFeatures/online.js',
    '/career/career.js',
    '/careerPause/careerPause.js',
    '/introPopup/intro.js',
    '/careerQuests/quests.js',
    '/careerTasklist/tasklist.js',
    '/careerVehicleSelect/careerVehicleSelect.js',
    '/threeElementSelect/threeElementSelect.js',

    '/appselect/appselect.js',
    '/appedit/appedit.js',
    '/modmanager/modmanager.js',
    '/play/play.js',
    '/garage/garage.js',
    '/apps/app-service.js',
    '/apps/app-container.js',
    '/apps/app.js',

    '/campaignselect/campaignselect.js',

    '/busRoute/busRoute.js',
    '/iconView/icons.js',

    '/fadeScreen/fadeScreen.js',
    '/atom/title/title.js',
    '/atom/card/card.js',
    '/atom/tabs/tabs.js',
    '/multiplayer/multiplayer.js',

    '/mainmenu/mainmenu.css',
    '/menu/menu.css',
    '/introPopup/intro.css',
  ]),

  ...inPath(paths.INTERNAL_LIBS, [
    '/mission-popups/mission-popups.js',
    '/colorpicker/color.js',
    '/ui-components/bng-components.js',
    '/ui-components/bng-components.css',
  ]),

  `${paths.EXTERNAL_LIBS}/keys.css`


]

