<template>
  <div class="leaderboard">
    <div
      v-for="user in listWithPlacement"
      :key="user.user_id"
      class="lb-row"
      :class="{
        'lb-row--you': user.user_id === userId,
        'lb-row--first': user.place === 1,
        'lb-row--second': user.place === 2,
        'lb-row--third': user.place === 3,
      }"
    >
      <div class="lb-row__place">
        {{ String(user.place).padStart(2, '0') }}
      </div>
      <div class="lb-row__avatar">
        <UserBadge :user="user" :small="true" :clickable="false" :block="true" />
      </div>
      <div class="lb-row__name">
        <template v-if="global">
          <NuxtLink :to="`/user/${user.user_id}`" class="lb-row__link">
            {{ user.name }}
          </NuxtLink>
        </template>
        <template v-else>
          <a href="javascript:void(0);" class="lb-row__link" @click="emit('user-selected', user)">{{
            user.nickname || user.name
          }}</a>
        </template>
        <span v-if="user.user_id === userId" class="lb-row__you">YOU</span>
      </div>
      <div class="lb-row__score">
        <span class="lb-row__score-value">{{
          global ? user.normalized_score : user.score
        }}</span>
        <span class="lb-row__score-unit">P</span>
      </div>
    </div>
  </div>
</template>

<script setup lang="ts">
const { users = [], global = false } = defineProps<{
  users?: any[];
  global?: boolean;
}>();

const emit = defineEmits<{
  'user-selected': [user: any];
}>();

const userStore = useUserStore();

const userId = computed(() => userStore.id);

const orderedList = computed(() => {
  const list = users.concat();
  if (global) {
    list.sort((a: any, b: any) => b.normalized_score - a.normalized_score);
  } else {
    list.sort((a: any, b: any) => b.score - a.score);
  }
  return list;
});

const listWithPlacement = computed(() => {
  let currentPlace = 0;
  const result: any[] = [];

  for (let i = 0; i < orderedList.value.length; i += 1) {
    const currentUser = orderedList.value[i];
    const lastUser = orderedList.value[i - 1];
    if (
      !lastUser ||
      (global ? currentUser.normalized_score : currentUser.score) <
        (global ? lastUser.normalized_score : lastUser.score)
    ) {
      currentPlace += 1;
    }
    result.push({ ...currentUser, place: currentPlace });
  }
  return result;
});
</script>

<style scoped>
.leaderboard {

  display: flex;
  flex-direction: column;
  gap: 2px;
  background: var(--indigo-dark);
  border-radius: 2px;
  overflow: hidden;
}

.lb-row {
  display: grid;
  grid-template-columns: 56px 48px 1fr auto;
  align-items: center;
  gap: 16px;
  padding: 14px 22px;
  background: var(--indigo-dark);
  transition: background 0.15s ease;
}

.lb-row:hover {
  background: color-mix(in srgb, var(--indigo-dark) 92%, var(--ink));
}

.lb-row__place {
  font-size: 22px;
  font-weight: 900;
  letter-spacing: -0.02em;
  color: var(--muted-strong);
  line-height: 1;
  font-variant-numeric: tabular-nums;
}

.lb-row__avatar {
  display: flex;
  align-items: center;
}

.lb-row__name {
  font-size: 15px;
  font-weight: 700;
  color: var(--cream);
  display: flex;
  align-items: center;
  gap: 10px;
  min-width: 0;
  overflow: hidden;
  text-overflow: ellipsis;
  white-space: nowrap;
}

.lb-row__link {
  color: inherit;
  text-decoration: none;
}

.lb-row__link:hover {
  text-decoration: underline;
  text-underline-offset: 3px;
}

.lb-row__you {
  font-size: 10px;
  font-weight: 800;
  letter-spacing: 1.4px;
  background: var(--orange);
  color: #fff;
  padding: 3px 7px;
  border-radius: 2px;
}

.lb-row__score {
  display: flex;
  align-items: baseline;
  gap: 4px;
  color: var(--cream);
  font-variant-numeric: tabular-nums;
}

.lb-row__score-value {
  font-size: 26px;
  font-weight: 900;
  letter-spacing: -0.02em;
  line-height: 1;
}

.lb-row__score-unit {
  font-size: 11px;
  font-weight: 800;
  letter-spacing: 1.2px;
  color: var(--muted-strong);
}

/* ===== Top 3 accents ===== */
.lb-row--first .lb-row__place {
  color: var(--orange);
}

.lb-row--first .lb-row__score-value {
  color: var(--green);
}

.lb-row--second .lb-row__place {
  color: var(--yellow);
}

.lb-row--third .lb-row__place {
  color: var(--muted-strong);
}

/* ===== Highlight current user ===== */
.lb-row--you {
  background: rgba(255, 90, 58, 0.12);
  box-shadow: inset 3px 0 0 var(--orange);
}

.lb-row--you:hover {
  background: rgba(255, 90, 58, 0.18);
}

@media (max-width: 600px) {
  .lb-row {
    grid-template-columns: 40px 40px 1fr auto;
    gap: 12px;
    padding: 12px 16px;
  }
  .lb-row__place {
    font-size: 18px;
  }
  .lb-row__score-value {
    font-size: 22px;
  }
}
</style>
