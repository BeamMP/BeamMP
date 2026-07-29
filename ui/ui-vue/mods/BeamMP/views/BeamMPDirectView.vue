<template>
  <section class="direct-wrap">
    <header class="direct-header">
      <h2>{{ $tt("ui.multiplayer.direct_connect") }}</h2>
      <p>Connect to a BeamMP server using its address and port.</p>
    </header>

    <div class="direct-card">
      <div class="fields">
        <label class="field field-address">
          <span>{{ $tt("ui.multiplayer.direct_connect.server_ip") }}</span>
          <div class="input-shell">
            <span class="field-prefix">IP</span>
            <input
              v-model.trim="ip"
              type="text"
              autocomplete="off"
              spellcheck="false"
              placeholder="127.0.0.1"
            />
          </div>
        </label>

        <label class="field field-port">
          <span>{{ $tt("ui.multiplayer.direct_connect.server_port") }}</span>
          <div class="input-shell">
            <span class="field-prefix">:</span>
            <input
              v-model.trim="port"
              type="text"
              inputmode="numeric"
              autocomplete="off"
              placeholder="30814"
            />
          </div>
        </label>
      </div>

      <div class="actions">
        <BngButton accent="secondary" @click="pasteFromClipboard">{{ $tt("ui.multiplayer.pasteFromClipboard") }}</BngButton>
        <BngButton @click="connect">{{ $tt("ui.multiplayer.connect") }}</BngButton>
        <BngButton accent="secondary" @click="favorite">{{ $tt("ui.multiplayer.favorite") }}</BngButton>
      </div>
    </div>
  </section>
</template>

<script setup>
import { ref } from "vue"
import { BngButton } from "@/common/components/base"
import { useBeamMPState } from "../shared/beammpState.js"

const ip = ref("")
const port = ref("30814")
const { addFavorite, connectToServer, directConnectFromClipboard } = useBeamMPState()

async function pasteFromClipboard() {
  const text = String(await directConnectFromClipboard() || "")
  if (!text.includes(".")) return
  const [nextIp, nextPort] = text.split(":")
  ip.value = nextIp || ip.value
  if (nextPort) port.value = nextPort
}

async function connect() {
  await connectToServer(ip.value || "127.0.0.1", port.value || "30814")
}

async function favorite() {
  if (!ip.value || !port.value) return
  addFavorite({
    ip: ip.value,
    port: port.value,
    sname: new Date().toLocaleString(),
    strippedName: new Date().toLocaleString(),
    custom: true,
    tags: "",
    map: "",
    location: "--",
  })
}
</script>

<style scoped lang="scss">
.direct-wrap {
  width: min(48rem, 100%);
  display: flex;
  flex-direction: column;
  gap: 0.9rem;
  padding: 0.35rem;
}

.direct-header {
  h2 {
    margin: 0;
    font-size: 1.3rem;
  }

  p {
    margin: 0.25rem 0 0;
    color: var(--bng-cool-gray-300);
  }
}

.direct-card {
  display: flex;
  flex-direction: column;
  gap: 1rem;
  padding: 1rem;
  border: 1px solid rgba(255, 255, 255, 0.14);
  border-radius: var(--bng-corners-2);
  background:
    linear-gradient(135deg, rgba(27, 31, 38, 0.94), rgba(13, 16, 21, 0.9)),
    rgba(0, 0, 0, 0.35);
  box-shadow: inset 0.22rem 0 var(--bng-orange-500);
}

.fields {
  display: grid;
  grid-template-columns: minmax(14rem, 2fr) minmax(9rem, 1fr);
  gap: 0.75rem;
}

.field {
  display: flex;
  flex-direction: column;
  gap: 0.35rem;
  color: var(--bng-cool-gray-100);
  font-size: 0.85rem;
  font-weight: 600;
}

.input-shell {
  display: flex;
  align-items: stretch;
  min-height: 2.7rem;
  overflow: hidden;
  border: 1px solid rgba(255, 255, 255, 0.22);
  border-radius: var(--bng-corners-1);
  background: rgba(7, 10, 14, 0.78);
  transition: border-color 120ms ease, box-shadow 120ms ease;

  &:hover {
    border-color: rgba(255, 255, 255, 0.42);
  }

  &:focus-within {
    border-color: var(--bng-orange-500);
    box-shadow: 0 0 0 0.13rem rgba(var(--bng-orange-500-rgb), 0.32);
  }

  input {
    flex: 1;
    min-width: 0;
    border: 0;
    outline: 0;
    padding: 0.55rem 0.7rem;
    color: var(--bng-off-white);
    background: transparent;
    font: inherit;

    &::placeholder {
      color: var(--bng-cool-gray-400);
    }
  }
}

.field-prefix {
  display: grid;
  min-width: 2.6rem;
  place-items: center;
  padding: 0 0.5rem;
  border-right: 1px solid rgba(255, 255, 255, 0.14);
  color: var(--bng-cool-gray-200);
  background: rgba(255, 255, 255, 0.07);
  font-size: 0.78rem;
  font-weight: 700;
}

.actions {
  display: flex;
  gap: 0.5rem;
  flex-wrap: wrap;
}

@media (max-width: 700px) {
  .fields {
    grid-template-columns: 1fr;
  }
}
</style>
