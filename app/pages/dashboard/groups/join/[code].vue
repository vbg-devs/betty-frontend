<template>
  <div>
    <transition name="page">
      <div v-if="loading" class="loader">
        <img src="~/assets/images/logo.svg" />
        <img src="~/assets/images/spinner.svg" class="loader__icon" />
      </div>
    </transition>
    <transition name="page">
      <join-group-modal v-if="!loading" :group="group"></join-group-modal>
    </transition>
  </div>
</template>

<script setup lang="ts">
const route = useRoute();
const { authFetch } = useApi();

const loading = ref(true);
const group = ref<any>(null);

onMounted(async () => {
  try {
    const data = await authFetch<any>(`/group/${route.params.code}`);
    group.value = data;
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped></style>
