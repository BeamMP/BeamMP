<template>
  <section class="tiles-grid">
    <button class="tile" @click="openView('official')">{{ $tt("ui.beammp.official") }}</button>
    <button class="tile" @click="openView('featured')">{{ $tt("ui.beammp.featured") }}</button>
    <button class="tile" @click="openView('partner')">{{ $tt("ui.beammp.partner") }}</button>
    <button class="tile" @click="openView('favorites')">{{ $tt("ui.beammp.serverBrowser.saveAsFavorites") }}</button>
    <button class="tile" @click="openView('recent')">{{ $tt("ui.beammp.recent") }}</button>

    <button
      v-for="tag in availableTags"
      :key="tag.raw"
      class="tile tag"
      @click="openTag(tag.raw)"
    >
      {{ tag.text }}
    </button>
  </section>
</template>

<script setup>
import { computed } from "vue"
import { useRouter } from "vue-router"
import { BEAMMP_SERVERS_ROUTE_NAME } from "../shared/constants.js"
import { useBeamMPState } from "../shared/beammpState.js"

const router = useRouter()
const { availableTags, setView, updateFilter } = useBeamMPState()
const tags = computed(() => availableTags.value.filter(tag => tag.theme !== null))

function openView(view) {
  setView(view)
  router.push({ name: BEAMMP_SERVERS_ROUTE_NAME, params: { view } })
}

function openTag(rawTag) {
  setView("servers")
  updateFilter({ selectedTags: [{ raw: rawTag }] })
  router.push({ name: BEAMMP_SERVERS_ROUTE_NAME })
}
</script>

<style scoped lang="scss">
.tiles-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(12rem, 1fr));
  gap: 0.75rem;
}

.tile {
  min-height: 6.5rem;
  border-radius: var(--bng-corners-2);
  border: 1px solid rgba(var(--bng-orange-500-rgb), 0.4);
  color: var(--bng-off-white);
  background:
    linear-gradient(140deg, rgba(var(--bng-orange-500-rgb), 0.35), rgba(0, 0, 0, 0.4));
  text-align: left;
  padding: 0.75rem;
  font-size: 1rem;
  cursor: pointer;
}

.tag {
  min-height: 4.5rem;
}
</style>
