import * as Sentry from '@sentry/nuxt';

// @sentry/nuxt v9 ignores a `sentry.dsn` key in nuxt.config — the DSN must be
// initialized here. Guarded so dev servers and vitest runs don't report.
if (import.meta.env.PROD) {
  Sentry.init({
    dsn: 'https://b938ff1b3bb541738a2dea8180b92cad@o86153.ingest.sentry.io/5813126',
  });
}
