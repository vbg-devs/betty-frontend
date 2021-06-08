/* eslint-disable no-shadow, no-param-reassign */
import firebase from 'firebase/app';
import 'firebase/auth';

export const state = () => ({
  tournaments: [],
  details: [],
});

export const getters = {
  all: (state) => state.tournaments,
  byId: (state) => (id) => state.tournaments.find((x) => x.id === id),
  details: (state) => (id) => state.details.find((x) => x.id === id),
};

export const mutations = {
  ADD_TOURNAMENTS(state, payload) {
    state.tournaments = payload;
  },
  ADD_DETAILS(state, payload) {
    state.details.push(payload);
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
  async loadDetails({ state, commit }, payload) {
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();

    console.log('loadDetails', token, payload.id);

    return new Promise((resolve, reject) => {
      const details = state.details.find((x) => x.id === payload.id);
      if (details) resolve(details);
      this.$axios.get(`https://betty-prod.herokuapp.com/api/v1/tournament/${payload.id}`, {
        headers:
        {
          Authorization: `Bearer ${token}`,
        },
      }).then((response) => {
        commit('ADD_DETAILS', Object.freeze(response.data));
        resolve(response.data);
      }).catch((err) => {
        console.error('error tournament/loadDetails', err);
        reject(err);
      });
    });
  },
};
