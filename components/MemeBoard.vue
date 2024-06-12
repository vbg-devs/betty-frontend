<template>
  <div class="meme-board">
    <header class="meme-board__header"></header>
    <section class="meme-board__body">
      <div v-for="message in messages" :key="message.id" class="meme-board__message">
        <div class="row">
          <div class="column column--wrap">
            <user-badge :user="message.user"></user-badge>
          </div>
          <div class="column">
            <div class="meme-board__username">
              <strong>{{ message.user.name }}</strong> - {{ message.date.toLocaleString() }}
            </div>
            <template v-if="message.image">
              <img :src="message.image.images.original.url" class="message__image">
            </template>
            <template v-else>
              <p>{{ message.message }}</p>
            </template>
          </div>
        </div>
      </div>
    </section>
    <footer class="meme-board__footer">
      <div class="meme-board__form">
        <input v-model="q" placeholder="Send message to group" t type="text" class="meme-board__input" @keyup="handleKeyup">
        <div v-show="loading" class="meme-board__spinner">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 100 100" preserveAspectRatio="xMidYMid" width="34" height="34" style="shape-rendering: auto; display: block; background: rgb(255, 255, 255);" xmlns:xlink="http://www.w3.org/1999/xlink">
            <g>
              <g transform="rotate(0 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.9166666666666666s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(30 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.8333333333333334s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(60 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.75s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(90 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.6666666666666666s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(120 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.5833333333333334s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(150 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.5s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(180 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.4166666666666667s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(210 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.3333333333333333s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(240 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.25s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(270 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.16666666666666666s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(300 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="-0.08333333333333333s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g transform="rotate(330 50 50)">
                <rect fill="#434f8e" height="12" width="6" ry="6" rx="3" y="24" x="47">
                  <animate repeatCount="indefinite" begin="0s" dur="1s" keyTimes="0;1" values="1;0" attributeName="opacity"></animate>
                </rect>
              </g>
              <g></g>
            </g><!-- [ldio] generated by https://loading.io -->
          </svg>
        </div>
        <button class="meme-board__toggle" aria-label="Send gif (Shift + Enter)" data-balloon-pos="up" :class="{ 'meme-board__toggle--active': useGiphy }" @click="useGiphy = !useGiphy">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 576 512">
            <path fill="currentColor" d="M512 80c8.8 0 16 7.2 16 16V416c0 8.8-7.2 16-16 16H64c-8.8 0-16-7.2-16-16V96c0-8.8 7.2-16 16-16H512zM64 32C28.7 32 0 60.7 0 96V416c0 35.3 28.7 64 64 64H512c35.3 0 64-28.7 64-64V96c0-35.3-28.7-64-64-64H64zM296 160c-13.3 0-24 10.7-24 24V328c0 13.3 10.7 24 24 24s24-10.7 24-24V184c0-13.3-10.7-24-24-24zm56 24v80 64c0 13.3 10.7 24 24 24s24-10.7 24-24V288h40c13.3 0 24-10.7 24-24s-10.7-24-24-24H400V208h64c13.3 0 24-10.7 24-24s-10.7-24-24-24H376c-13.3 0-24 10.7-24 24zM128 256c0-26.5 21.5-48 48-48c8 0 15.4 1.9 22 5.3c11.8 6.1 26.3 1.5 32.3-10.3s1.5-26.3-10.3-32.3c-13.2-6.8-28.2-10.7-44-10.7c-53 0-96 43-96 96s43 96 96 96c19.6 0 37.5-6.1 52.8-15.8c7-4.4 11.2-12.1 11.2-20.3V264c0-13.3-10.7-24-24-24H184c-13.3 0-24 10.7-24 24s10.7 24 24 24h8v13.1c-5.3 1.9-10.6 2.9-16 2.9c-26.5 0-48-21.5-48-48z" />
          </svg>
        </button>
      </div>
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
      useGiphy: false,
      messages: [],
      loading: false,
    };
  },
  computed: {
    ...mapGetters({
      user: 'user/profile',
    }),
  },
  methods: {
    handleKeyup(ev) {
      if (ev.shiftKey && ev.code === 'Enter') {
        this.test(true);
        return;
      }
      if (ev.code === 'Enter') {
        this.test();
      }
    },
    async test(override) {
      if (!this.q) return;
      if (!this.useGiphy && !override) {
        this.messages.push({
          id: (this.messages.length + 1),
          date: new Date(),
          image: undefined,
          message: this.q,
          user: this.user,
        });
        this.q = '';
        return;
      }
      if (this.loading) return;
      this.loading = true;
      gf.search(this.q, { limit: 10 }).then((res) => {
        if (res.data.length) {
          this.messages.push({
            id: (this.messages.length + 1),
            date: new Date(),
            image: res.data[0],
            user: this.user,
          });
        }
        this.q = '';
        this.loading = false;
      });
    },
  },
};
</script>

<style lang="less" scoped>
.meme-board__body {
  max-height: 600px;
  min-height: 1;
  overflow-y: auto;
  padding-right: 10px;
}

.message__image {
  display: block;
  max-width: 100%;
  height: auto;
  max-height: 300px;
  border-radius: 8px;
}

.meme-board__footer {
  padding-top: 30px;
}

.meme-board__message {
  margin-bottom: 15px;
  padding-bottom: 15px;
  border-bottom: 1px solid #efefef;
}

// .meme-board__message:first-child {
//   border-top: none;
// }

.meme-board__input {
  width: 100%;
  padding: 10px;
  border: 1px solid #efefef;
  border-radius: 4px;
  outline: none;
  font-family: inherit;
}

.meme-board .row {
  margin: 0;
  gap: 10px;
}

.meme-board__username {
  font-size: 14px;
  margin-bottom: 10px;
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
  top: 0;
  border: none;
  background: transparent;
  padding: 0;
  top: 50%;
  transform: translateY(-50%);
  cursor: pointer;
  color: #eee;
}

.meme-board__toggle--active {
  color: #434f8e;
}

.meme-board__toggle svg {
  display: block;
  height: 26px;
  width: auto;
}

.meme-board__spinner {
  position: absolute;
  right: 40px;
  top: 50%;
  transform: translateY(-50%);
}
</style>
