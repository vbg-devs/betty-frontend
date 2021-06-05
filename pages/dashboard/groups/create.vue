<template>
  <div>
    <h1 class="page-title">Create new group</h1>
    <form @submit.prevent="create">
      <div class="form-row">
        <input v-model="name" type="text" placeholder="Name of the group" class="form-input form-input--with-icon icon--tag">
      </div>
      <div class="form-row">
        <input v-model="message" type="text" placeholder="Welcome message" class="form-input form-input--with-icon icon--message">
      </div>
      <div class="form-row">
        <input v-model="winPoints" type="number" min="0" placeholder="Points for winning team" class="form-input form-input--with-icon icon--award">
      </div>
      <div class="form-row">
        <input v-model="exactScorePoints" type="number" min="0" placeholder="Points for exact score" class="form-input form-input--with-icon icon--target">
      </div>
      <div class="form-row">
        <button class="button button--action">Create group</button>
      </div>
    </form>
  </div>
</template>

<script>
export default {
  name: 'CreateGroup',
  data() {
    return {
      name: '',
      message: '',
      winPoints: '',
      exactScorePoints: '',
      peak: true,
    };
  },
};
</script>

<style>
</style>
