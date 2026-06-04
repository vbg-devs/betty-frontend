export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  ssr: false,

  modules: ['@pinia/nuxt', 'nuxt-gtag', '@sentry/nuxt/module'],

  app: {
    head: {
      title: 'Betty.social - The go to place for friendly betting',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1, maximum-scale=1' },
        {
          name: 'description',
          content:
            'Betty is your personal assistant who keeps track of everyones bets and scores and let\u00b4s you relax, sit back and enjoy the World Cup.',
        },
        { property: 'og:title', content: 'Betty' },
        { property: 'og:image', content: 'https://betty.social/shareimage.jpg' },
        { property: 'og:image:secure_url', content: 'https://betty.social/shareimage.jpg' },
        { property: 'og:image:type', content: 'image/jpeg' },
        { property: 'og:image:width', content: '1200' },
        { property: 'og:image:height', content: '630' },
        { property: 'og:image:alt', content: 'Betty.social - The go to place for friendly betting' },
        { property: 'og:url', content: 'https://betty.social' },
        {
          property: 'og:description',
          content:
            'Betty is your personal assistant who keeps track of everyones bets and scores and let\u00b4s you relax, sit back and enjoy the World Cup.',
        },
        { property: 'og:type', content: 'website' },
        { name: 'twitter:card', content: 'summary_large_image' },
        { name: 'twitter:title', content: 'Betty' },
        { name: 'twitter:description', content: 'Betty is your personal assistant who keeps track of everyones bets and scores and let\u00b4s you relax, sit back and enjoy the World Cup.' },
        { name: 'twitter:image', content: 'https://betty.social/shareimage.jpg' },
        { name: 'keywords', content: 'betting, bet pool, euro2021, eur2020, betty, friendly bets' },
      ],
      link: [
        { rel: 'apple-touch-icon', sizes: '180x180', href: '/apple-touch-icon.png' },
        { rel: 'icon', type: 'image/png', sizes: '32x32', href: '/favicon-32x32.png' },
        { rel: 'icon', type: 'image/png', sizes: '16x16', href: '/favicon-16x16.png' },
        { rel: 'icon', type: 'image/x-icon', href: '/favicon.ico' },
      ],
    },
  },

  css: ['~/assets/css/global.css', 'balloon-css/balloon.min.css'],

  gtag: {
    id: 'G-71Z91KX62G',
  },

  sentry: {
    dsn: 'https://b938ff1b3bb541738a2dea8180b92cad@o86153.ingest.sentry.io/5813126',
  },
});
