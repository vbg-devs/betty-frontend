/* eslint-disable no-shadow, no-param-reassign */

export const state = () => ({
  groups: [
    {
      id: 1,
      name: 'Amazing friends',
      image_url: 'https://via.placeholder.com/250x250',
      welcome_message: 'Hello world! Welcome to the annual round of “Max is probably gonna win this”-cup.',
      owner: '1',
      tournament_id: 1,
      members: [{ id: 1, joined: new Date().toISOString() }],
      invite_code: 'XXXXXX',
    },
  ],
});

export const getters = {
  all: (state) => state.groups,
  byId: (state) => (id) => state.groups.find((x) => x.id === id),
};

export const mutations = {
  ADD_GROUPS(state, payload) {
    state.groups.push(...payload);
  },
};

export const actions = {
  // load({ rootState, commit }, payload) {
  //   return new Promise((resolve, reject) => {
  //     this.$axios.get('https://betty-prod.herokuapp.com/api/v1/teams', {
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
};
