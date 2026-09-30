<template>
  <div class="page">
    <button class="btn-ghost" style="margin-bottom:1rem;font-size:.8rem" @click="$router.back()">
      ← Volver
    </button>

    <div v-if="loading" class="loading-state"><span class="spinner"></span> Cargando...</div>
    <div v-else-if="error" class="alert alert-error">{{ error }}</div>

    <div v-else-if="course" class="detail-layout">
      <div class="card detail-card">
        <div class="detail-top">
          <span class="badge badge-gray">{{ course.code }}</span>
          <span class="pod-info">pod: {{ servedBy }}</span>
        </div>
        <h1 class="detail-title">{{ course.name }}</h1>
        <p class="detail-teacher">{{ course.teacher }}</p>

        <div class="detail-stats">
          <div class="stat">
            <span class="stat-value">{{ course.credits }}</span>
            <span class="stat-label">Créditos</span>
          </div>
          <div class="stat">
            <span class="stat-value">{{ course.capacity }}</span>
            <span class="stat-label">Capacidad</span>
          </div>
          <div class="stat">
            <span class="stat-value" :style="{ color: course.available_slots === 0 ? 'var(--accent)' : 'var(--success)' }">
              {{ course.available_slots }}
            </span>
            <span class="stat-label">Vacantes</span>
          </div>
        </div>

        <div v-if="enrolled" class="alert alert-success" style="margin-top:1.25rem">
          ✅ ¡Matriculado exitosamente en <strong>{{ course.name }}</strong>!
        </div>
        <div v-if="enrollError" class="alert alert-error" style="margin-top:1.25rem">
          {{ enrollError }}
        </div>

        <div style="margin-top:1.5rem">
          <button
            v-if="!enrolled"
            class="btn-primary"
            style="padding:.65rem 1.6rem"
            :disabled="course.available_slots === 0 || enrollLoading"
            @click="doEnroll"
          >
            <span v-if="enrollLoading" class="spinner" style="vertical-align:middle;margin-right:.4rem"></span>
            {{ course.available_slots === 0 ? 'Sin vacantes' : 'Matricularme' }}
          </button>
        </div>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted }         from 'vue';
import { useRoute }               from 'vue-router';
import { getCourse, enroll }      from '../api/index.js';
import { useAuth }                from '../composables/useAuth.js';

const route       = useRoute();
const auth        = useAuth();
const course      = ref(null);
const loading     = ref(false);
const error       = ref('');
const servedBy    = ref('');
const enrolled    = ref(false);
const enrollError = ref('');
const enrollLoading = ref(false);

onMounted(async () => {
  loading.value = true;
  try {
    const res   = await getCourse(route.params.id);
    course.value  = res.data.data;
    servedBy.value = res.data.served_by;
    auth.setServedBy(res.data.served_by);
  } catch {
    error.value = 'No se pudo cargar el curso.';
  } finally {
    loading.value = false;
  }
});

async function doEnroll() {
  enrollLoading.value = true;
  enrollError.value   = '';
  try {
    await enroll(auth.state.student.id, course.value.id);
    enrolled.value = true;
    course.value.available_slots--;
    auth.setServedBy(servedBy.value);
  } catch (err) {
    enrollError.value = err.response?.data?.error || 'Error al matricularse.';
  } finally {
    enrollLoading.value = false;
  }
}
</script>

<style scoped>
.loading-state { display: flex; align-items: center; gap: .6rem; color: var(--muted); padding: 3rem; justify-content: center; }
.detail-layout { max-width: 560px; }
.detail-card { padding: 2rem; }
.detail-top  { display: flex; align-items: center; justify-content: space-between; margin-bottom: .75rem; }
.detail-title { font-size: 1.4rem; font-weight: 700; color: var(--primary); margin: .5rem 0 .25rem; line-height: 1.3; }
.detail-teacher { font-size: .875rem; color: var(--muted); }
.detail-stats {
  display: flex;
  gap: 1.5rem;
  margin-top: 1.5rem;
  padding-top: 1.25rem;
  border-top: 1px solid var(--border);
}
.stat { display: flex; flex-direction: column; gap: .15rem; }
.stat-value { font-size: 1.6rem; font-weight: 700; color: var(--text); }
.stat-label { font-size: .72rem; color: var(--muted); text-transform: uppercase; letter-spacing: .04em; }
</style>
