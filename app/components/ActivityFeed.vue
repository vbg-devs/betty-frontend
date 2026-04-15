<template>
  <div>
    <Transition name="clear" tag="div">
      <div v-if="list.length > 0" class="clear-all-container">
        <div
          class="clear-all"
          @click="clearAll"
          @mouseenter="hoverClear = true"
          @mouseleave="hoverClear = false"
        >
          <span v-if="hoverClear">CLEAR ALL</span>
          <svg
            v-else
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="feather feather-x-circle"
          >
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="15" y1="9" x2="9" y2="15"></line>
            <line x1="9" y1="9" x2="15" y2="15"></line>
          </svg>
        </div>
      </div>
    </Transition>
    <TransitionGroup name="list" tag="div">
      <div v-for="message in list" :key="message.id" class="feed-item">
        <div class="row row--center-v">
          <template v-if="message.type === 'bet_placed'">
            <div class="column column--wrap column--no-padding">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-user-check feed-item__icon"
              >
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <polyline points="17 11 19 13 23 9"></polyline>
              </svg>
            </div>
            <div class="column">
              <GameBetListItem :bet="message.message" />
            </div>
          </template>
          <template v-else-if="message.type === 'game_starting_soon'">
            <div class="column column--wrap column--no-padding">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-watch feed-item__icon"
              >
                <circle cx="12" cy="12" r="7"></circle>
                <polyline points="12 9 12 12 13.5 13.5"></polyline>
                <path
                  d="M16.51 17.35l-.35 3.83a2 2 0 0 1-2 1.82H9.83a2 2 0 0 1-2-1.82l-.35-3.83m.01-10.7l.35-3.83A2 2 0 0 1 9.83 1h4.35a2 2 0 0 1 2 1.82l.35 3.83"
                ></path>
              </svg>
            </div>
            <div class="column">
              <GameStartSoonListItem :match="message.message" />
            </div>
          </template>
          <template v-else-if="message.type === 'bet_updated'">
            <div class="column column--wrap column--no-padding">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-user-check feed-item__icon"
              >
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <polyline points="17 11 19 13 23 9"></polyline>
              </svg>
            </div>
            <div class="column">
              <GameBetListItem :bet="message.message" :update="true" />
            </div>
          </template>
          <template v-else-if="message.type === 'group_joined'">
            <div class="column column--wrap column--no-padding">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-user-check feed-item__icon"
              >
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <polyline points="17 11 19 13 23 9"></polyline>
              </svg>
            </div>
            <div class="column">
              <GroupJoinedListItem :data="message.message" />
            </div>
          </template>
          <template v-else-if="message.type === 'group_left'">
            <div class="column column--wrap column--no-padding">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-user-x feed-item__icon"
              >
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <line x1="18" y1="8" x2="23" y2="13"></line>
                <line x1="23" y1="8" x2="18" y2="13"></line>
              </svg>
            </div>
            <div class="column">
              <div class="feed-item__label">Someone just left a group</div>
            </div>
          </template>
          <template v-else-if="message.type === 'group_created'">
            <div class="column column--wrap column--no-padding">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-users feed-item__icon"
              >
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
              </svg>
            </div>
            <div class="column">
              <div class="feed-item__label">New group created!</div>
            </div>
          </template>
          <template v-else-if="message.type === 'user_register'">
            <div class="column column--wrap column--no-padding">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-user-plus feed-item__icon"
              >
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <line x1="20" y1="8" x2="20" y2="14"></line>
                <line x1="23" y1="11" x2="17" y2="11"></line>
              </svg>
            </div>
            <div class="column">
              <div class="feed-item__label">
                <strong>{{ message.message.name }}</strong> just joined, welcome!
              </div>
            </div>
          </template>
          <template v-else-if="message.type === 'evaluate_game'">
            <div class="column column--wrap column--no-padding">
              <svg
                aria-hidden="true"
                focusable="false"
                data-prefix="fal"
                data-icon="receipt"
                role="img"
                xmlns="http://www.w3.org/2000/svg"
                viewBox="0 0 448 512"
                class="feed-item__icon"
              >
                <path
                  fill="currentColor"
                  d="M344 240H104c-4.4 0-8 3.6-8 8v16c0 4.4 3.6 8 8 8h240c4.4 0 8-3.6 8-8v-16c0-4.4-3.6-8-8-8zm0 96H104c-4.4 0-8 3.6-8 8v16c0 4.4 3.6 8 8 8h240c4.4 0 8-3.6 8-8v-16c0-4.4-3.6-8-8-8zM418.1 0c-5.8 0-11.8 1.8-17.3 5.7L357.3 37 318.7 9.2c-8.4-6-18.2-9.1-28.1-9.1-9.8 0-19.6 3-28 9.1L224 37 185.4 9.2C177 3.2 167.1.1 157.3.1s-19.6 3-28 9.1L90.7 37 47.2 5.7C41.8 1.8 35.8 0 29.9 0 14.4.1 0 12.3 0 29.9v452.3C0 499.5 14.3 512 29.9 512c5.8 0 11.8-1.8 17.3-5.7L90.7 475l38.6 27.8c8.4 6 18.2 9.1 28.1 9.1 9.8 0 19.6-3 28-9.1L224 475l38.6 27.8c8.4 6 18.3 9.1 28.1 9.1s19.6-3 28-9.1l38.6-27.8 43.5 31.3c5.4 3.9 11.4 5.7 17.3 5.7 15.5 0 29.8-12.2 29.8-29.8V29.9C448 12.5 433.7 0 418.1 0zM416 477.8L376 449l-18.7-13.5-18.7 13.5-38.6 27.8c-2.8 2-6 3-9.3 3-3.4 0-6.6-1.1-9.4-3.1L242.7 449 224 435.5 205.3 449l-38.6 27.8c-2.8 2-6 3-9.4 3-3.4 0-6.6-1.1-9.4-3.1L109.3 449l-18.7-13.5L72 449l-40 29.4V34.2L72 63l18.7 13.5L109.4 63 148 35.2c2.8-2 6-3 9.3-3 3.4 0 6.6 1.1 9.4 3.1L205.3 63 224 76.5 242.7 63l38.6-27.8c2.8-2 6-3 9.4-3 3.4 0 6.6 1.1 9.4 3.1L338.7 63l18.7 13.5L376 63l40-28.8v443.6zM344 144H104c-4.4 0-8 3.6-8 8v16c0 4.4 3.6 8 8 8h240c4.4 0 8-3.6 8-8v-16c0-4.4-3.6-8-8-8z"
                  class=""
                ></path>
              </svg>
            </div>
            <div class="column">
              <GameMessageListItem :message="message.message" />
            </div>
          </template>
          <template v-else-if="message.type === 'user_exact_score'">
            <div class="column column--wrap column--no-padding">
              <svg
                xmlns="http://www.w3.org/2000/svg"
                width="24"
                height="24"
                viewBox="0 0 24 24"
                fill="none"
                stroke="currentColor"
                stroke-width="2"
                stroke-linecap="round"
                stroke-linejoin="round"
                class="feather feather-star feed-item__icon"
              >
                <polygon
                  points="12 2 15.09 8.26 22 9.27 17 14.14 18.18 21.02 12 17.77 5.82 21.02 7 14.14 2 9.27 8.91 8.26 12 2"
                ></polygon>
              </svg>
            </div>
            <div class="column">
              <ExactScoreListItem :message="message.message" />
            </div>
          </template>
          <template v-else>
            <span v-text="message.type" />
          </template>
        </div>
      </div>
    </TransitionGroup>
  </div>
</template>

<script setup lang="ts">
const messageStore = useMessageStore();

const hoverClear = ref(false);

const list = computed(() => messageStore.all);

let msgIndex = 0;
onMounted(() => {
  const connection = new WebSocket('wss://api.betty.social/ws');
  connection.onmessage = (event) => {
    const evt = JSON.parse(event.data);
    if (evt.type === 'ping') return;
    if (evt.type === 'evaluate_game') {
      window.dispatchEvent(new Event('game-evaluated'));
    }
    evt.id = msgIndex;
    messageStore.add({ ...evt, timeStamp: new Date() });
    msgIndex += 1;
  };
});

function clearAll() {
  messageStore.clearAll();
}
</script>

<style scoped>
.feed-item {
  border-radius: 4px;
  background: #434f8e;
  color: #fff;
  padding: 0 20px;
  box-shadow: 0 5px 4px -2px rgba(0, 0, 0, 0.5);
  display: flex;
  align-items: center;
  justify-content: flex-start;
  height: 60px;
  margin-bottom: 10px;
  font-size: 13px;
  position: relative;

  & > .row {
    flex: 1;
  }
}

.clear-all-container {
  display: flex;
  justify-content: flex-start;
  align-items: center;
  margin-bottom: 5px;
}

.clear-all {
  background: #434f8e;
  display: flex;
  justify-content: center;
  align-items: center;
  height: 30px;
  width: 30px;
  color: #fff;
  border-radius: 50%;
  font-size: 13px;
  cursor: pointer;
  transition: all 0.2s ease;

  & > svg {
    opacity: 1;
    transition: all 0.2s ease;
  }

  & > span {
    transition: all 0.2s ease;
    opacity: 0;
    white-space: nowrap;
  }

  &:hover {
    width: 100px;
    background: #48569c;
    border-radius: 4px;
    transition: all 0.2s ease;

    & > svg {
      opacity: 0;
    }

    & > span {
      opacity: 1;
    }
  }
}

.feed-item__action {
  position: absolute;
  width: 40px;
  height: 40px;
  border-radius: 50%;
  right: 10px;
  opacity: 0;
  visibility: hidden;
  transition: opacity ease 0.3s;
}

.feed-item:hover .feed-item__action {
  opacity: 1;
  visibility: visible;
}

.feed-item__action__button {
  background: #fff;
  border-radius: 50%;
  padding: 0;
  border: none;
  width: 100%;
  height: 100%;
  display: flex;
  justify-content: center;
  align-items: center;
  cursor: pointer;

  &:hover {
    background: #ccc;
  }
}

.feed-item__icon {
  display: block;
  height: 18px;
  width: auto;
}

.timestamp {
  color: #bbb;
  font-size: 12px;
  text-align: right;
}

.list-enter-active,
.list-leave-active,
.clear-enter-active,
.clear-leave-active {
  transition: all 0.5s ease;
}

.list-enter-from,
.list-leave-to,
.clear-enter-from,
.clear-leave-to {
  opacity: 0;
  transform: translateX(-100%);
}

.list-enter-to {
  opacity: 1;
  transform: translateY(0);
  height: 60px;
}

.clear-enter-to {
  opacity: 1;
  transform: translateY(0);
  height: 30px;
}

.column--no-padding {
  padding-right: 0;
}
</style>
