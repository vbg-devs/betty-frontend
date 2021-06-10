export default {
  ssr: false,
  // Global page headers: https://go.nuxtjs.dev/config-head
  head: {
    title: 'Betty.social - The go to place for friendly betting',
    meta: [
      { charset: 'utf-8' },
      { name: 'viewport', content: 'width=device-width, initial-scale=1' },
      { hid: 'description', name: 'description', content: 'Betty is your personal assistant who keeps track of everyones bets and scores and let´s you relax, sit back and enjoy the European Cup.' },
      { hid: 'og:title', property: 'og:title', content: 'Betty' },
      { hid: 'og:image', property: 'og:image', content: 'https://betty.social/apple-touch-icon.png' },
      { hid: 'og:description', property: 'og:description', content: 'Betty is your personal assistant who keeps track of everyones bets and scores and let´s you relax, sit back and enjoy the European Cup.' },
      { hid: 'og:type', property: 'og:type', content: 'website' },
      { hid: 'keywords', name: 'keywords', content: 'betting, bet pool, euro2021, eur2020, betty, friendly bets' },
    ],
    link: [
      { rel: 'apple-touch-icon', sizes: '180x180', href: '/apple-touch-icon.png' },
      {
        rel: 'icon', type: 'image/png', sizes: '32x32', href: '/favicon-32x32.png',
      },
      {
        rel: 'icon', type: 'image/png', sizes: '16x16', href: '/favicon-16x16.png',
      },
      { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
      { rel: 'stylesheet', href: 'https://fonts.googleapis.com/css2?family=Inter:wght@100;200;300;400;500;600;700;800;900&display=swap' },
    ],
  },

  // Global CSS: https://go.nuxtjs.dev/config-css
  css: [
  ],

  // Plugins to run before rendering page: https://go.nuxtjs.dev/config-plugins
  plugins: [
  ],

  // Auto import components: https://go.nuxtjs.dev/config-components
  components: true,

  // Modules for dev and build (recommended): https://go.nuxtjs.dev/config-modules
  buildModules: [
    // https://go.nuxtjs.dev/eslint
    '@nuxtjs/eslint-module',
  ],

  // Modules: https://go.nuxtjs.dev/config-modules
  modules: [
    // https://go.nuxtjs.dev/axios
    '@nuxtjs/axios',
    // https://go.nuxtjs.dev/pwa
    '@nuxtjs/pwa',
    '@nuxtjs/google-gtag',
  ],
  'google-gtag': {
    id: 'G-71Z91KX62G',
  },

  // Axios module configuration: https://go.nuxtjs.dev/config-axios
  axios: {},

  // PWA module configuration: https://go.nuxtjs.dev/pwa
  pwa: {
    manifest: {
      lang: 'en',
    },
  },

  // Build Configuration: https://go.nuxtjs.dev/config-build
  build: {
  },
};
