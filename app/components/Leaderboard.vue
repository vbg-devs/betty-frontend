<template>
  <div class="leaderboard">
    <div
      v-for="user in listWithPlacement"
      :key="user.user_id"
      class="leaderbord-row"
      :class="{ highlight: user.user_id === userId }"
    >
      <div class="row row--center-v">
        <div class="column column--wrap">{{ user.place }}</div>
        <div class="column column--wrap">
          <UserBadge :user="user" :clickable="false" :block="true" />
        </div>
        <div class="column column--wrap">
          <template v-if="global">
            {{ user.name }}
          </template>
          <template v-else>
            <a href="javascript:void(0);" class="link" @click="emit('user-selected', user)">{{
              user.name
            }}</a>
          </template>
        </div>
        <div class="column text-right">
          <span class="points">{{ global ? user.normalized_score : user.score }}p</span>
        </div>
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
.highlight {
  background-color: #434f8e;
  color: #fff;
}

.points {
  font-weight: 700;
}

.highlight .link,
.highlight .points {
  color: #fff;
}

.leaderbord-row {
  padding: 0 10px;
}

.leaderbord-row:not(.highlight):nth-child(even) {
  background: #fbfbfb;
}

.link {
  &:hover {
    text-decoration: underline;
  }
}
</style>
