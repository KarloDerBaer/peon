// Favoriten: einmal geladen, alle Ansichten sehen denselben Stand
import { ref } from 'vue';

export const favorites = ref(new Set());

export async function loadFavorites() {
  favorites.value = new Set(await window.peon.favorites());
}

export async function toggleFavorite(key) {
  const on = !favorites.value.has(key);
  favorites.value = new Set(await window.peon.setFavorite(key, on));
}
