import type { UserProfile } from '~/types';

export const useUserStore = defineStore('user', () => {
  const user = ref<UserProfile | null>(null);

  const id = computed(() => user.value?.id);
  const email = computed(() => user.value?.email);
  const isAdmin = computed(() => user.value?.is_admin);
  const profile = computed(() => user.value);

  function set(payload: UserProfile | null) {
    user.value = payload;
  }

  return { user, id, email, isAdmin, profile, set };
});
