<template>
  <div>
    <div class="message" style="padding: 10px 12px">
      <div class="row row--center-v">
        <div class="column column--wrap">
          <svg
            xmlns="http://www.w3.org/2000/svg"
            width="24"
            height="24"
            viewBox="0 0 24 24"
            fill="none"
            stroke="currentColor"
            stroke-width="2"
            stroke-linecap="round"
            stroke-linejoin="round"
            class="feather feather-alert-circle"
          >
            <circle cx="12" cy="12" r="10"></circle>
            <line x1="12" y1="8" x2="12" y2="12"></line>
            <line x1="12" y1="16" x2="12.01" y2="16"></line>
          </svg>
        </div>
        <div class="column">
          <div>
            The global leaderboard har moved to its own page. You can find it in the menu or
            <u><NuxtLink to="/leaderboard">click here</NuxtLink></u>
          </div>
        </div>
      </div>
    </div>
    <h1 class="page-title">My Groups</h1>
    <div class="groups">
      <div v-for="group in groupsWithTournament" :key="group.id" class="group">
        <group-list-item :group="group"></group-list-item>
      </div>
    </div>
    <div v-if="groups.length === 0" class="empty">
      <img src="~/assets/images/group-empty.svg" class="empty__logo" />
      <div class="empty__text">
        <p>You don't have any groups yet.</p>
        <p>Invite a bunch of friends and get started!</p>
      </div>
    </div>
    <div class="empty__button">
      <button class="button button--action" @click="showModal = true">Start a group</button>
      <NuxtLink to="/dashboard/groups/browse" class="button button--secondary">
        Browse public groups
      </NuxtLink>
    </div>
    <transition name="page">
      <create-group-modal
        v-if="showModal"
        @close="handleCloseCreateGroupModal"
      ></create-group-modal>
    </transition>
  </div>
</template>

<script setup lang="ts">
const groupStore = useGroupStore();
const tournamentStore = useTournamentStore();

const showModal = ref(false);

const groups = computed(() => groupStore.all);

const groupsWithTournament = computed(() => {
  const mapped = groups.value.map((x) =>
    Object.freeze({
      ...x,
      tournament: tournamentStore.byId(x.tournament_id),
    }),
  );
  return mapped.filter((x) => x.tournament);
});

function handleCloseCreateGroupModal() {
  showModal.value = false;
  document.body.classList.remove('no-scroll');
}
</script>

<style scoped>
.empty {
  text-align: center;
}

.empty__logo {
  display: block;
  margin: 0 auto;
}

.empty__text {
  font-size: 22px;
  text-align: center;
  font-weight: 500;
  margin: 15px 0;
}

.empty__button {
  display: flex;
  justify-content: center;
  gap: 10px;
  margin-top: 30px;
  flex-wrap: wrap;
}

.groups {
  display: flex;
  margin: 0 -10px;
  flex-wrap: wrap;
  justify-content: center;
}

.group {
  padding: 10px;
  flex: 0 1 100%;

  @media (min-width: 768px) {
    flex: 0 1 33.333%;
  }
}
</style>
