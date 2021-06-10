<template>
  <div>
    <div v-for="message in list" :key="message.id" class="feed-item">
      <div class="timestamp">
        {{ message.timeStamp | format }}
      </div>
      <div class="row row--center-v">
        <template v-if="message.type === 'bet_placed'">
          <div class="column column--wrap">
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
          <div class="column column--wrap">
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
          <div class="column column--wrap">
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
        <template v-else-if="message.type === 'group_created'">
          <div class="column column--wrap">
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
          <div class="column column--wrap">
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
    </div>
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
      that.list.push({ ...evt, timeStamp: new Date() });
      msgIndex += 1;
    };
  },
};
</script>

<style lang="less" scoped>
.feed-item {
  border-bottom: 1px solid #f2f2f2;
  padding: 10px 10px 0;
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
</style>
