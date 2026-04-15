<template>
  <NuxtLink v-if="tournament" :to="`/dashboard/groups/${group.id}`">
    <Card class="card--clickable">
      <template #header>
        <div
          class="card__header__image"
          :style="{ backgroundImage: `url(${tournament.image_url})` }"
        ></div>
        <div class="card__header__details row row--bottom-v">
          <div class="column">
            <h1 class="card__header__title">
              {{ group.name }}
            </h1>
            <div class="card__header__sub-title">
              {{ tournament.name }}
            </div>
          </div>
        </div>
      </template>
      <div>{{ group.members.length }} members</div>
    </Card>
  </NuxtLink>
</template>

<script setup lang="ts">
const { group = {} as Record<string, any> } = defineProps<{
  group?: Record<string, any>;
}>();

const tournament = computed(() => group.tournament);
</script>

<style scoped>
.card__header__details {
  padding: 5px;
  margin: 0;
  padding-top: 20px;
}

.group__image {
  display: block;
  border-radius: 50%;
  border: 2px solid #fff;
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  height: 32px;
  width: 32px;
}

.column {
  padding: 5px;
}

.card__header__title {
  font-size: 16px;
  margin: 0;
}

.card__header__sub-title {
  font-size: 12px;
}

.tournament__image {
  max-height: 200px;
}
</style>
