<template>
  <div class="page">
    <div class="courses-header">
      <h1 class="page-title">Mis matrículas</h1>
      <span v-if="servedBy" class="pod-info" style="margin-left:auto">pod: {{ servedBy }}</span>
    </div>

    <div v-if="error" class="alert alert-error">{{ error }}</div>
    <div v-if="loading" class="loading-state"><span class="spinner"></span> Cargando...</div>

    <div v-else-if="enrollments.length === 0 && !loading" class="empty-state card">
      <p>Aún no tienes matrículas registradas.</p>
      <router-link to="/courses" class="btn-primary" style="display:inline-block;margin-top:.75rem;padding:.5rem 1rem">
        Ver cursos disponibles
      </router-link>
    </div>

    <div v-else class="card" style="overflow:hidden">
      <table>
        <thead>
          <tr>
            <th>Código</th>
            <th>Curso</th>
            <th>Docente</th>
            <th>Créditos</th>
            <th>Fecha matrícula</th>
          </tr>
        </thead>
        <tbody>
          <tr v-for="e in enrollments" :key="e.id">
            <td><span class="badge badge-gray">{{ e.code }}</span></td>
            <td style="font-weight:600">{{ e.course_name }}</td>
            <td style="color:var(--muted)">{{ e.teacher }}</td>
            <td>{{ e.credits }}</td>
            <td style="color:var(--muted);font-size:.8rem">{{ formatDate(e.enrolled_at) }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <p v-if="enrollments.length" class="summary-text">
      Total: <strong>{{ enrollments.length }}</strong> curso(s) ·
      <strong>{{ totalCredits }}</strong> crédito(s)
    </p>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { getMyEnrollments }         from '../api/index.js';
import { useAuth }                  from '../composables/useAuth.js';

const auth        = useAuth();
const enrollments = ref([]);
const loading     = ref(false);
const error       = ref('');
const servedBy    = ref('');

const totalCredits = computed(() => enrollments.value.reduce((s, e) => s + e.credits, 0));

function formatDate(iso) {
  return new Date(iso).toLocaleString('es-PE', {
    day: '2-digit', month: '2-digit', year: 'numeric',
    hour: '2-digit', minute: '2-digit',
  });
}

onMounted(async () => {
  loading.value = true;
  try {
    const res = await getMyEnrollments(auth.state.student.id);
    enrollments.value = res.data.data;
    servedBy.value    = res.data.served_by;
    auth.setServedBy(res.data.served_by);
  } catch {
    error.value = 'Error al cargar tus matrículas.';
  } finally {
    loading.value = false;
  }
});
</script>

<style scoped>
.courses-header { display: flex; align-items: center; gap: 1rem; margin-bottom: 1.25rem; }
.courses-header .page-title { margin-bottom: 0; }
.loading-state { display: flex; align-items: center; gap: .6rem; color: var(--muted); padding: 3rem; justify-content: center; }
.empty-state { text-align: center; padding: 2.5rem; color: var(--muted); }
.summary-text { margin-top: .75rem; font-size: .85rem; color: var(--muted); }
</style>
