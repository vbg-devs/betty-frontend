import type { Country } from '~/types';

// Fallback list — replace by /countries response once the backend PR is live.
const FALLBACK_COUNTRIES: Country[] = [
  { code: 'AR', name: 'Argentina', flag_emoji: '🇦🇷' },
  { code: 'AU', name: 'Australia', flag_emoji: '🇦🇺' },
  { code: 'BE', name: 'Belgium', flag_emoji: '🇧🇪' },
  { code: 'BR', name: 'Brazil', flag_emoji: '🇧🇷' },
  { code: 'CA', name: 'Canada', flag_emoji: '🇨🇦' },
  { code: 'DK', name: 'Denmark', flag_emoji: '🇩🇰' },
  { code: 'FI', name: 'Finland', flag_emoji: '🇫🇮' },
  { code: 'FR', name: 'France', flag_emoji: '🇫🇷' },
  { code: 'DE', name: 'Germany', flag_emoji: '🇩🇪' },
  { code: 'IS', name: 'Iceland', flag_emoji: '🇮🇸' },
  { code: 'IT', name: 'Italy', flag_emoji: '🇮🇹' },
  { code: 'JP', name: 'Japan', flag_emoji: '🇯🇵' },
  { code: 'MX', name: 'Mexico', flag_emoji: '🇲🇽' },
  { code: 'NL', name: 'Netherlands', flag_emoji: '🇳🇱' },
  { code: 'NO', name: 'Norway', flag_emoji: '🇳🇴' },
  { code: 'PL', name: 'Poland', flag_emoji: '🇵🇱' },
  { code: 'PT', name: 'Portugal', flag_emoji: '🇵🇹' },
  { code: 'ES', name: 'Spain', flag_emoji: '🇪🇸' },
  { code: 'SE', name: 'Sweden', flag_emoji: '🇸🇪' },
  { code: 'CH', name: 'Switzerland', flag_emoji: '🇨🇭' },
  { code: 'GB', name: 'United Kingdom', flag_emoji: '🇬🇧' },
  { code: 'US', name: 'United States', flag_emoji: '🇺🇸' },
];

const countries = ref<Country[]>([]);
const loaded = ref(false);
const loading = ref(false);

export function useCountries() {
  const { authFetch } = useApi();

  async function load() {
    if (loaded.value || loading.value) return countries.value;
    loading.value = true;
    try {
      const data = await authFetch<Country[]>('/countries');
      countries.value = (data ?? []).slice().sort((a, b) => a.name.localeCompare(b.name));
      if (countries.value.length === 0) countries.value = FALLBACK_COUNTRIES;
    } catch {
      countries.value = FALLBACK_COUNTRIES;
    } finally {
      loaded.value = true;
      loading.value = false;
    }
    return countries.value;
  }

  return { countries, load, loading, loaded };
}
