<script setup>
// Knopf "Zur Einkaufsliste". Ohne Liste legt er eine an, bei genau einer Liste fuegt er direkt hinzu, sonst Auswahl.
import { ref, computed, watch, onMounted, onBeforeUnmount } from 'vue';

const props = defineProps({ itemKey: String, stamp: Number });
const emit = defineEmits(['go']);
const api = window.peon;

const lists = ref([]);
const open = ref(false);
const root = ref(null);
async function load() { lists.value = await api.shopLists(props.itemKey); }
onMounted(load);
watch(() => [props.itemKey, props.stamp], load);

const inLists = computed(() => lists.value.filter((l) => l.on));

async function click() {
  if (inLists.value.length || lists.value.length > 1) { open.value = !open.value; return; }
  const id = lists.value.length ? lists.value[0].id : await api.shopNewList('');
  await api.shopAdd(id, props.itemKey);
  await load();
}
async function toggle(l) {
  if (l.on) await api.shopRemove(l.id, props.itemKey);
  else await api.shopAdd(l.id, props.itemKey);
  await load();
}
async function addNew() {
  const id = await api.shopNewList('');
  await api.shopAdd(id, props.itemKey);
  await load();
}
function outside(e) { if (open.value && root.value && !root.value.contains(e.target)) open.value = false; }
onMounted(() => document.addEventListener('mousedown', outside));
onBeforeUnmount(() => document.removeEventListener('mousedown', outside));
</script>

<template>
  <div class="shopbtn" ref="root">
    <button :class="{ primary: !inLists.length }" :aria-expanded="open" @click="click">{{ inLists.length ? `Auf der Einkaufsliste: ${inLists.map((l) => l.name).join(', ')}` : 'Zur Einkaufsliste' }}</button>
    <div class="menu" v-if="open">
      <label v-for="l in lists" :key="l.id" class="row"><input type="checkbox" :checked="l.on" @change="toggle(l)" /> {{ l.name }}</label>
      <button class="link small" @click="addNew">Neue Liste anlegen</button>
      <button class="link small" @click="open = false; emit('go', 'shopping')">Zur Einkaufsliste wechseln</button>
    </div>
  </div>
</template>

<style scoped>
.shopbtn { position: relative; }
.shopbtn > button { max-width: 340px; overflow: hidden; text-overflow: ellipsis; }
.menu { position: absolute; right: 0; top: calc(100% + 6px); z-index: 20; min-width: 220px; display: grid; gap: 8px; padding: 10px 12px; background: var(--raised); border: 1px solid var(--line); border-radius: var(--radius-m); box-shadow: 0 6px 20px rgba(0, 0, 0, 0.35); }
.row { display: flex; gap: 8px; align-items: center; white-space: nowrap; }
input { accent-color: var(--accent); }
</style>
