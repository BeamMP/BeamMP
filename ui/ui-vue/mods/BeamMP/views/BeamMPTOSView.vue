<template>
  <section class="panel">
    <h1>{{ $tt("ui.beammp.tos.title") }}</h1>

    <div class="block">
      <h2>{{ $tt("ui.beammp.tos") }}</h2>
      <p>
        {{ $tt("ui.beammp.tos.description1") }}
        <a href="#" @click.prevent="openExternal('https://forum.beammp.com/topic/94/terms-of-use-v1-0')">here</a>.
        {{ $tt("ui.beammp.tos.description2") }}
      </p>
      <label><input v-model="tosAccepted" type="checkbox" /> I accept the Terms of Service</label>
    </div>

    <div class="block">
      <h2>{{ $tt("ui.common.beammp.rules") }}</h2>
      <p>
        {{ $tt("ui.beammp.rules.description1") }}
        <a href="#" @click.prevent="openExternal('https://docs.beammp.com/community/rules/')">here</a>.
        {{ $tt("ui.beammp.rules.description2") }}
      </p>
      <label><input v-model="rulesAccepted" type="checkbox" /> I accept the Multiplayer Rules</label>
    </div>

    <div class="actions">
      <BngButton :disabled="!canContinue" @click="proceed">{{ $tt("ui.common.continue") }}</BngButton>
    </div>
  </section>
</template>

<script setup>
import { computed, ref } from "vue"
import { useRouter } from "vue-router"
import { BngButton } from "@/common/components/base"
import { BEAMMP_LAUNCHER_ROUTE_NAME } from "../shared/constants.js"
import { useBeamMPState } from "../shared/beammpState.js"

const router = useRouter()
const { acceptTos, openExternal } = useBeamMPState()
const tosAccepted = ref(false)
const rulesAccepted = ref(false)
const canContinue = computed(() => tosAccepted.value && rulesAccepted.value)

function proceed() {
  if (!canContinue.value) return
  acceptTos()
  router.push({ name: BEAMMP_LAUNCHER_ROUTE_NAME })
}
</script>

<style scoped lang="scss">
.panel {
  display: flex;
  flex-direction: column;
  gap: 1rem;
}

.block {
  padding: 0.8rem;
  border-radius: var(--bng-corners-1);
  background: rgba(255, 255, 255, 0.04);
}

.actions {
  display: flex;
  justify-content: flex-end;
}

p {
  color: var(--bng-cool-gray-100);
}

a {
  color: var(--bng-orange-300);
}
</style>
