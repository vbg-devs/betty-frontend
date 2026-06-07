<template>
  <div>
    <transition name="page">
      <div v-if="loading" class="loader">
        <img src="~/assets/images/logo.svg" />
        <img src="~/assets/images/spinner.svg" class="loader__icon" />
      </div>
    </transition>
    <transition name="page">
      <join-group-modal v-if="!loading && group" :group="group"></join-group-modal>
    </transition>
    <transition name="page">
      <div v-if="!loading && !group" class="join-error">
        <h1 class="page-title">Could not load this invite</h1>
        <p class="join-error__message">
          The invite link may be invalid or expired. Please check the link and try again.
        </p>
        <NuxtLink to="/dashboard" class="button button--action">Go to dashboard</NuxtLink>
      </div>
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
  } catch (err) {
    console.error(err);
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.join-error {
  max-width: 480px;
  margin: 60px auto;
  text-align: center;
}

.join-error__message {
  margin-bottom: 24px;
}
</style>
