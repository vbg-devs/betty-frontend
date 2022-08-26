/* eslint-disable no-shadow, no-param-reassign */
import firebase from 'firebase/app';
import 'firebase/auth';

export const state = () => ({
  games: [],
});

export const getters = {
  all: (state) => state.games,
  byId: (state) => (id) => state.games.find((x) => x.id === id),
};

export const mutations = {
  ADD_GAMES(state, payload) {
    state.games.push(...payload);
  },
};

export const actions = {
  // load({ rootState, commit }, payload) {
  //   return new Promise((resolve, reject) => {
  //     this.$axios.get('https://api.betty.social/api/v1/teams', {
  //       headers: {
  //         Authorization: `Bearer ${payload.token || rootState.user.user.token}`,
  //       },
  //     }).then((response) => {
  //       commit('ADD_GAMES', (response.data || []).map((x) => Object.freeze(x)));
  //       resolve(response.data);
  //     }).catch((err) => {
  //       console.error('error loadModelVersionJobs', err);
  //       reject(err);
  //     });
  //   });
  // },
  async load({ commit }, payload) {
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();

    return new Promise((resolve, reject) => {
      this.$axios.get(`https://api.betty.social/api/v1/game/${payload.id}`, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((response) => {
        commit('ADD_GAMES', [Object.freeze(response.data)]);
        resolve(response.data);
      }).catch((err) => {
        console.error('error group/create', err);
        reject(err);
      });
    });
  },
};
