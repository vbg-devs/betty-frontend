import type { ActivityMessage } from '~/types';

export const useMessageStore = defineStore('message', () => {
  const messages = ref<ActivityMessage[]>([]);

  const all = computed(() => messages.value);

  function add(payload: ActivityMessage) {
    messages.value.push(payload);
    if (messages.value.length > 5) {
      messages.value.splice(0, messages.value.length - 5);
    }
  }

  function remove(payload: { id: number }) {
    const index = messages.value.findIndex((x) => x.id === payload.id);
    if (index > -1) {
      messages.value.splice(index, 1);
    }
  }

  function clearAll() {
    messages.value = [];
  }

  return { messages, all, add, remove, clearAll };
});
