<template>
  <Teleport to="body">
    <div v-if="notifications.length" class="notification-container">
      <div
        v-for="n in notifications"
        :key="n.id"
        class="notification"
        :class="`notification--${n.state || 'info'}`"
      >
        <div v-if="n.title" class="notification__title">{{ n.title }}</div>
        <div class="notification__message">{{ n.message }}</div>
        <div v-if="n.type === 'confirm'" class="notification__actions">
          <button class="button button--action" @click="handleConfirm(n)">OK</button>
          <button class="button button--danger" @click="dismiss(n.id)">Cancel</button>
        </div>
        <button v-else class="notification__close" @click="dismiss(n.id)">&times;</button>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
const { notifications, dismiss } = useNotify();

async function handleConfirm(n: { id: number; onConfirm?: () => void | Promise<void> }) {
  if (n.onConfirm) await n.onConfirm();
  dismiss(n.id);
}
</script>

<style scoped>
.notification-container {
  position: fixed;
  top: 20px;
  right: 20px;
  z-index: 10000;
  display: flex;
  flex-direction: column;
  gap: 10px;
  max-width: 400px;
}

.notification {
  background: #fff;
  border-radius: 8px;
  padding: 16px;
  box-shadow: 0 4px 12px rgba(0, 0, 0, 0.15);
  position: relative;
  border-left: 4px solid #434f8e;
}

.notification--success {
  border-left-color: #78cc14;
}

.notification--error {
  border-left-color: #f44336;
}

.notification--warning {
  border-left-color: #ff9800;
}

.notification__title {
  font-weight: 700;
  margin-bottom: 4px;
}

.notification__message {
  font-size: 14px;
  color: #555;
}

.notification__actions {
  display: flex;
  gap: 8px;
  margin-top: 12px;
}

.notification__close {
  position: absolute;
  top: 8px;
  right: 12px;
  background: none;
  border: none;
  font-size: 18px;
  cursor: pointer;
  color: #999;
}
</style>
