<template>
  <div class="meme-board">
    <header class="meme-board__header">
      <span class="kicker kicker--accent">★ GROUP CHAT</span>
      <span v-if="messages.length" class="meme-board__count">{{ messages.length }} MESSAGES</span>
    </header>
    <section class="meme-board__body">
      <div v-show="images.length" class="gif-selector">
        <div>
          <strong>Select gif</strong>
        </div>
        <div class="gif-selector__image-wrapper">
          <img :src="selectedPreviewImage" />
        </div>
        <div class="gif-selector__buttons">
          <button
            class="button button--action"
            :disabled="selectedImageIndex === 0"
            @click="prevImage"
          >
            Prev
          </button>
          <button
            class="button button--action"
            :disabled="selectedImageIndex === images.length - 1"
            @click="nextImage"
          >
            Next
          </button>
          &nbsp;
          <button class="button button--select" @click="selectImage">Submit</button>
          <button class="button button--danger" @click="cancelImageSelection">Cancel</button>
        </div>
      </div>
      <div
        v-for="msg in messages"
        :key="msg.id"
        class="meme-board__message"
        :class="{ 'meme-board__message--mine': msg.user_id === userId }"
      >
        <div class="row">
          <div class="column column--wrap">
            <UserBadge :user="getUser(msg.user_id)" />
          </div>
          <div class="column">
            <div class="meme-board__username">
              <strong>{{ getUser(msg.user_id).nickname || getUser(msg.user_id).name }}</strong>
              - {{ formatDate(msg.created_at) }}
            </div>
            <button
              v-if="msg.user_id === userId"
              class="meme-board__delete"
              :disabled="deletingId === msg.id"
              aria-label="Delete message"
              @click="confirmDeleteMessage(msg)"
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
                <polyline points="3 6 5 6 21 6"></polyline>
                <path
                  d="M19 6l-1 14a2 2 0 0 1-2 2H8a2 2 0 0 1-2-2L5 6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"
                ></path>
              </svg>
            </button>
            <template v-if="msg.image_url">
              <img :src="msg.image_url" class="message__image" />
            </template>
            <template v-else>
              <p>{{ msg.body }}</p>
            </template>
            <div class="reactions">
              <button
                v-for="group in groupReactions(msg)"
                :key="group.emoji_id"
                type="button"
                class="reactions__chip"
                :class="{ 'reactions__chip--mine': group.reactedByMe }"
                @click="toggleReaction(msg, group.emoji_id)"
              >
                <span class="reactions__emoji">{{ group.emoji_id }}</span>
                <span class="reactions__count">{{ group.count }}</span>
              </button>
              <div class="reactions__add">
                <button
                  type="button"
                  class="reactions__add-button"
                  aria-label="Add reaction"
                  @click.stop="togglePicker(msg.id)"
                >
                  <svg
                    xmlns="http://www.w3.org/2000/svg"
                    viewBox="0 0 24 24"
                    width="14"
                    height="14"
                    fill="none"
                    stroke="currentColor"
                    stroke-width="2"
                    stroke-linecap="round"
                    stroke-linejoin="round"
                  >
                    <circle cx="12" cy="12" r="9" />
                    <path d="M8 14s1.5 2 4 2 4-2 4-2" />
                    <line x1="9" y1="9" x2="9.01" y2="9" />
                    <line x1="15" y1="9" x2="15.01" y2="9" />
                    <line x1="19" y1="3" x2="19" y2="7" />
                    <line x1="17" y1="5" x2="21" y2="5" />
                  </svg>
                </button>
                <div v-if="pickerOpenFor === msg.id" class="reactions__picker">
                  <button
                    v-for="emoji in REACTION_EMOJIS"
                    :key="emoji"
                    type="button"
                    class="reactions__picker-item"
                    @click.stop="toggleReaction(msg, emoji)"
                  >
                    {{ emoji }}
                  </button>
                </div>
              </div>
            </div>
          </div>
        </div>
      </div>
    </section>
    <footer class="meme-board__footer">
      <div class="meme-board__form">
        <input
          v-model="q"
          placeholder="Send message to group"
          type="text"
          class="meme-board__input"
          @keyup="handleKeyup"
        />
        <div v-show="loading" class="meme-board__spinner">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 100 100"
            preserveAspectRatio="xMidYMid"
            width="34"
            height="34"
            style="shape-rendering: auto; display: block"
            xmlns:xlink="http://www.w3.org/1999/xlink"
          >
            <g>
              <g transform="rotate(0 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.9166666666666666s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(30 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.8333333333333334s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(60 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.75s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(90 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.6666666666666666s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(120 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.5833333333333334s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(150 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.5s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(180 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.4166666666666667s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(210 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.3333333333333333s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(240 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.25s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(270 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.16666666666666666s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(300 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="-0.08333333333333333s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g transform="rotate(330 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate
                    repeatCount="indefinite"
                    begin="0s"
                    dur="1s"
                    keyTimes="0;1"
                    values="1;0"
                    attributeName="opacity"
                  ></animate>
                </rect>
              </g>
              <g></g>
            </g>
          </svg>
        </div>
        <button
          class="meme-board__toggle"
          aria-label="Toggle gif mode"
          data-balloon-pos="left"
          :class="{ 'meme-board__toggle--active': useGiphy }"
          @click="useGiphy = !useGiphy"
        >
          <svg
            xmlns="http://www.w3.org/2000/svg"
            viewBox="0 0 24 24"
            width="24"
            height="24"
            color="currentColor"
            fill="none"
          >
            <path
              d="M14.8597 22H10.548C7.25691 22 5.61139 22 4.46864 21.2022C4.14123 20.9736 3.85055 20.7025 3.60545 20.3971C2.75 19.3313 2.75 17.7966 2.75 14.7273V12.1818C2.75 9.21865 2.75 7.73706 3.22323 6.55375C3.98399 4.65142 5.5929 3.15088 7.63261 2.44135C8.90137 2 10.4899 2 13.6671 2C15.4827 2 16.3904 2 17.1154 2.2522C18.2809 2.65765 19.2003 3.5151 19.635 4.60214C19.9055 5.27832 19.9055 6.12494 19.9055 7.81818V10"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <path
              d="M2.75 12C2.75 10.1591 4.25603 8.66667 6.11381 8.66667C6.78569 8.66667 7.57779 8.78333 8.23104 8.60988C8.81145 8.45576 9.2648 8.00652 9.42033 7.43136C9.59536 6.78404 9.47763 5.99912 9.47763 5.33333C9.47763 3.49238 10.9837 2 12.8414 2"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
            <path
              d="M12.842 18H15.3648M10.416 13.8506C10.2901 13.0495 10.1346 13.0487 8.8054 13H7.79626C7.23892 13 6.78711 13.4477 6.78711 14L6.78711 17C6.78711 17.5523 7.23892 18 7.79625 18H9.61272C10.0029 18 10.416 17.6866 10.416 17.3V16.2C10.416 16.0895 10.3034 15.896 10.1919 15.896H9.06776M12.842 13H14.1034M14.1034 13H15.3648M14.1034 13V17.8749M21.2511 13H18.7283C18.1709 13 17.7191 13.4477 17.7191 14V15.5M17.7191 15.5V18M17.7191 15.5H20.242"
              stroke="currentColor"
              stroke-width="1.5"
              stroke-linecap="round"
              stroke-linejoin="round"
            />
          </svg>
        </button>
      </div>
    </footer>
  </div>
</template>

<script setup lang="ts">
import { formatDistance } from 'date-fns';
import { GiphyFetch } from '@giphy/js-fetch-api';
import type { GroupMessage } from '~/types';

const { members = [] } = defineProps<{
  members?: any[];
}>();

const route = useRoute();
const userStore = useUserStore();
const { authFetch } = useApi();
const { alert: notify, confirm: confirmDialog } = useNotify();

const gf = new GiphyFetch('EUSX9DmpuBQafmcrIeKL9jNl5ES91X9r');

const REACTION_EMOJIS = ['👍', '❤️', '😂', '🔥', '🎉', '😮', '😢', '👀'];

const q = ref('');
const useGiphy = ref(false);
const messages = ref<GroupMessage[]>([]);
const loading = ref(false);
const images = ref<any[]>([]);
const selectedImageIndex = ref(0);
const deletingId = ref<number | null>(null);
const pickerOpenFor = ref<number | null>(null);
let timer: ReturnType<typeof setInterval> | null = null;

const user = computed(() => userStore.profile);
const userId = computed(() => userStore.id);

const selectedPreviewImage = computed(() => {
  return images.value[selectedImageIndex.value]?.images.original.url;
});

onMounted(() => {
  timer = setInterval(loadMessages, 10000);
  loadMessages();
  document.addEventListener('click', handleDocumentClick);
});

onBeforeUnmount(() => {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
  document.removeEventListener('click', handleDocumentClick);
});

async function loadMessages() {
  try {
    const data = await authFetch<GroupMessage[]>(`/messageboard/${route.params.id}`);
    messages.value = data.map((m) => ({ ...m, reactions: m.reactions ?? [] }));
  } catch (err) {
    console.error(err);
  }
}

interface ReactionGroup {
  emoji_id: string;
  count: number;
  reactedByMe: boolean;
}

function groupReactions(message: GroupMessage): ReactionGroup[] {
  const map = new Map<string, ReactionGroup>();
  for (const r of message.reactions) {
    const existing = map.get(r.emoji_id);
    if (existing) {
      existing.count += 1;
      if (r.user_id === user.value?.id) existing.reactedByMe = true;
    } else {
      map.set(r.emoji_id, {
        emoji_id: r.emoji_id,
        count: 1,
        reactedByMe: r.user_id === user.value?.id,
      });
    }
  }
  return Array.from(map.values());
}

function togglePicker(messageId: number) {
  pickerOpenFor.value = pickerOpenFor.value === messageId ? null : messageId;
}

function handleDocumentClick(ev: MouseEvent) {
  if (pickerOpenFor.value === null) return;
  const target = ev.target as HTMLElement | null;
  if (target?.closest('.reactions, .reactions__add')) return;
  pickerOpenFor.value = null;
}

async function toggleReaction(message: GroupMessage, emoji: string) {
  const userId = user.value?.id;
  if (!userId) return;
  const mine = message.reactions.find((r) => r.user_id === userId);
  pickerOpenFor.value = null;

  if (mine && mine.emoji_id === emoji) {
    const prev = message.reactions;
    message.reactions = prev.filter((r) => r.user_id !== userId);
    try {
      await authFetch(`/messageboard/${message.id}/reaction`, { method: 'DELETE' });
    } catch (err) {
      console.error(err);
      message.reactions = prev;
    }
    return;
  }

  const prev = message.reactions;
  const others = prev.filter((r) => r.user_id !== userId);
  message.reactions = [
    ...others,
    { user_id: userId, emoji_id: emoji, created_at: new Date().toISOString() },
  ];
  try {
    await authFetch(`/messageboard/${message.id}/reaction`, {
      method: 'PUT',
      body: { emoji_id: emoji },
    });
  } catch (err) {
    console.error(err);
    message.reactions = prev;
  }
}

function cancelImageSelection() {
  images.value = [];
  selectedImageIndex.value = 0;
}

function nextImage() {
  selectedImageIndex.value += 1;
}

function prevImage() {
  selectedImageIndex.value -= 1;
}

function formatDate(date: string) {
  return formatDistance(new Date(date), new Date(), { addSuffix: true });
}

function getUser(userId: string) {
  return members.find((member) => member.user_id === userId);
}

function handleKeyup(ev: KeyboardEvent) {
  if (ev.key !== 'Enter') return;
  sendMessage();
}

async function postMessage(msg: { message?: string; image?: string }) {
  try {
    const data = await authFetch<any>('/messageboard', {
      method: 'POST',
      body: {
        group_id: parseFloat(route.params.id as string),
        body: msg.message,
        image_url: msg.image,
      },
    });
    messages.value.unshift(data);
    images.value = [];
    selectedImageIndex.value = 0;
  } catch (err) {
    console.error(err);
  }
}

function selectImage() {
  const newMessage = {
    image: selectedPreviewImage.value,
  };
  postMessage(newMessage);
}

function confirmDeleteMessage(msg: { id: number; user_id: string }) {
  if (msg.user_id !== userId.value) return;
  confirmDialog({
    title: 'Delete message',
    question: 'Delete this message? This cannot be undone.',
    onConfirm: () => deleteMessage(msg.id),
  });
}

async function deleteMessage(id: number) {
  if (deletingId.value === id) return;
  deletingId.value = id;
  try {
    await authFetch(`/messageboard/${id}`, { method: 'DELETE' });
    messages.value = messages.value.filter((m) => m.id !== id);
  } catch (err: any) {
    const status = err?.response?.status ?? err?.status;
    if (status === 404) {
      // Already gone — just drop it locally and don't bother the user.
      messages.value = messages.value.filter((m) => m.id !== id);
      return;
    }
    notify({
      title: 'Could not delete message',
      message: String(err),
      state: 'error',
    });
  } finally {
    deletingId.value = null;
  }
}

async function sendMessage() {
  if (!q.value) return;
  if (!useGiphy.value) {
    const newMessage = {
      image: undefined,
      message: q.value,
    };
    postMessage(newMessage);
    q.value = '';
    return;
  }
  if (loading.value) return;
  loading.value = true;
  const res = await gf.search(q.value, { limit: 10 });
  if (res.data.length) {
    images.value = res.data;
  }
  q.value = '';
  loading.value = false;
}
</script>

<style scoped>
.meme-board {
}

.meme-board__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
  padding-bottom: 14px;
  border-bottom: 1px solid var(--surface-overlay-06);
}

.kicker {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.6px;
  text-transform: uppercase;
}

.kicker--accent {
  color: var(--orange);
}

.meme-board__count {
  font-size: 11px;
  font-weight: 700;
  letter-spacing: 1.4px;
  color: var(--muted);
}

.meme-board__body {
  max-height: 400px;
  min-height: 1px;
  overflow-y: auto;
  padding-right: 6px;
  display: flex;
  flex-direction: column-reverse;
}

@media (min-width: 768px) {
  .meme-board__body {
    max-height: 800px;
  }
}

.message__image {
  display: block;
  max-width: 100%;
  height: auto;
  border-radius: 2px;
  margin-top: 4px;
}

.meme-board__footer {
  padding-top: 18px;
  border-top: 1px solid var(--surface-overlay-06);
  margin-top: 4px;
}

.meme-board__message {
  position: relative;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid var(--surface-overlay-04);
  border-left: 2px solid var(--orange);
  border-radius: 2px;
  padding: 16px 18px;
  margin-bottom: 18px;
}

.meme-board__message:last-child {
  margin-bottom: 0;
}

.meme-board__message :deep(p) {
  margin: 0;
  color: var(--cream);
  line-height: 1.4;
}

.meme-board__input {
  width: 100%;
  padding: 12px 44px 12px 14px;
  background: var(--surface-overlay-04);
  border: 1px solid var(--surface-overlay-08);
  color: var(--cream);
  border-radius: 2px;
  outline: none;
  font-family: inherit;
  font-size: 14px;
  transition:
    border-color 0.15s ease,
    background 0.15s ease;
}

.meme-board__input::placeholder {
  color: var(--muted);
}

.meme-board__input:focus {
  border-color: rgba(255, 255, 255, 0.2);
  background: var(--surface-overlay-06);
}

.meme-board .row {
  margin: 0;
  gap: 16px;
}

.meme-board__username {
  font-size: 13px;
  margin-bottom: 10px;
  color: var(--muted-strong);
}

.meme-board__username :deep(strong) {
  color: var(--cream);
  font-weight: 800;
  margin-right: 4px;
}

.meme-board__delete {
  position: absolute;
  top: 0;
  right: 0;
  background: transparent;
  border: 0;
  color: var(--muted);
  padding: 4px;
  cursor: pointer;
  border-radius: 2px;
  display: inline-flex;
  align-items: center;
  justify-content: center;
  opacity: 0;
  transition:
    color 0.15s ease,
    background 0.15s ease,
    opacity 0.15s ease;
}

.meme-board__message--mine:hover .meme-board__delete,
.meme-board__delete:focus-visible {
  opacity: 1;
}

.meme-board__delete:hover {
  color: var(--orange);
  background: rgba(255, 90, 58, 0.12);
}

.meme-board__delete:disabled {
  opacity: 0.45;
  cursor: not-allowed;
}

@media (hover: none) {
  .meme-board__delete {
    opacity: 1;
  }
}

.meme-board .column {
  padding: 0;
}

.meme-board__form {
  position: relative;
}

.meme-board__toggle {
  position: absolute;
  right: 10px;
  border: none;
  background: transparent;
  padding: 0;
  top: 50%;
  transform: translateY(-50%);
  cursor: pointer;
  color: var(--muted);
  transition: color 0.15s ease;
}

.meme-board__toggle:hover {
  color: var(--cream);
}

.meme-board__toggle--active {
  color: var(--orange);
}

.meme-board__toggle svg {
  display: block;
  height: 22px;
  width: auto;
}

.meme-board__spinner {
  position: absolute;
  right: 40px;
  top: 50%;
  transform: translateY(-50%);
}

.gif-selector {
  background: var(--surface-overlay-04);
  border: 1px solid var(--surface-overlay-08);
  padding: 14px;
  border-radius: 2px;
  margin-bottom: 14px;
  color: var(--cream);
}

.gif-selector :deep(strong) {
  font-weight: 800;
  font-size: 11px;
  letter-spacing: 1.4px;
  text-transform: uppercase;
  color: var(--muted-strong);
}

.gif-selector__image-wrapper {
  margin: 10px 0;
}

.gif-selector__buttons {
  display: flex;
  gap: 8px;
  flex-wrap: wrap;
}

.gif-selector__buttons :deep(.button) {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.2px;
  text-transform: uppercase;
  padding: 10px 14px;
  border-radius: 2px;
  border: 0;
  cursor: pointer;
  font-family: inherit;
  height: auto;
}

.gif-selector__buttons :deep(.button--action) {
  background: var(--surface-overlay-06);
  color: var(--cream);
}

.gif-selector__buttons :deep(.button--select) {
  background: var(--orange);
  color: #fff;
}

.gif-selector__buttons :deep(.button--danger) {
  background: transparent;
  border: 1px solid rgba(255, 90, 58, 0.4);
  color: var(--orange);
}

.gif-selector img {
  max-height: 300px;
  width: auto;
  max-width: 100%;
  border-radius: 2px;
  display: block;
}

.reactions {
  display: flex;
  flex-wrap: wrap;
  gap: 6px;
  margin-top: 10px;
  align-items: center;
}

.reactions__chip {
  display: inline-flex;
  align-items: center;
  gap: 4px;
  padding: 3px 8px;
  background: rgba(255, 255, 255, 0.06);
  border: 1px solid rgba(255, 255, 255, 0.08);
  border-radius: 999px;
  color: var(--cream);
  font-family: inherit;
  font-size: 12px;
  font-weight: 700;
  line-height: 1;
  cursor: pointer;
  transition:
    background 0.15s ease,
    border-color 0.15s ease;
}

.reactions__chip:hover {
  background: rgba(255, 255, 255, 0.1);
}

.reactions__chip--mine {
  background: rgba(255, 90, 58, 0.16);
  border-color: rgba(255, 90, 58, 0.5);
  color: var(--orange);
}

.reactions__emoji {
  font-size: 14px;
  line-height: 1;
}

.reactions__count {
  font-variant-numeric: tabular-nums;
}

.reactions__add {
  position: relative;
  display: inline-flex;
}

.reactions__add-button {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 26px;
  height: 22px;
  padding: 0;
  background: transparent;
  border: 1px dashed rgba(255, 255, 255, 0.18);
  border-radius: 999px;
  color: var(--muted);
  cursor: pointer;
  transition:
    color 0.15s ease,
    border-color 0.15s ease;
}

.reactions__add-button:hover {
  color: var(--cream);
  border-color: rgba(255, 255, 255, 0.32);
}

.reactions__picker {
  position: absolute;
  bottom: calc(100% + 6px);
  left: 0;
  z-index: 5;
  display: flex;
  gap: 2px;
  padding: 6px;
  background: var(--indigo-dark);
  border: 1px solid rgba(255, 255, 255, 0.12);
  border-radius: 4px;
  box-shadow: 0 8px 20px rgba(0, 0, 0, 0.35);
}

.reactions__picker-item {
  display: inline-flex;
  align-items: center;
  justify-content: center;
  width: 30px;
  height: 30px;
  padding: 0;
  background: transparent;
  border: 0;
  border-radius: 2px;
  font-size: 18px;
  line-height: 1;
  cursor: pointer;
  transition: background 0.12s ease;
}

.reactions__picker-item:hover {
  background: rgba(255, 255, 255, 0.08);
}
</style>
