<template>
  <div class="card">
    <h3>{{ $tt("ui.common.beammp.direct_connect") }}</h3>

    <label>
      {{ $tt("ui.beammp.serverBrowser.serverIp") }}
      <input v-model="ip" class="bng-input" type="text" />
    </label>

    <label>
      {{ $tt("ui.beammp.serverBrowser.serverPort") }}
      <input v-model="port" class="bng-input" type="text" />
    </label>

    <div class="actions">
      <BngButton @click="connect">{{ $tt("ui.common.beammp.connect") }}</BngButton>
      <BngButton accent="secondary" @click="pasteFromClipboard">{{ $tt("ui.common.beammp.pasteFromClipboard") }}</BngButton>
    </div>
  </div>
</template>

<script setup>
import { ref } from "vue"
import { BngButton } from "@/common/components/base"
import { useBeamMPState } from "../shared/beammpState.js"

const ip = ref("")
const port = ref("30814")
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
