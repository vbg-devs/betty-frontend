<template>
  <div>
    activity
    <div v-for="l in list" v-bind:key="l.msgIndex">
      <span v-text="l.type" />
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
    console.log(this.list);
    const that = this;
    let msgIndex = 0;
    connection.onmessage = (event) => {
      const evt = JSON.parse(event.data);

      console.log('type', evt.type);
      console.log('messag', evt.message);
      evt.msgIndex = msgIndex;
      that.list.push(evt);
      msgIndex += 1;
    };
  },
};
</script>

<style>
</style>
