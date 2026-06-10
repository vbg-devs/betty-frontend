export default defineNuxtConfig({
  compatibilityDate: '2025-01-01',
  // Hybrid rendering: public marketing pages are prerendered to real HTML for
  // SEO; everything else stays a pure client-side SPA (ssr: false catch-all).
  ssr: true,

  routeRules: {
    '/': { prerender: true, ssr: true },
    '/privacy': { prerender: true, ssr: true },
    '/support': { prerender: true, ssr: true },
    '/**': { ssr: false },
  },

  modules: ['@pinia/nuxt', 'nuxt-gtag', '@sentry/nuxt/module'],

  app: {
    head: {
      title: 'Betty.social \u2014 Creating frenemies since 2021',
      meta: [
        { charset: 'utf-8' },
        { name: 'viewport', content: 'width=device-width, initial-scale=1, maximum-scale=1' },
        {
          name: 'description',
          content:
            'Place friendly bets with your friends on any sport, track every score, and crown a champion. Betty keeps the receipts so the group chat can keep the smack talk.',
        },
        { property: 'og:title', content: 'Betty.social \u2014 Creating frenemies since 2021' },
        { property: 'og:site_name', content: 'Betty.social' },
        { property: 'og:image', content: 'https://betty.social/shareimage.jpg' },
        { property: 'og:image:secure_url', content: 'https://betty.social/shareimage.jpg' },
        { property: 'og:image:type', content: 'image/jpeg' },
        { property: 'og:image:width', content: '1200' },
        { property: 'og:image:height', content: '630' },
        { property: 'og:image:alt', content: 'Betty.social \u2014 Creating frenemies since 2021' },
        { property: 'og:url', content: 'https://betty.social' },
        {
          property: 'og:description',
          content:
            'Place friendly bets with your friends on any sport, track every score, and crown a champion. Betty keeps the receipts so the group chat can keep the smack talk.',
        },
        { property: 'og:type', content: 'website' },
        { name: 'twitter:card', content: 'summary_large_image' },
        { name: 'twitter:title', content: 'Betty.social \u2014 Creating frenemies since 2021' },
        {
          name: 'twitter:description',
          content:
            'Place friendly bets with your friends on any sport, track every score, and crown a champion. Betty keeps the receipts so the group chat can keep the smack talk.',
        },
        { name: 'twitter:image', content: 'https://betty.social/shareimage.jpg' },
        {
          name: 'keywords',
          content:
            'friendly betting, social betting app, bet with friends, group bets, sports predictions, prediction game, bet tracker, leaderboard, world cup 2026, betty social',
        },
      ],
      htmlAttrs: { lang: 'en' },
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
});
