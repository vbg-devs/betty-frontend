/* eslint-disable no-shadow, no-param-reassign */
import firebase from 'firebase/app';
import 'firebase/auth';


export const state = () => ({
  groups: [],
});

export const getters = {
  all: (state) => state.groups,
  byId: (state) => (id) => state.groups.find((x) => x.id === id),
};

export const mutations = {
  ADD_GROUPS(state, payload) {
    state.groups = payload;
  },
};

export const actions = {
  load({ commit }, payload) {
    return new Promise((resolve, reject) => {
      this.$axios.get('https://betty-prod.herokuapp.com/api/v1/groups', {
        headers: {
          Authorization: `Bearer ${payload.token}`,
        },
      }).then((response) => {
        commit('ADD_GROUPS', (response.data || []).map((x) => Object.freeze(x)));
        resolve(response.data);
      }).catch((err) => {
        console.error('error group/load', err);
        reject(err);
      });
    });
  },
  async create({ commit }, payload) {
    const user = firebase.auth().currentUser;
    const token = await user.getIdToken();

    return new Promise((resolve, reject) => {
      this.$axios.post('https://betty-prod.herokuapp.com/api/v1/group', payload, {
        headers: {
          Authorization: `Bearer ${token}`,
        },
      }).then((response) => {
        commit('ADD_GROUPS', [Object.freeze(response.data)]);
        resolve(response.data);
      }).catch((err) => {
        console.error('error group/create', err);
        reject(err);
      });
    });
  },
};
