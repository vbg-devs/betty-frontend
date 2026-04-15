<template>
  <div>
    <strong>{{ data.who || 'Someone' }}</strong> just joined <strong>{{ data.group.name }}</strong>
  </div>
</template>

<script setup lang="ts">
const { data = {} as Record<string, any> } = defineProps<{
  data?: Record<string, any>;
}>();
</script>

<style></style>
