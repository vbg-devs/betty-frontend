/* eslint-disable no-shadow, no-param-reassign */
import firebase from 'firebase/app';
import 'firebase/auth';


export const state = () => ({
  bets: [],
});

export const getters = {
  all: (state) => state.bets,
};

export const mutations = {
  ADD_BETS(state, payload) {
    state.bets.push(...payload);
  },
};

export const actions = {
  // loadByGroup({ commit }, payload) {
  //   return new Promise((resolve, reject) => {
  //     this.$axios.get(`https://api.betty.social/api/v1/bets/byGroup/${paylod.id}`, {
  //       headers: {
  //         Authorization: `Bearer ${payload.token}`,
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
  async place({ commit }, payload) {
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();
    return new Promise((resolve, reject) => {
      this.$axios.post('https://api.betty.social/api/v1/bet', payload, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((response) => {
        commit('ADD_BETS', [Object.freeze(response.data)]);
        resolve(response.data);
      }).catch((err) => {
        console.error('error bet/place', err);
        reject(err);
      });
    });
  },
  async update({ }, payload) { //eslint-disable-line
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();
    return new Promise((resolve, reject) => {
      this.$axios.put(`https://api.betty.social/api/v1/bet/${payload.id}`, payload, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((response) => {
        // commit('ADD_BETS', [Object.freeze(response.data)]);
        resolve(response.data);
      }).catch((err) => {
        console.error('error bet/place', err);
        reject(err);
      });
    });
  },
};
