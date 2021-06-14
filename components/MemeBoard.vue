<template>
  <div class="meme-board">
    <header class="meme-board__header"></header>
    <section class="meme-board__body">
      <div v-for="message in messages" :key="message.id">
        <div class="row">
          <div class="column column--wrap">
            <user-badge :user="message.user"></user-badge>
          </div>
          <div class="column">
            <strong>{{ message.user.name }}</strong>
            <img :src="message.image.images.original.url" class="message__image">
          </div>
        </div>
      </div>
    </section>
    <footer class="meme-board__footer">
      <form @submit.prevent="test">
        <input v-model="q" type="text">
      </form>
    </footer>

  </div>
</template>

<script>
import { GiphyFetch } from '@giphy/js-fetch-api';
import { mapGetters } from 'vuex'; //eslint-disable-line  
import UserBadge from './UserBadge.vue';

const gf = new GiphyFetch('EUSX9DmpuBQafmcrIeKL9jNl5ES91X9r');
export default {
  name: 'MemeBoard',
  components: { UserBadge },
  data() {
    return {
      q: '',
      messages: [],
    };
  },
  computed: {
    ...mapGetters({
      user: 'user/profile',
    }),
  },
  methods: {
    async test() {
      gf.search(this.q, { limit: 10 }).then((res) => {
        this.messages.push({
          id: (this.messages.length + 1),
          image: res.data[0],
          user: this.user,
        });
        this.q = '';
      });
    },
  },
};
</script>

<style lang="less" scoped>
.meme-board__body {
  max-height: 600px;
  min-height: 1;
  overflow-y: scroll;
}

.message__image {
  display: block;
  max-width: 100%;
  height: auto;
}
</style>
