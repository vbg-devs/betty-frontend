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
      <div v-for="msg in messages" :key="msg.id" class="meme-board__message">
        <div class="row">
          <div class="column column--wrap">
            <UserBadge :user="getUser(msg.user_id)" />
          </div>
          <div class="column">
            <div class="meme-board__username">
              <strong>{{ getUser(msg.user_id).name }}</strong>
              - {{ formatDate(msg.created_at) }}
            </div>
            <template v-if="msg.image_url">
              <img :src="msg.image_url" class="message__image" />
            </template>
            <template v-else>
              <p>{{ msg.body }}</p>
            </template>
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

const { members = [] } = defineProps<{
  members?: any[];
}>();

const route = useRoute();
const userStore = useUserStore();
const { authFetch } = useApi();

const gf = new GiphyFetch('EUSX9DmpuBQafmcrIeKL9jNl5ES91X9r');

const q = ref('');
const useGiphy = ref(false);
const messages = ref<any[]>([]);
const loading = ref(false);
const images = ref<any[]>([]);
const selectedImageIndex = ref(0);
let timer: ReturnType<typeof setInterval> | null = null;

const user = computed(() => userStore.profile);

const selectedPreviewImage = computed(() => {
  return images.value[selectedImageIndex.value]?.images.original.url;
});

onMounted(() => {
  timer = setInterval(loadMessages, 10000);
  loadMessages();
});

onBeforeUnmount(() => {
  if (timer) {
    clearInterval(timer);
    timer = null;
  }
});

async function loadMessages() {
  try {
    const data = await authFetch<any[]>(`/messageboard/${route.params.id}`);
    messages.value = data;
  } catch (err) {
    console.error(err);
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

function getUser(userId: number) {
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
  --indigo-dark: #1f2752;
  --cream: #fffaeb;
  --orange: #ff5a3a;
  --muted: rgba(255, 250, 235, 0.5);
  --muted-strong: rgba(255, 250, 235, 0.78);
}

.meme-board__header {
  display: flex;
  align-items: center;
  justify-content: space-between;
  margin-bottom: 16px;
  padding-bottom: 14px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.06);
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
  max-height: 300px;
  border-radius: 2px;
}

.meme-board__footer {
  padding-top: 18px;
  border-top: 1px solid rgba(255, 255, 255, 0.06);
  margin-top: 4px;
}

.meme-board__message {
  margin-bottom: 14px;
  padding-bottom: 14px;
  border-bottom: 1px solid rgba(255, 255, 255, 0.05);
}

.meme-board__message:last-child {
  border-bottom: 0;
  margin-bottom: 0;
  padding-bottom: 0;
}

.meme-board__message :deep(p) {
  margin: 0;
  color: var(--cream);
  line-height: 1.4;
}

.meme-board__input {
  width: 100%;
  padding: 12px 44px 12px 14px;
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
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
  background: rgba(255, 255, 255, 0.06);
}

.meme-board .row {
  margin: 0;
  gap: 12px;
}

.meme-board__username {
  font-size: 13px;
  margin-bottom: 6px;
  color: var(--muted-strong);
}

.meme-board__username :deep(strong) {
  color: var(--cream);
  font-weight: 800;
  margin-right: 4px;
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
  background: rgba(255, 255, 255, 0.04);
  border: 1px solid rgba(255, 255, 255, 0.08);
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
  background: rgba(255, 255, 255, 0.06);
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
</style>
