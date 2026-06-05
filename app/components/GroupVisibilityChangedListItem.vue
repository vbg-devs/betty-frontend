<template>
  <div>
    <strong>{{ groupName }}</strong> is now
    <strong>{{ data.public_at ? 'public' : 'private' }}</strong>
  </div>
</template>

<script setup lang="ts">
const { data = {} as Record<string, any> } = defineProps<{
  data?: Record<string, any>;
}>();

const groupStore = useGroupStore();

const groupName = computed(() => {
  const id = data.group_id;
  if (typeof id === 'number') {
    const group = groupStore.byId(id);
    if (group?.name) return group.name;
  }
  return 'A group';
});
</script>

<style></style>
