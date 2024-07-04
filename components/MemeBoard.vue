<template>
  <div class="meme-board">
    <header class="meme-board__header"></header>
    <section class="meme-board__body">
      <div v-show="images.length" class="gif-selector">
        <div>
          <strong>Select gif</strong>
        </div>
        <div class="gif-selector__image-wrapper">
          <img :src="selectedPreviewImage">
        </div>
        <div class="gif-selector__buttons">
          <button class="button button--action" :disabled="selectedImageIndex === 0" @click="prevImage">Prev</button>
          <button class="button button--action" :disabled="selectedImageIndex === images.length - 1" @click="nextImage">Next</button>
          &nbsp;
          <button class="button button--select" @click="selectImage">Submit</button>
          <button class="button button--danger" @click="cancelImageSelection">Cancel</button>
        </div>
      </div>
      <div v-for="message in messages" :key="message.id" class="meme-board__message">
        <div class="row">
          <div class="column column--wrap">
            <user-badge :user="getUser(message.user_id)"></user-badge>
          </div>
          <div class="column">
            <div class="meme-board__username">
              <strong>{{ getUser(message.user_id).name }}</strong>
              - {{ formatDate(message.created_at) }}
            </div>
            <template v-if="message.image_url">
              <img :src="message.image_url" class="message__image">
            </template>
            <template v-else>
              <p>{{ message.body }}</p>
            </template>
          </div>
        </div>
      </div>
    </section>
    <footer class="meme-board__footer">
      <div class="meme-board__form">
        <input v-model="q" placeholder="Send message to group" type="text" class="meme-board__input" @keyup="handleKeyup">
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
        <button class="meme-board__toggle" aria-label="Send gif (Shift + Enter)" data-balloon-pos="left" :class="{ 'meme-board__toggle--active': useGiphy }" @click="useGiphy = !useGiphy">
          <svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24" color="currentColor" fill="none">
            <path d="M14.8597 22H10.548C7.25691 22 5.61139 22 4.46864 21.2022C4.14123 20.9736 3.85055 20.7025 3.60545 20.3971C2.75 19.3313 2.75 17.7966 2.75 14.7273V12.1818C2.75 9.21865 2.75 7.73706 3.22323 6.55375C3.98399 4.65142 5.5929 3.15088 7.63261 2.44135C8.90137 2 10.4899 2 13.6671 2C15.4827 2 16.3904 2 17.1154 2.2522C18.2809 2.65765 19.2003 3.5151 19.635 4.60214C19.9055 5.27832 19.9055 6.12494 19.9055 7.81818V10" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
            <path d="M2.75 12C2.75 10.1591 4.25603 8.66667 6.11381 8.66667C6.78569 8.66667 7.57779 8.78333 8.23104 8.60988C8.81145 8.45576 9.2648 8.00652 9.42033 7.43136C9.59536 6.78404 9.47763 5.99912 9.47763 5.33333C9.47763 3.49238 10.9837 2 12.8414 2" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
            <path d="M12.842 18H15.3648M10.416 13.8506C10.2901 13.0495 10.1346 13.0487 8.8054 13H7.79626C7.23892 13 6.78711 13.4477 6.78711 14L6.78711 17C6.78711 17.5523 7.23892 18 7.79625 18H9.61272C10.0029 18 10.416 17.6866 10.416 17.3V16.2C10.416 16.0895 10.3034 15.896 10.1919 15.896H9.06776M12.842 13H14.1034M14.1034 13H15.3648M14.1034 13V17.8749M21.2511 13H18.7283C18.1709 13 17.7191 13.4477 17.7191 14V15.5M17.7191 15.5V18M17.7191 15.5H20.242" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round" />
          </svg>
        </button>
      </div>
    </footer>
  </div>
</template>

<script>
import { formatDistance } from 'date-fns';
import firebase from 'firebase/app';
import 'firebase/auth';

import { GiphyFetch } from '@giphy/js-fetch-api';
import { mapGetters } from 'vuex'; //eslint-disable-line  
import UserBadge from './UserBadge.vue';

const gf = new GiphyFetch('EUSX9DmpuBQafmcrIeKL9jNl5ES91X9r');
export default {
  name: 'MemeBoard',
  components: { UserBadge },
  props: {
    members: {
      type: Array,
      default: () => [],
    },
  },
  data() {
    return {
      q: '',
      useGiphy: false,
      messages: [],
      loading: false,
      images: [],
      selectedImageIndex: 0,
      timer: null,
    };
  },
  computed: {
    ...mapGetters({
      user: 'user/profile',
    }),
    selectedPreviewImage() {
      return this.images[this.selectedImageIndex]?.images.original.url;
    },
  },
  async mounted() {
    this.timer = setInterval(this.loadMessages, 10000);
    this.loadMessages();
  },
  beforeDestroy() { //eslint-disable-line
    if (this.timer) {
      clearInterval(this.timer);
      this.timer = null;
    }
  },
  methods: {
    async loadMessages() {
      const user = firebase.auth().currentUser;
      const token = await user.getIdToken();
      this.$axios.get(`https://api.betty.social/api/v1/messageboard/${this.$route.params.id}`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((response) => {
        this.messages = response.data;
      }).catch((err) => {
        console.error(err);
      });
    },
    cancelImageSelection() {
      this.images = [];
      this.selectedImageIndex = 0;
    },
    nextImage() {
      this.selectedImageIndex += 1;
    },
    prevImage() {
      this.selectedImageIndex -= 1;
    },
    formatDate(date) {
      return formatDistance(new Date(date), new Date(), { addSuffix: true });
    },
    getUser(userId) {
      return this.members.find((member) => member.user_id === userId);
    },
    handleKeyup(ev) {
      if (ev.shiftKey && ev.code === 'Enter') {
        this.test(true);
        return;
      }
      if (ev.code === 'Enter') {
        this.test();
      }
    },
    async postMessage(message) {
      const user = firebase.auth().currentUser;
      const token = await user.getIdToken();
      this.$axios.post('https://api.betty.social/api/v1/messageboard', {
        group_id: parseFloat(this.$route.params.id),
        body: message.message,
        image_url: message.image,
      }, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((res) => {
        console.log(res);
        this.messages.unshift(res.data);
        this.images = [];
        this.selectedImageIndex = 0;
      });
    },
    selectImage() {
      const newMessage = {
        image: this.selectedPreviewImage,
        user: this.user,
      };
      this.postMessage(newMessage);
    },
    async test(override) {
      if (!this.q) return;
      if (!this.useGiphy && !override) {
        const newMessage = {
          image: undefined,
          message: this.q,
        };
        this.postMessage(newMessage);
        this.q = '';
        return;
      }
      if (this.loading) return;
      this.loading = true;
      gf.search(this.q, { limit: 10 }).then((res) => {
        if (res.data.length) {
          this.images = res.data;
          // const newMessage = {
          //   image: res.data[0].images.original.url,
          //   user: this.user,
          // };
          // this.postMessage(newMessage);
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
  max-height: 400px;
  min-height: 1;
  overflow-y: auto;
  padding-right: 10px;
  display: flex;
  flex-direction: column-reverse;
}

@media(min-width: 768px) {
  .meme-board__body {
    max-height: 800px;
  }
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

.gif-selector {
  background: #fbfbfb;
  padding: 10px;
  border-radius: 4px;
}

.gif-selector__image-wrapper {
  margin: 10px 0;
}

.gif-selector__buttons {
  display: flex;
  gap: 8px;
}

.button--select {
  background: #434f8e;
}

.gif-selector img {
  max-height: 300px;
  width: auto;
  max-width: 100%;
  border-radius: 8px;
  display: block;
}
</style>
