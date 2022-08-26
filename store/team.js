/* eslint-disable no-shadow, no-param-reassign */


export const state = () => ({
  teams: [],
});

export const getters = {
  all: (state) => state.teams,
  byId: (state) => (id) => state.teams.find((x) => x.id === id),
};

export const mutations = {
  ADD_TEAMS(state, payload) {
    state.teams = payload;
  },
};

export const actions = {
  load({ commit }, payload) {
    console.log('LOAD TEMAS');
    return new Promise((resolve, reject) => {
      this.$axios.get('https://api.betty.social/api/v1/teams', {
        headers:
        {
          Authorization: `Bearer ${payload.token}`,
        },
      }).then((response) => {
        commit('ADD_TEAMS', (response.data || []).map((x) => Object.freeze(x)));
        resolve(response.data);
      }).catch((err) => {
        console.error('error team/load', err);
        reject(err);
      });
    });
  },
};
