<template>
  <div class="login-page">
    <div class="login-box card">
      <div class="login-header">
        <div class="unsa-logo">UNSA</div>
        <h1>Sistema de Matrícula</h1>
        <p>Universidad Nacional de San Agustín de Arequipa</p>
      </div>

      <div v-if="error" class="alert alert-error">{{ error }}</div>

      <div class="form-group">
        <label>Selecciona tu cuenta</label>
        <select v-model="selectedId" :disabled="loading">
          <option value="">— elige un estudiante —</option>
          <option v-for="s in students" :key="s.id" :value="s.id">
            {{ s.code }} · {{ s.name }}
          </option>
        </select>
      </div>

      <button class="btn-primary" style="width:100%;padding:.7rem" :disabled="!selectedId || loading" @click="doLogin">
        <span v-if="loading" class="spinner" style="vertical-align:middle;margin-right:.4rem"></span>
        Iniciar sesión
      </button>

      <p class="login-note">Escenario hipotético — Cloud Computing S10</p>
    </div>
  </div>
</template>

<script setup>
import { ref, onMounted } from 'vue';
import { useRouter }      from 'vue-router';
import { getStudents }    from '../api/index.js';
import { useAuth }        from '../composables/useAuth.js';

const router     = useRouter();
const auth       = useAuth();
const students   = ref([]);
const selectedId = ref('');
const loading    = ref(false);
const error      = ref('');

onMounted(async () => {
  loading.value = true;
  try {
    const res = await getStudents();
    students.value = res.data.data;
  } catch {
    error.value = 'No se pudo conectar al servidor. Verifique que el backend esté corriendo.';
  } finally {
    loading.value = false;
  }
});

function doLogin() {
  const student = students.value.find(s => s.id === selectedId.value);
  if (!student) return;
  auth.login(student);
  router.push('/courses');
}
</script>

<style scoped>
.login-page {
  min-height: 100vh;
  display: flex;
  align-items: center;
  justify-content: center;
  background: linear-gradient(135deg, #1a3a5c 0%, #2c5282 100%);
}
.login-box {
  width: 100%;
  max-width: 420px;
  padding: 2.5rem 2rem;
}
.login-header { text-align: center; margin-bottom: 2rem; }
.unsa-logo {
  display: inline-block;
  background: var(--accent);
  color: #fff;
  font-size: 1.6rem;
  font-weight: 800;
  padding: .5rem 1.2rem;
  border-radius: var(--radius);
  letter-spacing: .08em;
  margin-bottom: .75rem;
}
.login-header h1 { font-size: 1.2rem; font-weight: 700; color: var(--primary); }
.login-header p  { font-size: .8rem; color: var(--muted); margin-top: .2rem; }
.form-group { margin-bottom: 1.25rem; }
.form-group label { display: block; font-size: .8rem; font-weight: 600; margin-bottom: .4rem; color: var(--muted); }
select {
  width: 100%;
  padding: .55rem .75rem;
  border: 1.5px solid var(--border);
  border-radius: var(--radius);
  font-size: .875rem;
  font-family: inherit;
  background: #fff;
  color: var(--text);
  appearance: none;
  cursor: pointer;
}
select:focus { outline: none; border-color: var(--primary); }
.login-note { text-align: center; font-size: .72rem; color: var(--muted); margin-top: 1rem; }
</style>
