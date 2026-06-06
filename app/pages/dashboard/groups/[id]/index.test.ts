// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { defineComponent, nextTick } from 'vue';
import { flushPromises, type DOMWrapper } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import type { Bet, Game, Group, GroupMember, Tournament, UserProfile } from '~/types';
import GroupPage from './index.vue';

const { authFetch, notifyAlert, notifyConfirm } = vi.hoisted(() => ({
  authFetch: vi.fn(),
  notifyAlert: vi.fn(),
  notifyConfirm: vi.fn(),
}));
mockNuxtImport('useApi', () => () => ({ authFetch }));
mockNuxtImport('useNotify', () => () => ({ alert: notifyAlert, confirm: notifyConfirm }));

const FUTURE = '2099-07-19T00:00:00Z';
const PAST = '2000-07-19T00:00:00Z';

const NeedActionStub = defineComponent({
  name: 'NeedAction',
  props: ['pools', 'showBets', 'bets'],
  emits: ['click-game'],
  template: '<div class="need-action-stub" />',
});
const PoolsStub = defineComponent({
  name: 'Pools',
  props: ['pools', 'showBets', 'bets'],
  emits: ['click-game'],
  template: '<div class="pools-stub" />',
});
const LeaderboardStub = defineComponent({
  name: 'Leaderboard',
  props: ['users'],
  emits: ['user-selected'],
  template: '<div class="leaderboard-stub" />',
});
const TopThreeStub = defineComponent({
  name: 'TopThree',
  props: ['users'],
  emits: ['user-selected'],
  template: '<div class="top-three-stub" />',
});
const MemeBoardStub = defineComponent({
  name: 'MemeBoard',
  props: ['members'],
  template: '<div class="meme-board-stub" />',
});
const BetModalStub = defineComponent({
  name: 'BetModal',
  props: ['gameBet', 'show', 'peek', 'bets'],
  emits: ['bet-placed', 'close'],
  template: '<div class="bet-modal-stub" />',
});
const GroupSettingsModalStub = defineComponent({
  name: 'GroupSettingsModal',
  props: ['group'],
  emits: ['close'],
  template: '<div class="group-settings-modal-stub" />',
});
const UserHistoryStub = defineComponent({
  name: 'UserHistory',
  props: ['user', 'peek', 'games', 'bets'],
  emits: ['close'],
  template: '<div class="user-history-stub" />',
});

function makeMember(overrides: Partial<GroupMember> = {}): GroupMember {
  return {
    user_id: 'uid-100',
    name: 'Alice Smith',
    nickname: null,
    image_url: null,
    score: 0,
    access_level: 1,
    ...overrides,
  };
}

function defaultMembers(): GroupMember[] {
  return [
    makeMember({ user_id: 'uid-100', name: 'Alice Smith', score: 10, access_level: 0 }),
    makeMember({ user_id: 'uid-101', name: 'Bob Jones', score: 5 }),
    makeMember({ user_id: 'uid-102', name: 'Cara Lane', score: 2 }),
  ];
}

function makeGroup(overrides: Partial<Group> = {}): Group {
  return {
    id: 1,
    name: 'My Group',
    tournament_id: 10,
    invite_code: 'INV123',
    welcome_message: '',
    description: null,
    header_image_url: null,
    allow_sneak_peek: false,
    correct_team_points: 1,
    exact_result_points: 3,
    public_at: null,
    members: defaultMembers(),
    ...overrides,
  };
}

function makeTournament(overrides: Partial<Tournament> = {}): Tournament {
  return {
    id: 10,
    name: 'Euro 2026',
    image_url: '',
    start_date: '2026-06-11T00:00:00Z',
    end_date: FUTURE,
    ...overrides,
  };
}

function makeGame(id: number, overrides: Partial<Game> = {}): Game {
  return {
    id,
    home_team_id: 1,
    away_team_id: 2,
    home_team_score: null,
    away_team_score: null,
    start_date: '2026-06-12T00:00:00Z',
    status: 0,
    pool_id: 50,
    ...overrides,
  };
}

function makeDetails(overrides: Partial<Tournament> = {}): Tournament {
  return makeTournament({
    pools: [
      { id: 50, name: 'Group A' },
      { id: 51, name: 'Group B' },
    ],
    games: [
      makeGame(1, { status: 1 }),
      makeGame(2, { status: 1 }),
      makeGame(3),
      makeGame(4, { pool_id: 51 }),
    ],
    ...overrides,
  });
}

function makeUser(overrides: Partial<UserProfile> = {}): UserProfile {
  return {
    id: 'uid-100',
    email: 'alice@example.com',
    name: 'Alice Smith',
    image_url: null,
    firebase_image_url: null,
    country: null,
    is_admin: false,
    created_at: '2026-01-01T00:00:00Z',
    updated_at: '2026-01-01T00:00:00Z',
    ...overrides,
  };
}

function makeBet(overrides: Partial<Bet> = {}): Bet {
  return {
    id: 1,
    user_id: 'uid-101',
    game_id: 1,
    group_id: 1,
    home_team_score: 2,
    away_team_score: 1,
    user_points: 0,
    processed_at: null,
    ...overrides,
  };
}

type PageWrapper = Awaited<ReturnType<typeof mountSuspended>>;
let wrapper: PageWrapper | undefined;

async function mountPage() {
  wrapper = await mountSuspended(GroupPage, {
    route: '/dashboard/groups/1',
    global: {
      stubs: {
        NeedAction: NeedActionStub,
        Pools: PoolsStub,
        Leaderboard: LeaderboardStub,
        TopThree: TopThreeStub,
        MemeBoard: MemeBoardStub,
        BetModal: BetModalStub,
        GroupSettingsModal: GroupSettingsModalStub,
        UserHistory: UserHistoryStub,
      },
    },
  });
  await flushPromises();
  return wrapper;
}

const writeText = vi.fn();

describe('pages/dashboard/groups/[id]', () => {
  beforeEach(() => {
    authFetch.mockReset();
    authFetch.mockResolvedValue([]);
    notifyAlert.mockReset();
    notifyConfirm.mockReset();
    writeText.mockReset();
    writeText.mockResolvedValue(undefined);
    Object.defineProperty(navigator, 'clipboard', {
      value: { writeText },
      configurable: true,
    });
    useUserStore().user = makeUser();
    useGroupStore().groups = [makeGroup()];
    useTournamentStore().tournaments = [makeTournament()];
    useTournamentStore().details = [makeDetails()];
  });

  afterEach(() => {
    wrapper?.unmount();
    wrapper = undefined;
    vi.restoreAllMocks();
    vi.useRealTimers();
  });

  it('renders nothing when the group is not in the store', async () => {
    useGroupStore().groups = [];
    const w = await mountPage();
    expect(w.find('.group-page').exists()).toBe(false);
  });

  describe('hero', () => {
    it('shows the group name uppercased, member count, games progress, and tournament name', async () => {
      const w = await mountPage();
      expect(w.find('.hero__title').text()).toBe('MY GROUP');
      expect(w.find('.kicker--accent').text()).toContain('YOUR GROUP · EURO 2026');
      const meta = w.find('.hero__meta').text();
      expect(meta).toContain('3 MEMBERS');
      expect(meta).toContain('2 OF 4 GAMES');
      expect(w.find('.kicker--green').text()).toBe('● ACTIVE');
    });

    it('omits the games progress when the tournament details have no games', async () => {
      useTournamentStore().details = [makeDetails({ games: [] })];
      const w = await mountPage();
      expect(w.find('.hero__meta').text()).not.toContain('GAMES');
    });

    it('shows active stats: rank padded to two digits and games-played percentage', async () => {
      const w = await mountPage();
      const rank = w.find('.stat--orange');
      expect(rank.find('.stat__kicker').text()).toBe('YOUR RANK');
      expect(rank.find('.stat__value').text()).toBe('01');
      expect(rank.find('.stat__sub').text()).toBe('OF 03');
      const played = w.find('.stat--ghost');
      expect(played.find('.stat__kicker').text()).toBe('GAMES PLAYED');
      expect(played.find('.stat__value').text()).toBe('50%');
    });

    it('shows 0% games played when no game is complete', async () => {
      useTournamentStore().details = [makeDetails({ games: [makeGame(1), makeGame(2)] })];
      const w = await mountPage();
      expect(w.find('.stat--ghost .stat__value').text()).toBe('0%');
    });

    // NOTE: pins current behavior — String('–').padStart(2, '0') renders '0–' for
    // non-members instead of a plain dash. Looks like a cosmetic source bug.
    it('renders "0–" as the rank when the current user is not a member', async () => {
      useUserStore().user = makeUser({ id: 'uid-999' });
      const w = await mountPage();
      expect(w.find('.stat--orange .stat__value').text()).toBe('0–');
    });

    it('treats a missing tournament as ended and drops the tournament name', async () => {
      useTournamentStore().tournaments = [];
      useTournamentStore().details = [];
      const w = await mountPage();
      expect(w.find('.kicker--accent').text()).toBe('★ YOUR GROUP');
      expect(w.find('.hero__meta').text()).toContain('○ FINAL');
      expect(w.findAll('.tab').map((t: DOMWrapper<Element>) => t.text())).toEqual([
        'Group',
        'Leaderboard',
      ]);
    });

    it('treats an empty end_date as a running tournament', async () => {
      useTournamentStore().tournaments = [makeTournament({ end_date: '' })];
      const w = await mountPage();
      expect(w.find('.hero__meta').text()).toContain('● ACTIVE');
    });

    it('shows champion stats with "YOU WON" when the current user tops an ended tournament', async () => {
      useTournamentStore().tournaments = [makeTournament({ end_date: PAST })];
      const w = await mountPage();
      const champ = w.find('.stat--champion');
      expect(champ.find('.stat__kicker').text()).toBe('YOU WON');
      expect(champ.find('.stat__champion-name').text()).toBe('Alice Smith');
      expect(champ.find('.stat__sub').text()).toBe('10 PTS');
      const finish = w.find('.stat--ghost');
      expect(finish.find('.stat__kicker').text()).toBe('YOUR FINISH');
      expect(finish.find('.stat__value').text()).toBe('01');
    });

    it('shows "CHAMPION" and the losing placement for a non-winner on an ended tournament', async () => {
      useTournamentStore().tournaments = [makeTournament({ end_date: PAST })];
      useUserStore().user = makeUser({ id: 'uid-102', name: 'Cara Lane' });
      const w = await mountPage();
      expect(w.find('.stat--champion .stat__kicker').text()).toBe('CHAMPION');
      expect(w.find('.stat--ghost .stat__value').text()).toBe('03');
      expect(w.find('.podium-card__title').text()).toBe('CHAMPION CROWNED.');
    });
  });

  describe('header image upload', () => {
    it('shows the upload button to the author and forwards clicks to the hidden file input', async () => {
      const w = await mountPage();
      const btn = w.find('.hero__upload-btn');
      expect(btn.text()).toBe('ADD COVER →');
      const input = w.find('input[type="file"]');
      const clickSpy = vi.spyOn(input.element as HTMLInputElement, 'click');
      await btn.trigger('click');
      expect(clickSpy).toHaveBeenCalledTimes(1);
    });

    it('hides the upload button from non-author members', async () => {
      useUserStore().user = makeUser({ id: 'uid-101' });
      const w = await mountPage();
      expect(w.find('.hero__upload-btn').exists()).toBe(false);
      expect(w.find('input[type="file"]').exists()).toBe(false);
    });

    it('labels the button CHANGE COVER and applies the image class when a header image exists', async () => {
      useGroupStore().groups = [makeGroup({ header_image_url: 'https://img.example/x.png' })];
      const w = await mountPage();
      expect(w.find('.hero__card').classes()).toContain('hero__card--has-image');
      expect(w.find('.hero__upload-btn').text()).toBe('CHANGE COVER →');
    });

    async function selectFile(w: PageWrapper, file: File) {
      const input = w.find('input[type="file"]');
      Object.defineProperty(input.element, 'files', { value: [file], configurable: true });
      await input.trigger('change');
      await flushPromises();
    }

    it('rejects files with a disallowed mime type without uploading', async () => {
      const upload = vi.spyOn(useGroupStore(), 'uploadHeaderImage');
      const w = await mountPage();
      await selectFile(w, new File(['x'], 'a.txt', { type: 'text/plain' }));
      expect(upload).not.toHaveBeenCalled();
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Invalid file', state: 'warning' }),
      );
    });

    it('rejects files over 1MB without uploading', async () => {
      const upload = vi.spyOn(useGroupStore(), 'uploadHeaderImage');
      const w = await mountPage();
      await selectFile(
        w,
        new File([new Uint8Array(1024 * 1024 + 1)], 'big.png', { type: 'image/png' }),
      );
      expect(upload).not.toHaveBeenCalled();
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Image too large', state: 'warning' }),
      );
    });

    it('uploads a valid image and shows the loading label while in flight', async () => {
      let resolveUpload!: (v: unknown) => void;
      const upload = vi
        .spyOn(useGroupStore(), 'uploadHeaderImage')
        .mockReturnValue(new Promise((r) => (resolveUpload = r)) as never);
      const w = await mountPage();
      const file = new File(['img'], 'a.png', { type: 'image/png' });
      const input = w.find('input[type="file"]');
      Object.defineProperty(input.element, 'files', { value: [file], configurable: true });
      await input.trigger('change');
      await nextTick();

      expect(upload).toHaveBeenCalledWith(1, file);
      const btn = w.find('.hero__upload-btn');
      expect(btn.text()).toBe('UPLOADING…');
      expect(btn.attributes('disabled')).toBeDefined();

      resolveUpload({});
      await flushPromises();
      expect(w.find('.hero__upload-btn').text()).toBe('ADD COVER →');
      expect(notifyAlert).not.toHaveBeenCalled();
    });

    it.each([
      [401, 'Not allowed', 'warning'],
      [413, 'Image too large', 'warning'],
      [415, 'Unsupported image', 'warning'],
      [503, 'Image uploads unavailable', 'error'],
    ])('maps an upload failure with status %i to "%s"', async (status, title, state) => {
      vi.spyOn(useGroupStore(), 'uploadHeaderImage').mockRejectedValue({ status });
      const w = await mountPage();
      await selectFile(w, new File(['img'], 'a.png', { type: 'image/png' }));
      expect(notifyAlert).toHaveBeenCalledWith(expect.objectContaining({ title, state }));
    });

    it('falls back to a generic error for unknown upload failures', async () => {
      vi.spyOn(useGroupStore(), 'uploadHeaderImage').mockRejectedValue(new Error('boom'));
      const w = await mountPage();
      await selectFile(w, new File(['img'], 'a.png', { type: 'image/png' }));
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Could not upload image', state: 'error' }),
      );
    });
  });

  describe('tabs', () => {
    it('shows the group tab by default and switches to games and leaderboard', async () => {
      const w = await mountPage();
      expect(w.find('.group-tab').exists()).toBe(true);
      expect(w.findAll('.tab').map((t: DOMWrapper<Element>) => t.text())).toEqual([
        'Group',
        'Games',
        'Leaderboard',
      ]);

      await w.findAll('.tab')[1]!.trigger('click');
      await flushPromises();
      const pools = w.findComponent(PoolsStub);
      expect(pools.exists()).toBe(true);
      const poolsProp = pools.props('pools') as { id: number; games: Game[] }[];
      expect(poolsProp.map((p) => p.id)).toEqual([50, 51]);
      expect(poolsProp[0]!.games.map((g) => g.id)).toEqual([1, 2, 3]);
      expect(poolsProp[1]!.games.map((g) => g.id)).toEqual([4]);

      await w.findAll('.tab')[2]!.trigger('click');
      await flushPromises();
      const leaderboard = w.findComponent(LeaderboardStub);
      expect(leaderboard.exists()).toBe(true);
      expect((leaderboard.props('users') as GroupMember[]).map((m) => m.user_id)).toEqual([
        'uid-100',
        'uid-101',
        'uid-102',
      ]);
    });

    it('opens the user history when the leaderboard emits user-selected', async () => {
      const w = await mountPage();
      await w.findAll('.tab')[2]!.trigger('click');
      await flushPromises();
      w.findComponent(LeaderboardStub).vm.$emit(
        'user-selected',
        makeMember({ user_id: 'uid-101' }),
      );
      await nextTick();
      const history = w.findComponent(UserHistoryStub);
      expect(history.exists()).toBe(true);
      expect((history.props('user') as GroupMember).user_id).toBe('uid-101');

      history.vm.$emit('close');
      await nextTick();
      expect(w.findComponent(UserHistoryStub).exists()).toBe(false);
    });
  });

  describe('welcome / description', () => {
    it('renders the welcome message with the description underneath', async () => {
      useGroupStore().groups = [
        makeGroup({ welcome_message: 'Hello crew', description: 'Best group' }),
      ];
      const w = await mountPage();
      const welcome = w.find('.welcome');
      expect(welcome.classes()).not.toContain('welcome--quiet');
      expect(welcome.find('.welcome__text').text()).toBe('Hello crew');
      expect(welcome.find('.welcome__description').text()).toBe('Best group');
    });

    it('renders a quiet about card when only a description exists', async () => {
      useGroupStore().groups = [makeGroup({ description: 'Just about' })];
      const w = await mountPage();
      const welcome = w.find('.welcome');
      expect(welcome.classes()).toContain('welcome--quiet');
      expect(welcome.find('.welcome__description').text()).toBe('Just about');
    });

    it('renders no welcome card when both are empty', async () => {
      const w = await mountPage();
      expect(w.find('.welcome').exists()).toBe(false);
    });
  });

  describe('podium (ended tournament)', () => {
    it('groups tied members into shared podium slots and switches to the leaderboard', async () => {
      useTournamentStore().tournaments = [makeTournament({ end_date: PAST })];
      useGroupStore().groups = [
        makeGroup({
          members: [
            makeMember({ user_id: 'uid-100', name: 'Alice Smith', score: 10, access_level: 0 }),
            makeMember({ user_id: 'uid-101', name: 'Bob Jones', score: 10 }),
            makeMember({ user_id: 'uid-102', name: 'Cara Lane', score: 5 }),
            makeMember({ user_id: 'uid-103', name: 'Dan Poe', score: 1 }),
          ],
        }),
      ];
      const w = await mountPage();
      expect(w.find('.podium-card__title').text()).toBe('YOU TOOK IT.');

      const slots = w.findAll('.podium__slot');
      expect(slots).toHaveLength(3);
      expect(slots[0]!.find('.podium__place').text()).toBe('#1');
      expect(slots[0]!.findAll('.podium__person')).toHaveLength(2);
      expect(slots[0]!.text()).toContain('Alice Smith');
      expect(slots[0]!.text()).toContain('Bob Jones');
      expect(slots[1]!.text()).toContain('Cara Lane');
      expect(slots[2]!.text()).toContain('Dan Poe');

      await w.find('.podium-card__more').trigger('click');
      await flushPromises();
      expect(w.findComponent(LeaderboardStub).exists()).toBe(true);
    });

    it('hides the games tab, invite, nickname, and visibility cards when ended', async () => {
      useTournamentStore().tournaments = [makeTournament({ end_date: PAST })];
      const w = await mountPage();
      expect(w.findAll('.tab').map((t: DOMWrapper<Element>) => t.text())).toEqual([
        'Group',
        'Leaderboard',
      ]);
      expect(w.find('.invite').exists()).toBe(false);
      expect(w.find('.nickname').exists()).toBe(false);
      expect(w.find('.visibility__btn').exists()).toBe(false);
      expect(w.findComponent(NeedActionStub).exists()).toBe(false);
    });
  });

  describe('roster', () => {
    it('ranks members by score, sharing places on ties', async () => {
      useGroupStore().groups = [
        makeGroup({
          members: [
            makeMember({ user_id: 'uid-102', name: 'Cara Lane', score: 5 }),
            makeMember({ user_id: 'uid-100', name: 'Alice Smith', score: 10, access_level: 0 }),
            makeMember({ user_id: 'uid-101', name: 'Bob Jones', score: 10 }),
          ],
        }),
      ];
      const w = await mountPage();
      const rows = w.findAll('.roster__row');
      expect(rows.map((r: DOMWrapper<Element>) => r.find('.roster__rank').text())).toEqual([
        '#1',
        '#1',
        '#2',
      ]);
      expect(rows.map((r: DOMWrapper<Element>) => r.find('.roster__name').text())).toEqual([
        'Alice Smith',
        'Bob Jones',
        'Cara Lane',
      ]);
      expect(rows[0]!.find('.roster__pts').text()).toBe('10p');
    });

    it('prefers nicknames over real names in the roster', async () => {
      useGroupStore().groups = [
        makeGroup({
          members: [makeMember({ user_id: 'uid-100', name: 'Alice Smith', nickname: 'The GOAT' })],
        }),
      ];
      const w = await mountPage();
      expect(w.find('.roster__name').text()).toBe('The GOAT');
      expect(w.find('.roster__title').text()).toContain('1 FRIEND.');
    });

    it('caps the roster at six rows and offers a see-all shortcut to the leaderboard', async () => {
      const members = Array.from({ length: 8 }, (_, i) =>
        makeMember({ user_id: `uid-${200 + i}`, name: `Member ${i}`, score: 8 - i }),
      );
      useGroupStore().groups = [makeGroup({ members })];
      const w = await mountPage();
      expect(w.find('.roster__title').text()).toContain('8 FRIENDS.');
      expect(w.findAll('.roster__row')).toHaveLength(6);

      const more = w.find('.roster__more');
      expect(more.text()).toBe('See all 8 →');
      await more.trigger('click');
      await flushPromises();
      expect(w.findComponent(LeaderboardStub).exists()).toBe(true);
    });

    it('opens the user history when a roster row is clicked', async () => {
      const w = await mountPage();
      await w.find('.roster__row').trigger('click');
      const history = w.findComponent(UserHistoryStub);
      expect(history.exists()).toBe(true);
      expect((history.props('user') as GroupMember).user_id).toBe('uid-100');
      expect((history.props('games') as Game[]).map((g) => g.id)).toEqual([1, 2, 3, 4]);
    });
  });

  describe('invite link', () => {
    it('copies the share url and flips the button label back after 1.5s', async () => {
      const w = await mountPage();
      const input = w.find('.invite__input').element as HTMLInputElement;
      expect(input.value).toBe('https://betty.social/dashboard/groups/join/INV123');

      vi.useFakeTimers();
      await w.find('.invite__btn').trigger('click');
      await vi.advanceTimersByTimeAsync(0);
      await nextTick();
      expect(writeText).toHaveBeenCalledWith('https://betty.social/dashboard/groups/join/INV123');
      expect(w.find('.invite__btn').text()).toBe('COPIED ✓');

      await vi.advanceTimersByTimeAsync(1500);
      await nextTick();
      expect(w.find('.invite__btn').text()).toBe('COPY →');
    });
  });

  describe('nickname', () => {
    it('disables the save button until the input differs from the current nickname', async () => {
      const w = await mountPage();
      const btn = w.find('.nickname__btn');
      expect(w.find('.nickname__head .kicker--muted-light').text()).toBe('○ OFF');
      expect(btn.attributes('disabled')).toBeDefined();

      await w.find('.nickname__input').setValue('Cool Cat');
      expect(btn.attributes('disabled')).toBeUndefined();
      expect(btn.text()).toBe('SAVE →');
    });

    it('saves a trimmed nickname and notifies success', async () => {
      const setNickname = vi
        .spyOn(useGroupStore(), 'setNickname')
        .mockResolvedValue({ nickname: 'Cool Cat' });
      const w = await mountPage();
      await w.find('.nickname__input').setValue('  Cool Cat  ');
      await w.find('form.nickname').trigger('submit');
      await flushPromises();

      expect(setNickname).toHaveBeenCalledWith(1, 'Cool Cat');
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Nickname saved', state: 'success' }),
      );
    });

    it('prefills the existing nickname and clears it with a null payload', async () => {
      useGroupStore().groups = [
        makeGroup({ members: [makeMember({ user_id: 'uid-100', nickname: 'Old' })] }),
      ];
      const setNickname = vi
        .spyOn(useGroupStore(), 'setNickname')
        .mockResolvedValue({ nickname: null });
      const w = await mountPage();
      expect(w.find('.nickname__head .kicker--green').text()).toBe('● ACTIVE');
      expect((w.find('.nickname__input').element as HTMLInputElement).value).toBe('Old');

      await w.find('.nickname__input').setValue('');
      expect(w.find('.nickname__btn').text()).toBe('CLEAR →');
      await w.find('form.nickname').trigger('submit');
      await flushPromises();

      expect(setNickname).toHaveBeenCalledWith(1, null);
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Nickname cleared', state: 'success' }),
      );
    });

    it('notifies an error when saving the nickname fails', async () => {
      vi.spyOn(useGroupStore(), 'setNickname').mockRejectedValue(new Error('nope'));
      const w = await mountPage();
      await w.find('.nickname__input').setValue('X');
      await w.find('form.nickname').trigger('submit');
      await flushPromises();
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Could not save nickname', state: 'error' }),
      );
    });

    it('hides the nickname card when the current user is not a member', async () => {
      useUserStore().user = makeUser({ id: 'uid-999' });
      const w = await mountPage();
      expect(w.find('.nickname').exists()).toBe(false);
    });
  });

  describe('visibility', () => {
    it('shows the private state and goes public on click', async () => {
      const setVisibility = vi
        .spyOn(useGroupStore(), 'setVisibility')
        .mockResolvedValue({ public_at: FUTURE });
      const w = await mountPage();
      expect(w.find('.visibility__head .kicker--muted-light').text()).toBe('○ PRIVATE');
      expect(w.find('.visibility__hint').text()).toContain('invite link');

      const btn = w.find('.visibility__btn');
      expect(btn.text()).toBe('GO PUBLIC →');
      await btn.trigger('click');
      await flushPromises();
      expect(setVisibility).toHaveBeenCalledWith(1, true);
    });

    it('shows the public state and goes private on click', async () => {
      useGroupStore().groups = [makeGroup({ public_at: '2026-01-01T00:00:00Z' })];
      const setVisibility = vi
        .spyOn(useGroupStore(), 'setVisibility')
        .mockResolvedValue({ public_at: null });
      const w = await mountPage();
      expect(w.find('.visibility__head .kicker--green').text()).toBe('● PUBLIC');

      const btn = w.find('.visibility__btn');
      expect(btn.text()).toBe('MAKE PRIVATE');
      await btn.trigger('click');
      await flushPromises();
      expect(setVisibility).toHaveBeenCalledWith(1, false);
    });

    it('notifies "Not allowed" on a 401 from the response object', async () => {
      vi.spyOn(useGroupStore(), 'setVisibility').mockRejectedValue({
        response: { status: 401 },
      });
      const w = await mountPage();
      await w.find('.visibility__btn').trigger('click');
      await flushPromises();
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Not allowed', state: 'warning' }),
      );
    });

    it('notifies a generic error for other visibility failures', async () => {
      vi.spyOn(useGroupStore(), 'setVisibility').mockRejectedValue(new Error('boom'));
      const w = await mountPage();
      await w.find('.visibility__btn').trigger('click');
      await flushPromises();
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Could not update visibility', state: 'error' }),
      );
    });
  });

  describe('house rules', () => {
    it('shows the points and sneak peek values', async () => {
      const w = await mountPage();
      const rows = w.findAll('.rules__row');
      expect(rows[0]!.find('.rules__value').text()).toBe('1 pts');
      expect(rows[1]!.find('.rules__value').text()).toBe('3 pts');
      const peek = rows[2]!.find('.rules__value');
      expect(peek.text()).toBe('Closed');
      expect(peek.classes()).toContain('t-orange');
    });

    it('marks sneak peek as allowed in green when enabled', async () => {
      useGroupStore().groups = [makeGroup({ allow_sneak_peek: true })];
      const w = await mountPage();
      const peek = w.findAll('.rules__row')[2]!.find('.rules__value');
      expect(peek.text()).toBe('Allowed');
      expect(peek.classes()).toContain('t-green');
    });

    it('lets the author open and close the settings modal', async () => {
      const w = await mountPage();
      expect(w.findComponent(GroupSettingsModalStub).exists()).toBe(false);
      await w.find('.rules__edit').trigger('click');
      const modal = w.findComponent(GroupSettingsModalStub);
      expect(modal.exists()).toBe(true);
      expect((modal.props('group') as Group).id).toBe(1);

      modal.vm.$emit('close');
      await nextTick();
      expect(w.findComponent(GroupSettingsModalStub).exists()).toBe(false);
    });

    it('hides the edit button from non-authors', async () => {
      useUserStore().user = makeUser({ id: 'uid-101' });
      const w = await mountPage();
      expect(w.find('.rules__edit').exists()).toBe(false);
    });
  });

  describe('leave group', () => {
    it('asks for confirmation and leaves plus redirects on confirm', async () => {
      const leave = vi.spyOn(useGroupStore(), 'leave').mockResolvedValue(undefined);
      const router = useRouter();
      const replace = vi.spyOn(router, 'replace').mockResolvedValue(undefined);
      const w = await mountPage();

      await w.find('.leave-btn').trigger('click');
      expect(notifyConfirm).toHaveBeenCalledTimes(1);
      const { question, onConfirm } = notifyConfirm.mock.calls[0]![0];
      expect(question).toBe('Are you sure you want to leave My Group?');

      expect(leave).not.toHaveBeenCalled();
      await onConfirm();
      expect(leave).toHaveBeenCalledWith(1);
      expect(replace).toHaveBeenCalledWith('/dashboard');
    });
  });

  describe('bets', () => {
    it('loads the group bets on mount', async () => {
      await mountPage();
      expect(authFetch).toHaveBeenCalledWith('/bets/bygroup/1');
    });

    it('notifies a warning when loading bets fails', async () => {
      authFetch.mockRejectedValue(new Error('down'));
      await mountPage();
      expect(notifyAlert).toHaveBeenCalledWith(
        expect.objectContaining({ title: 'Could not load bets', state: 'warning' }),
      );
    });

    it('opens the bet modal with the group id and the bets for that game joined to members', async () => {
      const bets = [
        makeBet({ id: 1, user_id: 'uid-101', game_id: 1 }),
        makeBet({ id: 2, user_id: 'uid-102', game_id: 3 }),
      ];
      authFetch.mockImplementation((url: string) =>
        url === '/bets/bygroup/1' ? Promise.resolve(bets) : Promise.resolve([]),
      );
      const w = await mountPage();

      const modal = w.findComponent(BetModalStub);
      expect(modal.props('show')).toBe(false);
      expect(modal.props('peek')).toBe(false);

      w.findComponent(NeedActionStub).vm.$emit('click-game', { id: 1 });
      await nextTick();
      expect(modal.props('show')).toBe(true);
      expect(modal.props('gameBet')).toEqual({ id: 1, groupId: 1 });
      const modalBets = modal.props('bets') as Bet[];
      expect(modalBets).toHaveLength(1);
      expect(modalBets[0]!.id).toBe(1);
      expect(modalBets[0]!.user?.name).toBe('Bob Jones');

      modal.vm.$emit('close');
      await nextTick();
      expect(modal.props('show')).toBe(false);
    });

    it('closes the modal and reloads bets after a bet is placed', async () => {
      // Fake the interval clock so the 10s poll cannot add fetches mid-test;
      // setTimeout stays real for mountSuspended/flushPromises.
      vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
      const w = await mountPage();
      w.findComponent(NeedActionStub).vm.$emit('click-game', { id: 1 });
      await nextTick();
      authFetch.mockClear();

      const modal = w.findComponent(BetModalStub);
      modal.vm.$emit('bet-placed');
      await flushPromises();

      expect(modal.props('show')).toBe(false);
      expect(authFetch.mock.calls.filter((c) => c[0] === '/bets/bygroup/1')).toHaveLength(1);
    });

    it('polls the group bets every 10 seconds and applies the refreshed data', async () => {
      vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
      const w = await mountPage();
      w.findComponent(NeedActionStub).vm.$emit('click-game', { id: 1 });
      await nextTick();
      const modal = w.findComponent(BetModalStub);
      expect(modal.props('bets')).toEqual([]);

      authFetch.mockClear();
      authFetch.mockResolvedValue([makeBet({ id: 7, user_id: 'uid-101', game_id: 1 })]);
      await vi.advanceTimersByTimeAsync(9_999);
      expect(authFetch).not.toHaveBeenCalled();

      await vi.advanceTimersByTimeAsync(1);
      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(authFetch).toHaveBeenCalledWith('/bets/bygroup/1');
      await nextTick();
      expect((modal.props('bets') as Bet[]).map((b) => b.id)).toEqual([7]);
      expect((modal.props('bets') as Bet[])[0]!.user?.name).toBe('Bob Jones');

      await vi.advanceTimersByTimeAsync(10_000);
      expect(authFetch).toHaveBeenCalledTimes(2);
    });

    it('stops polling once the page is unmounted', async () => {
      vi.useFakeTimers({ toFake: ['setInterval', 'clearInterval'] });
      const w = await mountPage();
      w.unmount();
      wrapper = undefined;

      authFetch.mockClear();
      await vi.advanceTimersByTimeAsync(30_000);
      expect(authFetch).not.toHaveBeenCalled();
    });

    it('passes the pools and bets to NeedAction while the tournament runs', async () => {
      const w = await mountPage();
      const needAction = w.findComponent(NeedActionStub);
      expect(needAction.props('showBets')).toBe(true);
      const pools = needAction.props('pools') as { id: number }[];
      expect(pools.map((p) => p.id)).toEqual([50, 51]);
    });
  });

  describe('game-evaluated event', () => {
    it('force-reloads the tournament details when the event fires, and stops after unmount', async () => {
      const loadDetails = vi
        .spyOn(useTournamentStore(), 'loadDetails')
        .mockResolvedValue(makeDetails());
      const w = await mountPage();
      loadDetails.mockClear();

      window.dispatchEvent(new Event('game-evaluated'));
      expect(loadDetails).toHaveBeenCalledWith({ id: 10, force: true });

      w.unmount();
      wrapper = undefined;
      loadDetails.mockClear();
      window.dispatchEvent(new Event('game-evaluated'));
      expect(loadDetails).not.toHaveBeenCalled();
    });
  });
});
