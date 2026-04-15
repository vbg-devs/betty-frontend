const API_BASE = 'https://api.betty.social/api/v1';

export function useApi() {
  async function authFetch<T>(path: string, options: Parameters<typeof $fetch>[1] = {}) {
    const token = await useAuthToken();
    return $fetch<T>(`${API_BASE}${path}`, {
      ...options,
      headers: {
        ...(options.headers as Record<string, string>),
        Authorization: `Bearer ${token}`,
      },
    });
  }

  return { authFetch };
}
