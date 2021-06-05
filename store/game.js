/* eslint-disable no-shadow, no-param-reassign */

export const state = () => ({
  games: [],
});

export const getters = {
  all: (state) => state.jobs,
};

export const mutations = {
  ADD_GAMES(state, payload) {
    state.jobs.push(...payload);
  },
};

export const actions = {
  load({ rootState, commit }, payload) {
    return new Promise((resolve, reject) => {
      this.$axios.get('https://betty-prod.herokuapp.com/api/v1/teams', {
        headers: {
          Authorization: `Bearer ${payload.token || rootState.user.user.token}`,
        },
      }).then((response) => {
        commit('ADD_GAMES', (response.data || []).map((x) => Object.freeze(x)));
        resolve(response.data);
      }).catch((err) => {
        console.error('error loadModelVersionJobs', err);
        reject(err);
      });
    });
  },
};
