<template>
</template>

<script setup>
import { onMounted, onUnmounted, ref } from "vue"
import { useBridge } from "@/bridge"
import { $translate } from "@/services/translation"
import router from "@/router"
import { useBeamMPState } from "../shared/beammpState.js"

import { BngButton, BngPopoverMenu, BngUnit, ACCENTS } from "@/common/components/base"
import { openConfirmation, openPrompt, openFormDialog } from "@/services/popup"

const { events } = useBridge()
const { extensionCommand } = useBeamMPState()

onMounted(async () => {
	const res = await openConfirmation($translate.instant("ui.common.beammp.areYouSure"), $translate.instant("ui.beammp.pauseMenu.disconnectConfirmation"), [
		{ label: $translate.instant("ui.common.yes"), value: true, extras: { default: true, accent: ACCENTS.main } },
		{ label: $translate.instant("ui.common.no"), value: false, extras: { accent: ACCENTS.text } },
	])
	if (res) {
		extensionCommand("MPCoreNetwork", "leaveServer", "true")
	} else {
		console.log(bngVue)
		lua.ui_router.back().back()
	}
})
</script>
