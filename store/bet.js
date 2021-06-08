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
  //     this.$axios.get(`https://betty-prod.herokuapp.com/api/v1/bets/byGroup/${paylod.id}`, {
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
      this.$axios.post('https://betty-prod.herokuapp.com/api/v1/bet', payload, {
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
      // type Bet struct {
      //   ID            int64     `json:"id"`
      //   UserID        string    `db:"user_id" json:"user_id"`
      //   UserPoints    *int64    `db:"user_points" json:"user_points"`
      //   HomeTeamScore int64     `db:"home_team_score" json:"home_team_score"`
      //   AwayTeamScore int64     `db:"away_team_score" json:"away_team_score"`
      //   ProcessedAt   time.Time `db:"processed_at" json:"processed_at"`
      //   CreatedAt     time.Time `db:"created_at" json:"created_at"`
      //   UpdatedAt     time.Time `db:"updated_at" json:"updated_at"`
      // }
    });
  },
};
