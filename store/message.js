/* eslint-disable no-shadow, no-param-reassign */

export const state = () => ({
  messages: [],
});

export const getters = {
  all: (state) => state.messages,
};

export const mutations = {
  ADD_MESSAGE(state, payload) {
    if (state.messages.length === 5) {
      state.messages.splice(0, 1);
    }

    state.messages.push(payload);
  },
  DELETE_MESSAGE(state, payload) {
    const index = state.messages.findIndex((x) => x.id === payload.id);
    if (index > -1) {
      state.messages.splice(index, 1);
    }
  },
  CLEAR_MESSAGES(state) {
    state.messages = [];
  },
};

export const actions = {
  add({ commit }, payload) {
    return new Promise((resolve) => {
      commit('ADD_MESSAGE', payload);
      resolve(payload);
    });
  },
  delete({ commit }, payload) {
    return new Promise((resolve) => {
      commit('DELETE_MESSAGE', payload);
      resolve(payload);
    });
  },
  clearAll({ commit }) {
    return new Promise((resolve) => {
      commit('CLEAR_MESSAGES');
      resolve();
    });
  },
};
