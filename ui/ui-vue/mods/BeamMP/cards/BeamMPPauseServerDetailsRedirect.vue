<template>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { $translate } from "@/services/translation"
import router from "@/router"

import { BngButton, BngPopoverMenu, BngUnit, ACCENTS } from "@/common/components/base"
import { openConfirmation, openPrompt, openFormDialog } from "@/services/popup"

const { api, events } = useBridge()

onMounted(async () => {
	window.bngVue.gotoGameState('menu.beammp.current-server')
})
</script>