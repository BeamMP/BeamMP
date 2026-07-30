<template>
  <div v-if="visible" class="modal-overlay" @click.self="emit('cancel')">
    <BngCard class="modal-card">
      <h3>{{ title }}</h3>
      <p>{{ message }}</p>
      <div class="modal-actions">
        <BngButton @click="emit('cancel')">{{ cancelText }}</BngButton>
        <BngButton @click="emit('confirm')">{{ confirmText }}</BngButton>
      </div>
    </BngCard>
  </div>
</template>

<script setup>
import { BngButton, BngCard } from "@/common/components/base"

defineProps({
  visible: {
    type: Boolean,
    required: true,
  },
  title: {
    type: String,
    default: "Confirm",
  },
  message: {
    type: String,
    default: "",
  },
  confirmText: {
    type: String,
    default: "Confirm",
  },
  cancelText: {
    type: String,
    default: "Cancel",
  },
})

const emit = defineEmits(["confirm", "cancel"])
</script>

<style scoped lang="scss">
.modal-overlay {
  position: fixed;
  inset: 0;
  background: rgba(0, 0, 0, 0.68);
  display: grid;
  place-items: center;
  z-index: 500;
}

.modal-card {
  width: min(32rem, 92vw);
  display: flex;
  flex-direction: column;
  gap: 0.8rem;
  padding: 1rem;
  color: var(--bng-off-white);
  background: rgba(21, 21, 21, 0.96);
  border: 1px solid rgba(var(--bng-orange-500-rgb), 0.65);
}

.modal-actions {
  display: flex;
  justify-content: flex-end;
  gap: 0.5rem;
}

p {
  color: var(--bng-cool-gray-200);
  white-space: pre-wrap;
}
</style>
