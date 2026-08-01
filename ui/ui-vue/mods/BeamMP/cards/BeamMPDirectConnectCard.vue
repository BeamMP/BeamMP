<template>
  <div class="card">
    <h3>{{ $tt("ui.common.beammp.direct_connect") }}</h3>

      <BngInput
	  	v-model="ip"
		type="text"
		:show-external-button="false"
		label="{{ $tt('ui.beammp.serverBrowser.serverIp') }}"
	  />

      <BngInput
	    v-model="port"
		type="text"
		:show-external-button="false"
		label="{{ $tt('ui.beammp.serverBrowser.serverPort') }}"
	  />

    <div class="actions">
      <BngButton @click="connect">{{ $tt("ui.common.beammp.connect") }}</BngButton>
      <BngButton accent="secondary" @click="pasteFromClipboard">{{ $tt("ui.common.beammp.pasteFromClipboard") }}</BngButton>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue"
import { BngInput, BngButton, BngDropdown, ACCENTS } from "@/common/components/base"
import { useBeamMPState } from "../shared/beammpState.js"

const ip = ref("")
const port = ref("")
const { connectToServer, directConnectFromClipboard } = useBeamMPState()

async function connect() {
  await connectToServer(ip.value || "127.0.0.1", port.value || "30814")
}

async function pasteFromClipboard() {
  const text = String(await directConnectFromClipboard() || "")
  if (!text.includes(".")) return
  const [nextIp, nextPort] = text.split(":")
  ip.value = nextIp || ip.value
  if (nextPort) port.value = nextPort
}
</script>

<style scoped>
.card {
  display: flex;
  flex-direction: column;
  gap: 0.45rem;
  color: var(--bng-off-white);
}

.actions {
  display: flex;
  gap: 0.5rem;
}

label {
  display: flex;
  flex-direction: column;
  gap: 0.2rem;
}
</style>
