<template>
  <Teleport to="body">
    <div v-if="notifications.length" class="notification-container">
      <div
        v-for="n in notifications"
        :key="n.id"
        class="notification"
        :class="`notification--${n.state || 'info'}`"
      >
        <span class="notification__kicker">★ {{ kickerFor(n) }}</span>
        <div v-if="n.title" class="notification__title">{{ n.title }}</div>
        <!-- eslint-disable-next-line vue/no-v-html -- sanitized by renderMessage (escapes all HTML, re-allows only <strong>) -->
        <div class="notification__message" v-html="renderMessage(n.message)"></div>
        <div v-if="n.type === 'confirm'" class="notification__actions">
          <button class="btn btn--ghost" @click="dismiss(n.id)">{{ n.cancelLabel || 'CANCEL' }}</button>
          <button class="btn btn--orange" @click="handleConfirm(n)">
            {{ n.confirmLabel || 'YES, DO IT →' }}
          </button>
        </div>
        <button
          v-else
          class="notification__close"
          aria-label="Dismiss"
          @click="dismiss(n.id)"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="16"
            height="16"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
          >
            <line x1="18" y1="6" x2="6" y2="18"></line>
            <line x1="6" y1="6" x2="18" y2="18"></line>
          </svg>
        </button>
      </div>
    </div>
  </Teleport>
</template>

<script setup lang="ts">
const { notifications, dismiss } = useNotify();

// The message renders via v-html so toasts can emphasise with <strong>. Inputs are
// not always trusted (team/group names, raw error strings flow in here), so escape
// all HTML first, then re-allow only <strong>/</strong>. This keeps the emphasis
// feature while neutralising any injected markup (stored-XSS guard).
function renderMessage(raw: string) {
  const escaped = (raw ?? '')
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;');
  return escaped
    .replace(/&lt;strong&gt;/g, '<strong>')
    .replace(/&lt;\/strong&gt;/g, '</strong>');
}

async function handleConfirm(n: { id: number; onConfirm?: () => void | Promise<void> }) {
  if (n.onConfirm) await n.onConfirm();
  dismiss(n.id);
}

function kickerFor(n: { type?: string; state?: string }) {
  if (n.type === 'confirm') return 'HEADS UP';
  if (n.state === 'success') return 'NICE';
  if (n.state === 'error') return 'OOPS';
  if (n.state === 'warning') return 'HEADS UP';
  return 'BETTY SAYS';
}
</script>

<style scoped>
.notification-container {

  position: fixed;
  top: 120px;
  right: 20px;
  z-index: 10000;
  display: flex;
  flex-direction: column;
  gap: 12px;
  max-width: 380px;
  font-family:
    'Inter',
    system-ui,
    -apple-system,
    BlinkMacSystemFont,
    sans-serif;
}

@media (max-width: 600px) {
  .notification-container {
    left: 16px;
    right: 16px;
    max-width: none;
    top: auto;
    bottom: 16px;
  }
}

.notification {
  background: var(--indigo-dark);
  color: var(--cream);
  border-radius: 2px;
  padding: 16px 18px;
  box-shadow:
    0 20px 40px -16px rgba(0, 0, 0, 0.5),
    0 0 0 1px var(--surface-overlay-04);
  position: relative;
  border-left: 3px solid var(--orange);
  animation: slide-in 0.25s ease-out;
}

@keyframes slide-in {
  from {
    transform: translateX(20px);
    opacity: 0;
  }
  to {
    transform: translateX(0);
    opacity: 1;
  }
}

.notification--success {
  border-left-color: var(--green);
}

.notification--error {
  border-left-color: var(--orange);
}

.notification--warning {
  border-left-color: var(--yellow);
}

.notification__kicker {
  display: block;
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
  color: var(--orange);
  margin-bottom: 6px;
}

.notification--success .notification__kicker {
  color: var(--green);
}

.notification--warning .notification__kicker {
  color: var(--yellow);
}

.notification__title {
  font-weight: 800;
  font-size: 15px;
  color: var(--cream);
  margin-bottom: 4px;
  letter-spacing: -0.01em;
  padding-right: 24px;
}

.notification__message {
  font-size: 13px;
  color: var(--muted-strong);
  line-height: 1.5;
}

.notification__message :deep(strong) {
  color: var(--cream);
  font-weight: 800;
}

.notification__actions {
  display: flex;
  gap: 8px;
  margin-top: 14px;
  justify-content: flex-end;
}

.notification__close {
  position: absolute;
  top: 12px;
  right: 12px;
  background: transparent;
  border: 0;
  cursor: pointer;
  color: var(--muted-strong);
  width: 24px;
  height: 24px;
  display: flex;
  align-items: center;
  justify-content: center;
  border-radius: 50%;
  transition: background 0.15s ease;
}

.notification__close:hover {
  background: var(--surface-overlay-08);
  color: var(--cream);
}

.btn {
  border: 0;
  cursor: pointer;
  font-family: inherit;
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  padding: 10px 14px;
  border-radius: 2px;
  transition: filter 0.15s ease;
}

.btn--orange {
  background: var(--orange);
  color: #fff;
}

.btn--orange:hover {
  filter: brightness(1.05);
}

.btn--ghost {
  background: transparent;
  color: var(--muted-strong);
}

.btn--ghost:hover {
  background: var(--surface-overlay-06);
  color: var(--cream);
}
</style>
