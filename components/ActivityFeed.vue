<template>
  <div>
    <div v-for="message in list" :key="message.id" class="feed-item">
      <template v-if="message.type === 'user_register'">
        <game-bet :bet="message.message"></game-bet>
        {{ message }}
      </template>
      <template v-else>
        <span v-text="message.type" />
      </template>
    </div>
  </div>
</template>

<script>
export default {
  name: 'ActivityFeed',
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
  padding: 10px;
}
</style>
