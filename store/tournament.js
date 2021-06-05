/* eslint-disable no-shadow, no-param-reassign */

export const state = () => ({
  tournaments: [],
});

export const getters = {
  all: (state) => state.tournaments,
  byId: (state) => (id) => state.tournaments.find((x) => x.id === id),
};

export const mutations = {
  ADD_TOURNAMENTS(state, payload) {
    state.tournaments = payload;
  },
};

export const actions = {
  load({ commit }, payload) {
    return new Promise((resolve, reject) => {
      this.$axios.get('https://betty-prod.herokuapp.com/api/v1/tournaments', {
        headers:
        {
          Authorization: `Bearer ${payload.token}`,
        },
      }).then((response) => {
        commit('ADD_TOURNAMENTS', (response.data || []).map((x) => Object.freeze(x)));
        resolve(response.data);
      }).catch((err) => {
        console.error('error tournament/load', err);
        reject(err);
      });
    });
  },
};
