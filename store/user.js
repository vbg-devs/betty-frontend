/* eslint-disable no-shadow, no-param-reassign */

export const state = () => ({
  user: null,
});

export const getters = {
  id: (state) => state.user?.id,
  email: (state) => state.user?.email,
  is_admin: (state) => state.user?.is_admin,
  profile: (state) => state.user,
};

export const mutations = {
  SET_USER(state, payload) {
    state.user = payload;
  },
};

export const actions = {
  set({ commit }, payload) {
    return new Promise((resolve) => {
      commit('SET_USER', payload);
      resolve();
    });
  },
};
