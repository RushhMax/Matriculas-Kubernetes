<template>
  <div class="page">
    <div class="courses-header">
      <h1 class="page-title">Cursos disponibles</h1>
      <div class="header-meta">
        <span v-if="source" class="badge" :class="source === 'cache' ? 'badge-blue' : 'badge-gray'">
          {{ source === 'cache' ? '⚡ caché' : '🗄 base de datos' }}
        </span>
        <span v-if="servedBy" class="pod-info">pod: {{ servedBy }}</span>
        <button class="btn-ghost" style="padding:.3rem .8rem;font-size:.8rem" @click="load">Recargar</button>
      </div>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>

    <div v-if="loading" class="loading-state">
      <span class="spinner"></span> Cargando cursos...
    </div>

    <div v-else class="course-grid">
      <div
        v-for="c in courses"
        :key="c.id"
        class="course-card card"
        @click="$router.push(`/courses/${c.id}`)"
      >
        <div class="course-code badge badge-gray">{{ c.code }}</div>
        <h3 class="course-name">{{ c.name }}</h3>
        <p class="course-teacher">{{ c.teacher }}</p>
        <div class="course-footer">
          <span class="badge" :class="slotsClass(c.available_slots)">
            {{ c.available_slots }} / {{ c.capacity }} vacantes
          </span>
          <span class="credits-pill">{{ c.credits }} cr.</span>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { getCourses }     from '../api/index.js';
import { useAuth }        from '../composables/useAuth.js';

const auth     = useAuth();
const courses  = ref([]);
const loading  = ref(false);
const error    = ref('');
const source   = ref('');
const servedBy = ref('');

async function load() {
  loading.value = true;
  error.value   = '';
  try {
    const res     = await getCourses();
    courses.value = res.data.data;
    source.value  = res.data.source;
    servedBy.value = res.data.served_by;
    auth.setServedBy(res.data.served_by);
  } catch {
    error.value = 'Error al cargar los cursos.';
  } finally {
    loading.value = false;
  }
}

function slotsClass(slots) {
  if (slots === 0) return 'badge-red';
  if (slots <= 5)  return 'badge-yellow';
  return 'badge-green';
}

onMounted(load);
</script>

<style scoped>
.courses-header {
  display: flex;
  align-items: center;
  gap: 1rem;
  flex-wrap: wrap;
  margin-bottom: 1.25rem;
}
.courses-header .page-title { margin-bottom: 0; }
.header-meta { display: flex; align-items: center; gap: .6rem; margin-left: auto; }

.loading-state {
  display: flex;
  align-items: center;
  gap: .6rem;
  color: var(--muted);
  padding: 3rem;
  justify-content: center;
}

.course-grid {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(260px, 1fr));
  gap: 1rem;
}
.course-card {
  cursor: pointer;
  transition: transform .15s, box-shadow .15s;
  display: flex;
  flex-direction: column;
  gap: .5rem;
}
.course-card:hover {
  transform: translateY(-2px);
  box-shadow: 0 4px 16px rgba(0,0,0,.12);
}
.course-code { align-self: flex-start; font-size: .7rem; }
.course-name { font-size: .95rem; font-weight: 700; color: var(--primary); line-height: 1.3; }
.course-teacher { font-size: .8rem; color: var(--muted); }
.course-footer { display: flex; align-items: center; justify-content: space-between; margin-top: .25rem; }
.credits-pill {
  font-size: .72rem;
  color: var(--muted);
  background: var(--bg);
  padding: .15rem .5rem;
  border-radius: 999px;
  border: 1px solid var(--border);
}
</style>
