// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach } from 'vitest';
import { flushPromises } from '@vue/test-utils';
import { mockNuxtImport, mountSuspended } from '@nuxt/test-utils/runtime';
import GlobalLeaderboard from './GlobalLeaderboard.vue';
import Leaderboard from './Leaderboard.vue';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

const entries = [
  { user_id: 1, name: 'Alice', normalized_score: 50 },
  { user_id: 2, name: 'Bob', normalized_score: 80 },
  { user_id: 3, name: 'Cara', normalized_score: 20 },
];

describe('GlobalLeaderboard', () => {
  beforeEach(() => {
    authFetch.mockReset();
  });

  it('shows the loader and no leaderboard while the fetch is pending', async () => {
    authFetch.mockReturnValue(new Promise(() => {}));
    const wrapper = await mountSuspended(GlobalLeaderboard, { props: { id: 1 } });
    expect(wrapper.find('.l-loader').exists()).toBe(true);
    expect(wrapper.find('.l-loader__image').exists()).toBe(true);
    expect(wrapper.findComponent(Leaderboard).exists()).toBe(false);
  });

  it('requests the leaderboard for the given tournament id', async () => {
    authFetch.mockResolvedValue([]);
    await mountSuspended(GlobalLeaderboard, { props: { id: 5 } });
    expect(authFetch).toHaveBeenCalledTimes(1);
    expect(authFetch).toHaveBeenCalledWith('/tournament/5/leaderboard?limit=100');
  });

  it('defaults the tournament id to -1 when no id prop is given', async () => {
    authFetch.mockResolvedValue([]);
    await mountSuspended(GlobalLeaderboard);
    expect(authFetch).toHaveBeenCalledWith('/tournament/-1/leaderboard?limit=100');
  });

  it('hides the loader and passes the fetched users to Leaderboard in global mode', async () => {
    authFetch.mockResolvedValue(entries);
    const wrapper = await mountSuspended(GlobalLeaderboard, { props: { id: 1 } });
    await flushPromises();
    expect(wrapper.find('.l-loader').exists()).toBe(false);
    const leaderboard = wrapper.findComponent(Leaderboard);
    expect(leaderboard.exists()).toBe(true);
    expect(leaderboard.props('users')).toEqual(entries);
    expect(leaderboard.props('global')).toBe(true);
  });

  it('renders rows ranked by normalized_score descending', async () => {
    authFetch.mockResolvedValue(entries);
    const wrapper = await mountSuspended(GlobalLeaderboard, { props: { id: 1 } });
    await flushPromises();
    const rows = wrapper.findAll('.lb-row');
    expect(rows).toHaveLength(3);
    expect(rows.map((row) => row.find('.lb-row__name').text())).toEqual(['Bob', 'Alice', 'Cara']);
    expect(rows.map((row) => row.find('.lb-row__place').text())).toEqual(['01', '02', '03']);
    expect(rows.map((row) => row.find('.lb-row__score-value').text())).toEqual(['80', '50', '20']);
  });

  it('renders names as plain text (no selectable link) in global mode', async () => {
    authFetch.mockResolvedValue(entries);
    const wrapper = await mountSuspended(GlobalLeaderboard, { props: { id: 1 } });
    await flushPromises();
    expect(wrapper.find('.lb-row__link').exists()).toBe(false);
  });

  it('emits count with the number of fetched users', async () => {
    authFetch.mockResolvedValue(entries);
    const wrapper = await mountSuspended(GlobalLeaderboard, { props: { id: 1 } });
    await flushPromises();
    expect(wrapper.emitted('count')).toEqual([[3]]);
  });

  it('emits count 0 and renders an empty leaderboard for an empty response', async () => {
    authFetch.mockResolvedValue([]);
    const wrapper = await mountSuspended(GlobalLeaderboard, { props: { id: 1 } });
    await flushPromises();
    expect(wrapper.emitted('count')).toEqual([[0]]);
    expect(wrapper.find('.l-loader').exists()).toBe(false);
    expect(wrapper.findAll('.lb-row')).toHaveLength(0);
  });

  it('emits count 0 and renders an empty leaderboard when the response is undefined', async () => {
    authFetch.mockResolvedValue(undefined);
    const wrapper = await mountSuspended(GlobalLeaderboard, { props: { id: 1 } });
    await flushPromises();
    expect(wrapper.emitted('count')).toEqual([[0]]);
    expect(wrapper.findAll('.lb-row')).toHaveLength(0);
  });

  // NOTE: pins current behavior — there is no error handling around the fetch,
  // so a failed request escapes to the app error handler, leaves the spinner
  // up forever and never emits count.
  it('stays in the loading state when the fetch rejects', async () => {
    const error = new Error('boom');
    const errorHandler = vi.fn();
    authFetch.mockRejectedValue(error);
    const wrapper = await mountSuspended(GlobalLeaderboard, {
      props: { id: 1 },
      global: { config: { errorHandler } },
    });
    await flushPromises();
    expect(errorHandler).toHaveBeenCalledWith(error, expect.anything(), expect.anything());
    expect(wrapper.find('.l-loader').exists()).toBe(true);
    expect(wrapper.findComponent(Leaderboard).exists()).toBe(false);
    expect(wrapper.emitted('count')).toBeUndefined();
  });
});
