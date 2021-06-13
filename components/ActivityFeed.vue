<template>
  <div>
    <transition-group name="list" tag="div">
      <div v-for="message in list" :key="message.id" class="feed-item">
        <!-- <div class="timestamp">
          {{ message.timeStamp | format }}
        </div> -->
        <div class="row row--center-v">
          <template v-if="message.type === 'bet_placed'">
            <div class="column column--wrap column--no-padding">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-user-check feed-item__icon">
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <polyline points="17 11 19 13 23 9"></polyline>
              </svg>
            </div>
            <div class="column">
              <game-bet-list-item :bet="message.message"></game-bet-list-item>
            </div>
          </template>
          <template v-else-if="message.type === 'bet_updated'">
            <div class="column column--wrap column--no-padding">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-user-check feed-item__icon">
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <polyline points="17 11 19 13 23 9"></polyline>
              </svg>
            </div>
            <div class="column">
              <game-bet-list-item :bet="message.message" :update="true"></game-bet-list-item>
            </div>
          </template>
          <template v-else-if="message.type === 'group_joined'">
            <div class="column column--wrap column--no-padding">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-user-check feed-item__icon">
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <polyline points="17 11 19 13 23 9"></polyline>
              </svg>
            </div>
            <div class="column">
              <group-joined-list-item :data="message.message"></group-joined-list-item>
            </div>
          </template>
          <template v-else-if="message.type === 'group_left'">
            <div class="column column--wrap column--no-padding">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-user-x feed-item__icon">
                <path d="M16 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="8.5" cy="7" r="4"></circle>
                <line x1="18" y1="8" x2="23" y2="13"></line>
                <line x1="23" y1="8" x2="18" y2="13"></line>
              </svg>
            </div>
            <div class="column">
              <div class="feed-item__label">
                Someone just left a group 😭
              </div>
            </div>
          </template>
          <template v-else-if="message.type === 'group_created'">
            <div class="column column--wrap column--no-padding">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-users feed-item__icon">
                <path d="M17 21v-2a4 4 0 0 0-4-4H5a4 4 0 0 0-4 4v2"></path>
                <circle cx="9" cy="7" r="4"></circle>
                <path d="M23 21v-2a4 4 0 0 0-3-3.87"></path>
                <path d="M16 3.13a4 4 0 0 1 0 7.75"></path>
              </svg>
            </div>
            <div class="column">
              <div class="feed-item__label">
                New group created!
              </div>
            </div>
          </template>
          <template v-else-if="message.type === 'user_register'">
            <div class="column column--wrap column--no-padding">
              <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-user-plus feed-item__icon">
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
          <template v-else>
            <span v-text="message.type" />
          </template>
        </div>
        <div class="feed-item__action">
          <button class="feed-item__action__button" @click="deleteMessage(message)">
            <svg xmlns="http://www.w3.org/2000/svg" width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round" class="feather feather-trash-2">
              <polyline points="3 6 5 6 21 6"></polyline>
              <path d="M19 6v14a2 2 0 0 1-2 2H7a2 2 0 0 1-2-2V6m3 0V4a2 2 0 0 1 2-2h4a2 2 0 0 1 2 2v2"></path>
              <line x1="10" y1="11" x2="10" y2="17"></line>
              <line x1="14" y1="11" x2="14" y2="17"></line>
            </svg>
          </button>
        </div>
      </div>
    </transition-group>
  </div>
</template>

<script>
import { format } from 'date-fns';

export default {
  name: 'ActivityFeed',
  filters: {
    format(input) {
      return format(input, 'HH:mm');
    },
  },
  data() {
    return {
      list: [],
      interval: null,
    };
  },
  async fetch() {
    const connection = new WebSocket('wss://betty-prod.herokuapp.com/ws');
    const that = this;
    let msgIndex = 0;
    connection.onmessage = (event) => {
      const evt = JSON.parse(event.data);
      if (evt.type === 'ping') return;
      evt.id = msgIndex;
      if (this.list.length === 5) {
        this.list.splice(0, 1);
      }
      that.list.push({ ...evt, timeStamp: new Date() });
      msgIndex += 1;
    };
  },
  methods: {
    deleteMessage(message) {
      const index = this.list.findIndex((x) => x.id === message.id);
      if (index > -1) {
        this.list.splice(index, 1);
      }
    },
  },
  // mounted() {
  //   this.interval = setInterval(() => {
  //     if (this.list.length === 0) return;
  //     this.list.splice(0, 1);
  //   }, 10000);
  // },
  // beforeDestroy() {
  //   if (this.interval === null) return;
  //   clearInterval(this.interval);
  //   this.interval = null;
  // },
};
</script>

<style lang="less" scoped>
.feed-item {
  border-radius: 50px;
  background: #0a158e;
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

// .feed-item .row {
//   margin: 0;
// }

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
.list-leave-active {
  transition: all 0.5s ease;
}
.list-enter-from,
.list-leave-to {
  opacity: 0;
  transform: translateX(-100%);
}
.list-enter {
  opacity: 0;
  transform: translateY(100%);
  height: 0;
}
.list-enter-to {
  opacity: 1;
  transform: translateY(0);
  height: 60px;
}

.column--no-padding {
  padding-right: 0;
}
</style>
