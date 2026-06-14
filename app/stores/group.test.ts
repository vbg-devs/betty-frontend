// @vitest-environment nuxt
import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import { mockNuxtImport } from '@nuxt/test-utils/runtime';
import { setActivePinia, createPinia } from 'pinia';
import type { Group, PublicGroupListResponse } from '~/types';

const { authFetch } = vi.hoisted(() => ({ authFetch: vi.fn() }));
mockNuxtImport('useApi', () => () => ({ authFetch }));

function makeGroup(id: number, overrides: Partial<Group> = {}): Group {
  return {
    id,
    name: `Group ${id}`,
    tournament_id: 1,
    invite_code: `code-${id}`,
    welcome_message: 'Welcome',
    description: null,
    header_image_url: null,
    allow_sneak_peek: false,
    correct_team_points: 1,
    exact_result_points: 3,
    boost_count: 0,
    boost_multiplier: 2,
    public_at: null,
    members: [],
    ...overrides,
  };
}

describe('useGroupStore', () => {
  beforeEach(() => {
    setActivePinia(createPinia());
    authFetch.mockReset();
  });

  afterEach(() => {
    vi.unstubAllGlobals();
  });

  describe('load', () => {
    it('fetches /groups and stores the result', async () => {
      const data = [makeGroup(1), makeGroup(2)];
      authFetch.mockResolvedValue(data);
      const store = useGroupStore();

      await store.load();

      expect(authFetch).toHaveBeenCalledWith('/groups');
      expect(store.groups).toHaveLength(2);
      expect(store.groups[0]!.id).toBe(1);
      expect(store.groups[1]!.id).toBe(2);
    });

    it('freezes each loaded group', async () => {
      authFetch.mockResolvedValue([makeGroup(1)]);
      const store = useGroupStore();

      await store.load();

      expect(Object.isFrozen(store.groups[0])).toBe(true);
    });

    it('stores an empty array when the API returns null', async () => {
      authFetch.mockResolvedValue([makeGroup(1)]);
      const store = useGroupStore();
      await store.load();

      authFetch.mockResolvedValue(null);
      await store.load();

      expect(store.groups).toEqual([]);
    });
  });

  describe('all and byId', () => {
    it('all mirrors groups', async () => {
      authFetch.mockResolvedValue([makeGroup(1), makeGroup(2)]);
      const store = useGroupStore();

      expect(store.all).toEqual([]);
      await store.load();
      expect(store.all.map((g) => g.id)).toEqual([1, 2]);
    });

    it('byId returns the matching group or undefined', async () => {
      authFetch.mockResolvedValue([makeGroup(1), makeGroup(7)]);
      const store = useGroupStore();
      await store.load();

      expect(store.byId(7)!.name).toBe('Group 7');
      expect(store.byId(999)).toBeUndefined();
    });
  });

  describe('create', () => {
    it('posts the payload to /group and returns the response without reloading', async () => {
      authFetch.mockResolvedValue({ group_id: 42 });
      const store = useGroupStore();

      const result = await store.create({ name: 'New group', tournament_id: 3 });

      expect(result).toEqual({ group_id: 42 });
      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(authFetch).toHaveBeenCalledWith('/group', {
        method: 'POST',
        body: { name: 'New group', tournament_id: 3 },
      });
    });
  });

  describe('join', () => {
    it('posts to /join/{code}, refreshes groups, and returns the joined group', async () => {
      const joined = makeGroup(5);
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups' ? [joined] : joined,
      );
      const store = useGroupStore();

      const result = await store.join('abc123');

      expect(result).toEqual(joined);
      expect(authFetch).toHaveBeenNthCalledWith(1, '/join/abc123', { method: 'POST', body: {} });
      expect(authFetch).toHaveBeenNthCalledWith(2, '/groups');
      expect(store.groups.map((g) => g.id)).toEqual([5]);
    });
  });

  describe('joinPublic', () => {
    it('posts to /group/{id}/join, refreshes groups, and returns the response', async () => {
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups' ? [makeGroup(9)] : { group_id: 9 },
      );
      const store = useGroupStore();

      const result = await store.joinPublic(9);

      expect(result).toEqual({ group_id: 9 });
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/9/join', { method: 'POST', body: {} });
      expect(authFetch).toHaveBeenNthCalledWith(2, '/groups');
      expect(store.groups.map((g) => g.id)).toEqual([9]);
    });
  });

  describe('leave', () => {
    it('deletes /group/{id}/leave and refreshes groups', async () => {
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups' ? [] : { ok: true },
      );
      const store = useGroupStore();
      store.groups = [Object.freeze(makeGroup(4)) as Group];

      const result = await store.leave(4);

      expect(result).toEqual({ ok: true });
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/4/leave', { method: 'DELETE' });
      expect(authFetch).toHaveBeenNthCalledWith(2, '/groups');
      expect(store.groups).toEqual([]);
    });
  });

  describe('setVisibility', () => {
    it('puts is_public=true and refreshes groups', async () => {
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups'
          ? [makeGroup(2, { public_at: '2026-06-01T00:00:00Z' })]
          : { public_at: '2026-06-01T00:00:00Z' },
      );
      const store = useGroupStore();

      const result = await store.setVisibility(2, true);

      expect(result).toEqual({ public_at: '2026-06-01T00:00:00Z' });
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/2/visibility', {
        method: 'PUT',
        body: { is_public: true },
      });
      expect(authFetch).toHaveBeenNthCalledWith(2, '/groups');
      expect(store.byId(2)!.public_at).toBe('2026-06-01T00:00:00Z');
    });

    it('puts is_public=false', async () => {
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups' ? [] : { public_at: null },
      );
      const store = useGroupStore();

      const result = await store.setVisibility(2, false);

      expect(result).toEqual({ public_at: null });
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/2/visibility', {
        method: 'PUT',
        body: { is_public: false },
      });
    });
  });

  describe('updateSettings', () => {
    it('puts the payload to /group/{id}/settings and refreshes groups', async () => {
      const updated = makeGroup(3, { welcome_message: 'Hi', exact_result_points: 5 });
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups' ? [updated] : updated,
      );
      const store = useGroupStore();
      const payload = {
        welcome_message: 'Hi',
        description: null,
        correct_team_points: 2,
        exact_result_points: 5,
        allow_sneak_peek: true,
      };

      const result = await store.updateSettings(3, payload);

      expect(result).toEqual(updated);
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/3/settings', {
        method: 'PUT',
        body: payload,
      });
      expect(authFetch).toHaveBeenNthCalledWith(2, '/groups');
      expect(store.byId(3)!.welcome_message).toBe('Hi');
    });
  });

  describe('setHeaderImage', () => {
    it('puts the image url and refreshes groups', async () => {
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups'
          ? [makeGroup(6, { header_image_url: 'https://cdn/img.png' })]
          : { header_image_url: 'https://cdn/img.png' },
      );
      const store = useGroupStore();

      const result = await store.setHeaderImage(6, 'https://cdn/img.png');

      expect(result).toEqual({ header_image_url: 'https://cdn/img.png' });
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/6/header-image', {
        method: 'PUT',
        body: { header_image_url: 'https://cdn/img.png' },
      });
      expect(authFetch).toHaveBeenNthCalledWith(2, '/groups');
      expect(store.byId(6)!.header_image_url).toBe('https://cdn/img.png');
    });

    it('accepts null to clear the image', async () => {
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups' ? [] : { header_image_url: null },
      );
      const store = useGroupStore();

      const result = await store.setHeaderImage(6, null);

      expect(result).toEqual({ header_image_url: null });
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/6/header-image', {
        method: 'PUT',
        body: { header_image_url: null },
      });
    });
  });

  describe('setNickname', () => {
    it('puts the nickname and refreshes groups', async () => {
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups' ? [makeGroup(8)] : { nickname: 'Patzo' },
      );
      const store = useGroupStore();

      const result = await store.setNickname(8, 'Patzo');

      expect(result).toEqual({ nickname: 'Patzo' });
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/8/nickname', {
        method: 'PUT',
        body: { nickname: 'Patzo' },
      });
      expect(authFetch).toHaveBeenNthCalledWith(2, '/groups');
    });

    it('accepts null to clear the nickname', async () => {
      authFetch.mockImplementation(async (path: string) =>
        path === '/groups' ? [] : { nickname: null },
      );
      const store = useGroupStore();

      const result = await store.setNickname(8, null);

      expect(result).toEqual({ nickname: null });
      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/8/nickname', {
        method: 'PUT',
        body: { nickname: null },
      });
    });
  });

  describe('uploadHeaderImage', () => {
    const presign = {
      upload_url: 'https://r2.example.com/upload?sig=x',
      public_url: 'https://cdn.example.com/header.png',
    };

    function makeFile() {
      return new File(['png-bytes'], 'header.png', { type: 'image/png' });
    }

    it('presigns, PUTs the file to the upload url, then sets the header image', async () => {
      const fetchMock = vi.fn().mockResolvedValue({ ok: true, status: 200 });
      vi.stubGlobal('fetch', fetchMock);
      authFetch.mockImplementation(async (path: string) => {
        if (path === '/group/11/header-image/upload-url') return presign;
        if (path === '/groups') return [makeGroup(11, { header_image_url: presign.public_url })];
        return { header_image_url: presign.public_url };
      });
      const store = useGroupStore();
      const file = makeFile();

      const result = await store.uploadHeaderImage(11, file);

      expect(authFetch).toHaveBeenNthCalledWith(1, '/group/11/header-image/upload-url', {
        method: 'POST',
        body: { content_type: 'image/png', content_length: file.size },
      });
      expect(fetchMock).toHaveBeenCalledWith(presign.upload_url, {
        method: 'PUT',
        headers: { 'Content-Type': 'image/png' },
        body: file,
      });
      expect(authFetch).toHaveBeenNthCalledWith(2, '/group/11/header-image', {
        method: 'PUT',
        body: { header_image_url: presign.public_url },
      });
      expect(authFetch).toHaveBeenNthCalledWith(3, '/groups');
      expect(result).toEqual({ header_image_url: presign.public_url });
      expect(store.byId(11)!.header_image_url).toBe(presign.public_url);
    });

    it('throws with the status code when the PUT is not ok and does not set the image', async () => {
      const fetchMock = vi.fn().mockResolvedValue({ ok: false, status: 403 });
      vi.stubGlobal('fetch', fetchMock);
      authFetch.mockResolvedValue(presign);
      const store = useGroupStore();

      await expect(store.uploadHeaderImage(11, makeFile())).rejects.toThrow(
        'R2 upload failed (403)',
      );
      expect(authFetch).toHaveBeenCalledTimes(1);
      expect(authFetch).not.toHaveBeenCalledWith('/group/11/header-image', expect.anything());
    });
  });

  describe('listPublic', () => {
    const response: PublicGroupListResponse = { items: [], next_cursor: '' };

    it('sends an empty query when called with no params', async () => {
      authFetch.mockResolvedValue(response);
      const store = useGroupStore();

      const result = await store.listPublic();

      expect(result).toEqual(response);
      expect(authFetch).toHaveBeenCalledWith('/groups/public', { query: {} });
      expect(authFetch).toHaveBeenCalledTimes(1);
    });

    it('includes all params when provided', async () => {
      authFetch.mockResolvedValue(response);
      const store = useGroupStore();

      await store.listPublic({ cursor: 'abc', q: 'world', tournamentId: 2, limit: 10 });

      expect(authFetch).toHaveBeenCalledWith('/groups/public', {
        query: { cursor: 'abc', q: 'world', tournament_id: 2, limit: 10 },
      });
    });

    it('omits empty-string cursor and q', async () => {
      authFetch.mockResolvedValue(response);
      const store = useGroupStore();

      await store.listPublic({ cursor: '', q: '' });

      expect(authFetch).toHaveBeenCalledWith('/groups/public', { query: {} });
    });

    it('keeps tournamentId=0 and limit=0', async () => {
      authFetch.mockResolvedValue(response);
      const store = useGroupStore();

      await store.listPublic({ tournamentId: 0, limit: 0 });

      expect(authFetch).toHaveBeenCalledWith('/groups/public', {
        query: { tournament_id: 0, limit: 0 },
      });
    });

    it('includes only the cursor when only cursor is set', async () => {
      authFetch.mockResolvedValue(response);
      const store = useGroupStore();

      await store.listPublic({ cursor: 'next-page' });

      expect(authFetch).toHaveBeenCalledWith('/groups/public', { query: { cursor: 'next-page' } });
    });

    it('includes only q when only q is set', async () => {
      authFetch.mockResolvedValue(response);
      const store = useGroupStore();

      await store.listPublic({ q: 'friends' });

      expect(authFetch).toHaveBeenCalledWith('/groups/public', { query: { q: 'friends' } });
    });
  });
});
