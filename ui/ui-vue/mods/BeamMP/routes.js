import BeamMPMainMenu from "./views/BeamMPMainMenu.vue"
import BeamMPTOSView from "./views/BeamMPTOSView.vue"
import BeamMPLauncherView from "./views/BeamMPLauncherView.vue"
import BeamMPLoginView from "./views/BeamMPLoginView.vue"
import BeamMPTilesView from "./views/BeamMPTilesView.vue"
import BeamMPServersView from "./views/BeamMPServersView.vue"
import BeamMPCurrentServerView from "./views/BeamMPCurrentServerView.vue"
import BeamMPDirectView from "./views/BeamMPDirectView.vue"
import {
  BEAMMP_CURRENT_SERVER_ROUTE_NAME,
  BEAMMP_DIRECT_ROUTE_NAME,
  BEAMMP_LAUNCHER_ROUTE_NAME,
  BEAMMP_LOGIN_ROUTE_NAME,
  BEAMMP_ROUTE_NAME,
  BEAMMP_SERVERS_ROUTE_NAME,
  BEAMMP_TILES_ROUTE_NAME,
  BEAMMP_TOS_ROUTE_NAME,
} from "./shared/constants.js"

export const ROUTE_SOURCE_ID = "BeamMP.routes"

export const routeRecords = [
  {
    path: "/menu/beammp",
    component: BeamMPMainMenu,
    children: [
      {
        path: "",
        name: BEAMMP_ROUTE_NAME,
        redirect: { name: BEAMMP_TOS_ROUTE_NAME },
        meta: {
          luaRoute: {
            title: "BeamMP",
            backTarget: "menu",
            scopeTree: { "beammp-route": {} },
          },
        },
      },
      {
        path: "tos",
        name: BEAMMP_TOS_ROUTE_NAME,
        component: BeamMPTOSView,
      },
      {
        path: "launcher",
        name: BEAMMP_LAUNCHER_ROUTE_NAME,
        component: BeamMPLauncherView,
      },
      {
        path: "login",
        name: BEAMMP_LOGIN_ROUTE_NAME,
        component: BeamMPLoginView,
      },
      {
        path: "tiles",
        name: BEAMMP_TILES_ROUTE_NAME,
        component: BeamMPTilesView,
      },
      {
        path: "servers/:view?",
        name: BEAMMP_SERVERS_ROUTE_NAME,
        component: BeamMPServersView,
      },
      {
        path: "current-server",
        name: BEAMMP_CURRENT_SERVER_ROUTE_NAME,
        component: BeamMPCurrentServerView,
      },
      {
        path: "direct",
        name: BEAMMP_DIRECT_ROUTE_NAME,
        component: BeamMPDirectView,
      },
    ],
  },
]
