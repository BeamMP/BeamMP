<template>
  <section class="centered">
    <h2>{{ $tt("ui.beammp.launcher.lost") }}</h2>
    <BngButton @click="reconnect">{{ $tt("ui.common.beammp.connect") }}</BngButton>
  </section>
</template>

<script setup>
import { onMounted, watch } from "vue"
import { useRouter } from "vue-router"
import { BngButton } from "@/common/components/base"
import { BEAMMP_LOGIN_ROUTE_NAME } from "../shared/constants.js"
import { useBeamMPState } from "../shared/beammpState.js"

const router = useRouter()
const { connectToLauncher, refreshConnectionState, state } = useBeamMPState()

async function reconnect() {
  await connectToLauncher()
}

onMounted(async () => {
  await refreshConnectionState()
  if (state.launcherConnected.value) {
    router.replace({ name: BEAMMP_LOGIN_ROUTE_NAME })
  }
})

watch(() => state.launcherConnected.value, connected => {
  if (connected) {
    router.replace({ name: BEAMMP_LOGIN_ROUTE_NAME })
  }
})
</script>

<style scoped>
.centered {
  min-height: 50vh;
  display: grid;
  place-items: center;
  text-align: center;
  gap: 1rem;
}
</style>
