<template>
  <div>
    🤙 <strong>{{ (data.who || 'Someone') }}</strong> just joined <strong>{{ data.group.name }}</strong>
  </div>
</template>

<script>
export default {
  name: 'GroupJoinedListItem',
  props: {
    data: {
      type: Object,
      default: () => { },
    },
  },
};
</script>

<style>
</style>
