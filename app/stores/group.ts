import type { Group, PublicGroupListResponse } from '~/types';

export interface ListPublicParams {
  cursor?: string;
  q?: string;
  tournamentId?: number;
  limit?: number;
}

export const useGroupStore = defineStore('group', () => {
  const groups = ref<Group[]>([]);

  const all = computed(() => groups.value);
  const byId = computed(() => (id: number) => groups.value.find((x) => x.id === id));

  async function load() {
    const { authFetch } = useApi();
    const data = await authFetch<Group[]>('/groups');
    groups.value = (data || []).map((x) => Object.freeze(x)) as Group[];
  }

  async function create(payload: Record<string, unknown>) {
    const { authFetch } = useApi();
    return authFetch<{ group_id: number }>('/group', { method: 'POST', body: payload });
  }

  async function join(code: string) {
    const { authFetch } = useApi();
    const data = await authFetch<Group>(`/join/${code}`, { method: 'POST', body: {} });
    await load();
    return data;
  }

  async function joinPublic(id: number) {
    const { authFetch } = useApi();
    const data = await authFetch<{ group_id: number }>(`/group/${id}/join`, {
      method: 'POST',
      body: {},
    });
    await load();
    return data;
  }

  async function leave(id: number) {
    const { authFetch } = useApi();
    const data = await authFetch(`/group/${id}/leave`, { method: 'DELETE' });
    await load();
    return data;
  }

  async function setVisibility(id: number, isPublic: boolean) {
    const { authFetch } = useApi();
    const data = await authFetch<{ public_at: string | null }>(`/group/${id}/visibility`, {
      method: 'PUT',
      body: { is_public: isPublic },
    });
    await load();
    return data;
  }

  async function setHeaderImage(id: number, imageUrl: string | null) {
    const { authFetch } = useApi();
    const data = await authFetch<{ header_image_url: string | null }>(
      `/group/${id}/header-image`,
      { method: 'PUT', body: { header_image_url: imageUrl } },
    );
    await load();
    return data;
  }

  async function uploadHeaderImage(id: number, file: File) {
    const { authFetch } = useApi();
    const presign = await authFetch<{ upload_url: string; public_url: string }>(
      `/group/${id}/header-image/upload-url`,
      {
        method: 'POST',
        body: { content_type: file.type, content_length: file.size },
      },
    );

    const res = await fetch(presign.upload_url, {
      method: 'PUT',
      headers: { 'Content-Type': file.type },
      body: file,
    });
    if (!res.ok) {
      throw new Error(`R2 upload failed (${res.status})`);
    }

    return setHeaderImage(id, presign.public_url);
  }

  async function listPublic(params: ListPublicParams = {}) {
    const { authFetch } = useApi();
    const query: Record<string, string | number> = {};
    if (params.cursor) query.cursor = params.cursor;
    if (params.q) query.q = params.q;
    if (params.tournamentId !== undefined) query.tournament_id = params.tournamentId;
    if (params.limit !== undefined) query.limit = params.limit;
    return authFetch<PublicGroupListResponse>('/groups/public', { query });
  }

  return {
    groups,
    all,
    byId,
    load,
    create,
    join,
    joinPublic,
    leave,
    setVisibility,
    setHeaderImage,
    uploadHeaderImage,
    listPublic,
  };
});
