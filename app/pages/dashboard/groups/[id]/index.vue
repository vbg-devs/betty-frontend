<template>
  <div v-if="group && tournament" class="group">
    <card :no-padding="true">
      <template #header>
        <img :src="tournament.image_url" class="img img--full" />
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
      <div class="tabs">
        <div class="tab" :class="{ 'tab--selected': selectedTab === 1 }" @click="selectedTab = 1">
          <div class="tab__image">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              width="24"
              height="24"
              color="currentColor"
              fill="none"
            >
              <path
                d="M20.774 18C21.5233 18 22.1193 17.5285 22.6545 16.8691C23.7499 15.5194 21.9513 14.4408 21.2654 13.9126C20.568 13.3756 19.7894 13.0714 19 13M18 11C19.3807 11 20.5 9.88071 20.5 8.5C20.5 7.11929 19.3807 6 18 6"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
              />
              <path
                d="M3.22596 18C2.47666 18 1.88067 17.5285 1.34555 16.8691C0.250089 15.5194 2.04867 14.4408 2.73465 13.9126C3.43197 13.3756 4.21058 13.0714 5 13M5.5 11C4.11929 11 3 9.88071 3 8.5C3 7.11929 4.11929 6 5.5 6"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
              />
              <path
                d="M8.0838 15.1112C7.06203 15.743 4.38299 17.0331 6.0147 18.6474C6.81178 19.436 7.69952 20 8.81563 20H15.1844C16.3005 20 17.1882 19.436 17.9853 18.6474C19.617 17.0331 16.938 15.743 15.9162 15.1112C13.5201 13.6296 10.4799 13.6296 8.0838 15.1112Z"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M15.5 7.5C15.5 9.433 13.933 11 12 11C10.067 11 8.5 9.433 8.5 7.5C8.5 5.567 10.067 4 12 4C13.933 4 15.5 5.567 15.5 7.5Z"
                stroke="currentColor"
                stroke-width="1.5"
              />
            </svg>
          </div>
          <div class="tab__label">Group</div>
        </div>
        <div class="tab" :class="{ 'tab--selected': selectedTab === 2 }" @click="selectedTab = 2">
          <div class="tab__image">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              width="24"
              height="24"
              color="currentColor"
              fill="none"
            >
              <path
                d="M18 2V4M6 2V4"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M10 17L9.99999 13.3472C9.99999 13.1555 9.86325 13 9.69458 13H9M13.6297 17L14.9842 13.3492C15.0475 13.1785 14.9128 13 14.7207 13H13"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
              />
              <path
                d="M2.5 12.2432C2.5 7.88594 2.5 5.70728 3.75212 4.35364C5.00424 3 7.01949 3 11.05 3H12.95C16.9805 3 18.9958 3 20.2479 4.35364C21.5 5.70728 21.5 7.88594 21.5 12.2432V12.7568C21.5 17.1141 21.5 19.2927 20.2479 20.6464C18.9958 22 16.9805 22 12.95 22H11.05C7.01949 22 5.00424 22 3.75212 20.6464C2.5 19.2927 2.5 17.1141 2.5 12.7568V12.2432Z"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M6 8H18"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </div>
          <div class="tab__label">Games</div>
        </div>
        <div class="tab" :class="{ 'tab--selected': selectedTab === 3 }" @click="selectedTab = 3">
          <div class="tab__image">
            <svg
              xmlns="http://www.w3.org/2000/svg"
              viewBox="0 0 24 24"
              width="24"
              height="24"
              color="currentColor"
              fill="none"
            >
              <path
                d="M8 21C8 19.5858 8 18.8787 8.43934 18.4393C8.87868 18 9.58579 18 11 18H13C14.4142 18 15.1213 18 15.5607 18.4393C16 18.8787 16 19.5858 16 21V22H8V21Z"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M12 13L12 18"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M6 22H18"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
              <path
                d="M13.0366 2.86651L14.0925 4.99573C14.2364 5.29212 14.6204 5.57642 14.9444 5.63086L16.8582 5.95145C18.082 6.15712 18.37 7.05236 17.4881 7.9355L16.0003 9.43563C15.7483 9.68968 15.6103 10.1796 15.6883 10.5305L16.1142 12.3875C16.4502 13.8574 15.6763 14.426 14.3864 13.6578L12.5926 12.5871C12.2687 12.3935 11.7347 12.3935 11.4048 12.5871L9.61096 13.6578C8.3271 14.426 7.54719 13.8513 7.88315 12.3875L8.3091 10.5305C8.3871 10.1796 8.24911 9.68968 7.99714 9.43563L6.5093 7.9355C5.6334 7.05236 5.91537 6.15712 7.13923 5.95145L9.05302 5.63086C9.37099 5.57642 9.75494 5.29212 9.89893 4.99573L10.9548 2.86651C11.5307 1.71116 12.4666 1.71116 13.0366 2.86651Z"
                stroke="currentColor"
                stroke-width="1.5"
                stroke-linecap="round"
                stroke-linejoin="round"
              />
            </svg>
          </div>
          <div class="tab__label">Leaderboard</div>
        </div>
      </div>
      <section class="group__body">
        <transition-group name="page">
          <div v-if="selectedTab === 1" key="group" class="group-section">
            <div class="row row--wrap">
              <section class="group__information column">
                <div class="welcome-message">
                  {{ group.welcome_message }}
                </div>
                <div>
                  <template v-if="tournamentDetails">
                    <need-action
                      :pools="pools"
                      :show-bets="true"
                      :bets="bets"
                      @click-game="clickGame"
                    ></need-action>
                  </template>
                </div>

                <meme-board :members="group.members"></meme-board>
              </section>
              <aside class="sidebar column column--wrap">
                <div class="group__box group__box--fit">
                  <h3 class="group__box__title">Your Rank</h3>
                  <div class="group__box__body">
                    <div class="big text-center">
                      {{ yourPlacement
                      }}<span class="big big--smaller dimmed"> of {{ group.members.length }}</span>
                    </div>
                  </div>
                </div>

                <div class="group__box group__box--fit">
                  <h3 class="group__box__title">Top 3</h3>
                  <TopThree :users="group.members" @user-selected="userSelected"></TopThree>
                </div>
                <div class="group__box group__box--fit">
                  <h3 class="group__box__title">Games played</h3>
                  <span class="big">{{ completeGamesPercentage }}</span
                  ><span class="big big--smaller">%</span>
                  <progress-bar :progress="completeGamesPercentage"></progress-bar>
                  <div class="games">
                    {{ completeGames.length }} of {{ allGames.length }} games played
                  </div>
                </div>
                <div class="group__box group__box--fit">
                  <h3 class="group__box__title">Invite link</h3>
                  <div class="big big--smaller text-center">
                    <div class="share-link">
                      <input v-model="shareUrl" type="text" class="share-link__input" readonly />
                      <div class="share-link__action" @click="copyInviteCode">
                        <svg
                          v-if="!copied"
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          width="24"
                          height="24"
                          color="currentColor"
                          fill="none"
                        >
                          <path
                            d="M7.5 3.5C5.9442 3.54667 5.01661 3.71984 4.37477 4.36227C3.49609 5.24177 3.49609 6.6573 3.49609 9.48836L3.49609 15.9944C3.49609 18.8255 3.49609 20.241 4.37477 21.1205C5.25345 22 6.66767 22 9.49609 22L14.4961 22C17.3245 22 18.7387 22 19.6174 21.1205C20.4961 20.241 20.4961 18.8255 20.4961 15.9944V9.48836C20.4961 6.6573 20.4961 5.24177 19.6174 4.36228C18.9756 3.71984 18.048 3.54667 16.4922 3.5"
                            stroke="currentColor"
                            stroke-width="1.5"
                          />
                          <path
                            d="M7.49609 3.75C7.49609 2.7835 8.2796 2 9.24609 2H14.7461C15.7126 2 16.4961 2.7835 16.4961 3.75C16.4961 4.7165 15.7126 5.5 14.7461 5.5H9.24609C8.2796 5.5 7.49609 4.7165 7.49609 3.75Z"
                            stroke="currentColor"
                            stroke-width="1.5"
                            stroke-linejoin="round"
                          />
                        </svg>
                        <svg
                          v-else
                          xmlns="http://www.w3.org/2000/svg"
                          viewBox="0 0 24 24"
                          width="24"
                          height="24"
                          color="currentColor"
                          fill="none"
                        >
                          <path
                            d="M7.5 3.5C5.9442 3.54667 5.01661 3.71984 4.37477 4.36227C3.49609 5.24177 3.49609 6.6573 3.49609 9.48836L3.49609 15.9944C3.49609 18.8255 3.49609 20.241 4.37477 21.1205C5.25345 22 6.66767 22 9.49609 22L14.4961 22C17.3245 22 18.7387 22 19.6174 21.1205C20.4961 20.241 20.4961 18.8255 20.4961 15.9944V9.48836C20.4961 6.6573 20.4961 5.24177 19.6174 4.36228C18.9756 3.71984 18.048 3.54667 16.4922 3.5"
                            stroke="currentColor"
                            stroke-width="1.5"
                          />
                          <path
                            d="M7.49609 3.75C7.49609 2.7835 8.2796 2 9.24609 2H14.7461C15.7126 2 16.4961 2.7835 16.4961 3.75C16.4961 4.7165 15.7126 5.5 14.7461 5.5H9.24609C8.2796 5.5 7.49609 4.7165 7.49609 3.75Z"
                            stroke="currentColor"
                            stroke-width="1.5"
                            stroke-linejoin="round"
                          />
                          <path
                            d="M13.5 11H17"
                            stroke="currentColor"
                            stroke-width="1.5"
                            stroke-linecap="round"
                          />
                          <path
                            d="M7 12C7 12 7.5 12 8 13C8 13 9.58824 10.5 11 10"
                            stroke="currentColor"
                            stroke-width="1.5"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                          <path
                            d="M13.5 17H17"
                            stroke="currentColor"
                            stroke-width="1.5"
                            stroke-linecap="round"
                          />
                          <path
                            d="M8 17H9"
                            stroke="currentColor"
                            stroke-width="2"
                            stroke-linecap="round"
                            stroke-linejoin="round"
                          />
                        </svg>
                      </div>
                    </div>
                  </div>
                </div>
                <div class="members-box">
                  <h2>Members</h2>
                  <div class="members">
                    <user-badge
                      v-for="member in group.members"
                      :key="member.user_id"
                      :user="member"
                      class="member-icon"
                      @click="userSelected(member)"
                    ></user-badge>
                  </div>
                </div>
                <div class="group-settings">
                  <h2>Group settings</h2>
                  <div class="row row--center-v">
                    <div class="column">Allow sneak peek?</div>
                    <div class="column column--wrap">
                      <svg
                        v-if="group.allow_sneak_peek"
                        xmlns="http://www.w3.org/2000/svg"
                        width="24"
                        height="24"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="3"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        class="feather feather-check icon-peek"
                      >
                        <polyline points="20 6 9 17 4 12"></polyline>
                      </svg>
                      <svg
                        v-else
                        xmlns="http://www.w3.org/2000/svg"
                        width="24"
                        height="24"
                        viewBox="0 0 24 24"
                        fill="none"
                        stroke="currentColor"
                        stroke-width="3"
                        stroke-linecap="round"
                        stroke-linejoin="round"
                        class="feather feather-x icon-peek"
                      >
                        <line x1="18" y1="6" x2="6" y2="18"></line>
                        <line x1="6" y1="6" x2="18" y2="18"></line>
                      </svg>
                    </div>
                  </div>
                  <div class="row row--center-v">
                    <div class="column">Points for winning team</div>
                    <div class="column column--wrap text-center" style="width: 44px">
                      <strong>{{ group.correct_team_points }}</strong>
                    </div>
                  </div>
                  <div class="row row--center-v">
                    <div class="column">Points for exact score</div>
                    <div class="column column--wrap text-center" style="width: 44px">
                      <strong>{{ group.exact_result_points }}</strong>
                    </div>
                  </div>
                </div>
                <div class="button-wrapper">
                  <button class="button button--danger" @click="leaveGroup">Leave group</button>
                </div>
              </aside>
            </div>
          </div>
          <div v-if="selectedTab === 2" key="games" class="games-section">
            <template v-if="tournamentDetails">
              <Pools :pools="pools" :show-bets="true" :bets="bets" @click-game="clickGame"></Pools>
            </template>
          </div>
          <div v-if="selectedTab === 3" key="leaderboard">
            <leaderboard :users="group.members" @user-selected="userSelected"></leaderboard>
          </div>
        </transition-group>
      </section>
    </card>
    <bet-modal
      :game-bet="gameBet"
      :show="gameBet !== null"
      :peek="group.allow_sneak_peek"
      :bets="betsForGame"
      @bet-placed="betPlaced"
      @close="gameBet = null"
    ></bet-modal>
    <transition name="page">
      <user-history
        v-if="selectedUser"
        :user="selectedUser"
        :peek="group.allow_sneak_peek"
        :games="tournamentDetails.games"
        :bets="bets"
        @close="selectedUser = null"
      ></user-history>
    </transition>
  </div>
</template>

<script setup lang="ts">
import Pools from '~/components/Pools.vue';

const route = useRoute();
const router = useRouter();
const userStore = useUserStore();
const groupStore = useGroupStore();
const tournamentStore = useTournamentStore();
const { authFetch } = useApi();
const { alert: notify, confirm: confirmDialog } = useNotify();

const bets = ref<any[]>([]);
const gameBet = ref<any>(null);
const copied = ref(false);
const selectedTab = ref(1);
const selectedUser = ref<any>(null);
let interval: ReturnType<typeof setInterval> | null = null;

const groupId = computed(() => parseFloat(route.params.id as string));
const userId = computed(() => userStore.id);
const group = computed(() => groupStore.byId(groupId.value));
const tournament = computed(() => {
  if (!group.value) return null;
  return tournamentStore.byId(group.value.tournament_id);
});
const tournamentDetails = computed(() => {
  if (!tournament.value) return null;
  return tournamentStore.detailsById(tournament.value.id);
});
const allGames = computed(() => {
  if (!tournamentDetails.value) return [];
  return (tournamentDetails.value as any).games || [];
});
const completeGames = computed(() => allGames.value.filter((x: any) => x.status === 1));
const completeGamesPercentage = computed(() => {
  if (completeGames.value.length === 0) return 0;
  return Math.round((completeGames.value.length / allGames.value.length) * 100);
});

const yourPlacement = computed(() => {
  if (!group.value) return -1;
  const members = JSON.parse(JSON.stringify(group.value.members)).concat();
  members.sort((a: any, b: any) => b.score - a.score);

  let currentPlace = 0;
  let myPlace = -1;

  for (let i = 0; i < members.length; i += 1) {
    const currentUser = members[i];
    const lastUser = members[i - 1];
    if (!lastUser || currentUser.score < lastUser.score) {
      currentPlace += 1;
    }
    if (currentUser.user_id === userId.value) {
      myPlace = currentPlace;
    }
  }
  return myPlace;
});

const shareUrl = computed(() => {
  if (!group.value) return '';
  return `https://betty.social/dashboard/groups/join/${(group.value as any).invite_code}`;
});

const betsForGame = computed(() => {
  if (gameBet.value === null || !group.value) return [];
  return bets.value
    .filter((x: any) => x.game_id === gameBet.value.id)
    .map((x: any) => ({
      ...x,
      user: group.value!.members.find((u: any) => u.user_id === x.user_id),
    }));
});

const pools = computed(() => {
  if (!tournamentDetails.value) return [];
  const td = tournamentDetails.value as any;
  const result: any[] = [];
  td.pools.forEach((pool: any) => {
    result.push({
      ...pool,
      games: (td.games || []).filter((x: any) => x.pool_id === pool.id),
    });
  });
  return result;
});

watch(
  () => tournament.value,
  (newVal) => {
    if (!newVal) return;
    tournamentStore.loadDetails({ id: newVal.id });
  },
  { immediate: true },
);

watch(
  () => selectedTab.value,
  (newVal) => {
    if (newVal !== 2) return;
    nextTick().then(() => {
      setTimeout(() => {
        const elem = document.querySelector('.day-group.is-next-upcoming');
        if (!elem) return;
        const yOffset = -70;
        const y = elem.getBoundingClientRect().top + window.scrollY + yOffset;
        window.scrollTo({ top: y, behavior: 'smooth' });
      }, 500);
    });
  },
);

async function loadBets() {
  try {
    const data = await authFetch<any[]>(`/bets/bygroup/${route.params.id}`);
    bets.value = data;
  } catch (err) {
    notify({
      title: 'Could not load bets',
      message: `Please refresh page to make sure all bets are loaded. \n\n Error: ${err}`,
      state: 'warning',
    });
  }
}

function handleEvent() {
  if (!tournament.value) return;
  tournamentStore.loadDetails({ id: tournament.value.id, force: true });
}

function userSelected(user: any) {
  selectedUser.value = user;
}

function leaveGroup() {
  if (!group.value) return;
  confirmDialog({
    question: `Are you sure you want to leave ${group.value.name}?`,
    onConfirm: async () => {
      await groupStore.leave(group.value!.id);
      await router.replace('/dashboard');
    },
  });
}

function betPlaced() {
  gameBet.value = null;
  loadBets();
}

async function copyInviteCode() {
  await navigator.clipboard.writeText(shareUrl.value);
  copied.value = true;
  setTimeout(() => {
    copied.value = false;
  }, 1000);
}

function clickGame(payload: any) {
  if (!group.value) return;
  gameBet.value = { ...payload, groupId: group.value.id };
}

onMounted(() => {
  loadBets();
  interval = setInterval(loadBets, 1000 * 10);
  window.addEventListener('game-evaluated', handleEvent);
});

onBeforeUnmount(() => {
  window.removeEventListener('game-evaluated', handleEvent);
  if (interval) {
    clearInterval(interval);
    interval = null;
  }
});
</script>

<style scoped>
.group__image {
  display: block;
  border-radius: 50%;
  border: 5px solid rgba(0, 0, 0, 0.08);
  box-shadow: 0 5px 10px -7px rgba(0, 0, 0, 0.3);
  height: 140px;
  width: 140px;
  background-position: center;
  background-repeat: no-repeat;
}

.welcome-message {
  font-size: 22px;
  color: #999;
  margin-bottom: 20px;
  font-weight: 600;
}

.sidebar {
  @media (min-width: 768px) {
    width: 300px;
    margin-left: 25px;
  }
}

.big {
  font-size: 50px;
  font-weight: 800;
}

.big--smaller {
  font-size: 25px;
}

.group__box {
  margin-top: 10px;
  background: #fbfbfb;
  padding: 10px;
  height: 100%;
  border-radius: 4px;

  &:first-child {
    margin-top: 0;
  }
}

.group__box__title {
  text-transform: uppercase;
  font-size: 13px;
  color: rgba(0, 0, 0, 0.3);
  font-weight: 400;
}

.games {
  margin-top: 7px;
  color: #c0cbd4;
  font-size: 12px;
  font-weight: bold;
}

.invite-code-button {
  border: none;
  background: transparent;
  display: flex;
  justify-content: center;
  align-items: center;
  width: 30px;
  height: 30px;
  padding: 0;
  border-radius: 50%;
  cursor: pointer;

  svg {
    display: block;
  }
}

.invite-code-input {
  padding: 7px;
}

.share-link {
  border: 1px solid #efefef;
  display: flex;
  margin-top: 8px;
}

.share-link__input {
  border: none;
  outline: none;
  flex: 1;
  padding: 7px;
  color: #969292;
}

.share-link__action {
  border-left: 1px solid #efefef;
  display: flex;
  justify-content: center;
  align-items: center;
  width: 32px;
  cursor: pointer;
  transition: all ease 0.3s;
  color: #969292;

  &:hover {
    color: #434f8e;
  }
}

.share-link__action__icon {
  display: block;
  width: 18px;
}

.members {
  list-style-type: none;
  margin: 0;
  padding: 0;
  padding-top: 10px;
  padding-left: 10px;
}

.member {
  display: flex;
  align-items: center;
  margin-bottom: 8px;
}

.member__icon {
  padding-right: 5px;
}

.member__label {
  flex: 1;
}

.member-icon {
  position: relative;
  margin-left: -10px;
  border-width: 2px !important;
  height: 43.75px !important;
  width: 43.75px !important;

  &:hover {
    z-index: 5;
    transform: scale(1.2);
  }
}

.tabs {
  display: flex;
}

.tab {
  flex: 1;
  padding: 20px 10px;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  border-bottom: 1px solid #f2f2f2;
  transition: border-color ease 0.3s;
  cursor: pointer;
  opacity: 0.6;

  @media (max-width: 767px) {
    justify-content: center;
  }
}

.tab--selected {
  border-color: #434f8e;
  background: #fff;
  opacity: 1;
}

.tab__image svg {
  display: flex;
  margin-right: 5px;
  height: 24px;
  width: auto;
}

.tab__label {
  font-weight: 600;
  font-size: 14px;
  -webkit-font-smoothing: auto;
  line-height: 1;

  @media (max-width: 767px) {
    display: none;
  }
}

.group-section,
.games-section {
  padding: 10px;
}

.group-settings {
  margin-top: 25px;
}

.group__box--flex {
  display: flex;
  flex-direction: column;
}

.group__box__body {
  flex: 1;
  display: flex;
  justify-content: center;
  align-items: center;
  gap: 8px;
}

.group__box--fit {
  height: auto;
}

.icon-peek {
  width: auto;
  vertical-align: middle;

  &.feather-x {
    color: #f44336;
  }

  &.feather-check {
    color: #78cc14;
  }
}

.leaderboard-menu {
  text-align: right;
  padding: 10px;
  font-size: 12px;
}

.underline {
  text-decoration: underline;
}

.button-wrapper {
  display: flex;
  justify-content: center;
  margin-top: 30px;
}

.members-box {
  margin: 20px 0;
}

h2 {
  border-bottom: 1px solid #fafafa;
  padding-bottom: 10px;
  margin-bottom: 10px;
}

.dimmed {
  color: #c0cbd4;
}

.card__header {
  aspect-ratio: 16/9;
}
</style>
