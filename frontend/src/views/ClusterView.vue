<template>
  <div class="page">
    <h1 class="page-title">Estado del Cluster</h1>
    <p class="subtitle">Visualización en vivo del comportamiento de Kubernetes</p>

    <!-- Stats generales -->
    <div class="stats-row">
      <div class="stat-card">
        <div class="stat-value">{{ totalRequests }}</div>
        <div class="stat-label">Requests totales</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">{{ activePods.length }}</div>
        <div class="stat-label">Pods activos vistos</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">{{ cacheHits }}</div>
        <div class="stat-label">Hits de caché (Redis)</div>
      </div>
      <div class="stat-card">
        <div class="stat-value">{{ cacheHits + dbHits > 0 ? Math.round(cacheHits / (cacheHits + dbHits) * 100) : 0 }}%</div>
        <div class="stat-label">Tasa caché</div>
      </div>
    </div>

    <!-- Controles -->
    <div class="controls">
      <button class="btn-primary" :disabled="firing" @click="fireRequests(50, 'light')">
        {{ firing ? '⏳ Disparando...' : '🚀 50 requests (balanceo)' }}
      </button>
      <button class="btn-primary" :disabled="firing" @click="fireRequests(300, 'mixed')">
        {{ firing ? '⏳ Disparando...' : '💥 300 requests mixtos (escala HPA)' }}
      </button>
      <button class="btn-primary" :disabled="firing" @click="fireRequests(1000, 'mixed')">
        {{ firing ? '⏳ Disparando...' : '🔥 1000 requests (estrés máximo)' }}
      </button>
      <button class="btn-ghost" @click="reset">Resetear</button>
    </div>
    <p v-if="firing" class="firing-hint">
      Abre K9s o ejecuta <code>kubectl get hpa -n unsa-matricula -w</code> para ver el HPA escalar en tiempo real.
    </p>

    <!-- Distribución por pod -->
    <div class="section">
      <h2 class="section-title">Distribución por pod <span class="hint">(demuestra balanceo de carga)</span></h2>
      <div v-if="activePods.length === 0" class="empty">
        Aún no hay datos — dispara requests para ver cómo Kubernetes distribuye la carga.
      </div>
      <div v-else class="pod-list">
        <div v-for="pod in podStats" :key="pod.name" class="pod-row">
          <div class="pod-name">{{ pod.name }}</div>
          <div class="bar-wrap">
            <div class="bar" :style="{ width: pod.pct + '%' }"></div>
          </div>
          <div class="pod-count">{{ pod.count }} req ({{ pod.pct }}%)</div>
        </div>
      </div>
    </div>

    <!-- Historial de requests -->
    <div class="section">
      <h2 class="section-title">Últimos requests <span class="hint">(en tiempo real)</span></h2>
      <div class="log-table-wrap">
        <table class="log-table">
          <thead>
            <tr>
              <th>#</th>
              <th>Pod</th>
              <th>Tipo</th>
              <th>Fuente</th>
              <th>Latencia</th>
              <th>Estado</th>
            </tr>
          </thead>
          <tbody>
            <tr v-for="entry in recentLog" :key="entry.n" :class="entry.ok ? '' : 'row-error'">
              <td class="mono">{{ entry.n }}</td>
              <td class="mono pod-cell">{{ entry.pod }}</td>
              <td><span class="badge" :class="entry.type === 'POST' ? 'badge-yellow' : 'badge-gray'">{{ entry.type }}</span></td>
              <td>
                <span class="badge" :class="entry.source === 'cache' ? 'badge-blue' : 'badge-gray'">
                  {{ entry.source === 'cache' ? '⚡ caché' : entry.source === 'cpu' ? '🔥 CPU' : '🗄 db' }}
                </span>
              </td>
              <td class="mono">{{ entry.ms }}ms</td>
              <td>
                <span class="badge" :class="entry.ok ? 'badge-green' : 'badge-red'">
                  {{ entry.ok ? '✓' : '✗' }}
                </span>
              </td>
            </tr>
          </tbody>
        </table>
      </div>
    </div>
  </div>
</template>

<script setup>
import { ref, computed, onMounted } from 'vue';
import { useRoute } from 'vue-router';
import { getCourses, generateCpuLoad } from '../api/index.js';
import { useAuth } from '../composables/useAuth.js';

const auth         = useAuth();
const route        = useRoute();
const log          = ref([]);
const totalRequests = ref(0);
const cacheHits    = ref(0);
const dbHits       = ref(0);
const firing       = ref(false);

const recentLog = computed(() => [...log.value].reverse().slice(0, 30));

const activePods = computed(() => {
  const pods = new Set(log.value.filter(e => e.pod !== 'error').map(e => e.pod));
  return [...pods];
});

const podStats = computed(() => {
  const counts = {};
  log.value.filter(e => e.pod !== 'error').forEach(e => {
    counts[e.pod] = (counts[e.pod] || 0) + 1;
  });
  const total = Object.values(counts).reduce((a, b) => a + b, 0) || 1;
  return Object.entries(counts)
    .map(([name, count]) => ({ name, count, pct: Math.round(count / total * 100) }))
    .sort((a, b) => b.count - a.count);
});

async function fireRequests(n, mode) {
  firing.value = true;
  const CONCURRENCY = 10;
  for (let i = 0; i < n; i += CONCURRENCY) {
    const batch = [];
    for (let j = 0; j < CONCURRENCY && i + j < n; j++) {
      // En modo mixto se combina negocio real con carga CPU controlada para el HPA.
      const useCpuLoad = mode === 'mixed' && Math.random() > 0.35;
      batch.push(useCpuLoad ? cpuLoadRequest() : courseRequest());
    }
    await Promise.allSettled(batch);
    await new Promise(r => setTimeout(r, 20));
  }
  firing.value = false;
}

async function courseRequest() {
  const t0 = performance.now();
  try {
    const res    = await getCourses();
    const ms     = Math.round(performance.now() - t0);
    const pod    = res.data.served_by || 'desconocido';
    const source = res.data.source    || 'db';
    totalRequests.value++;
    if (source === 'cache') cacheHits.value++;
    else dbHits.value++;
    log.value.push({ n: totalRequests.value, pod, source, ms, ok: true, type: 'GET' });
  } catch {
    totalRequests.value++;
    log.value.push({ n: totalRequests.value, pod: 'error', source: '-', ms: Math.round(performance.now() - t0), ok: false, type: 'GET' });
  }
}

async function cpuLoadRequest() {
  const t0 = performance.now();
  try {
    const res = await generateCpuLoad(30);
    const ms  = Math.round(performance.now() - t0);
    const pod = res.data.served_by || 'desconocido';
    totalRequests.value++;
    log.value.push({ n: totalRequests.value, pod, source: 'cpu', ms, ok: true, type: 'CPU' });
  } catch (e) {
    const ms  = Math.round(performance.now() - t0);
    const pod = e.response?.data?.served_by;
    totalRequests.value++;
    if (pod) {
      // El pod respondió con error controlado: se conserva para observar distribución.
      const ok = e.response?.status < 500;
      log.value.push({ n: totalRequests.value, pod, source: 'cpu', ms, ok, type: 'CPU' });
    } else {
      // Sin respuesta del servidor (red caída, pod terminando, etc.)
      log.value.push({ n: totalRequests.value, pod: 'error', source: '-', ms, ok: false, type: 'CPU' });
    }
  }
}

function reset() {
  log.value = [];
  totalRequests.value = 0;
  cacheHits.value = 0;
  dbHits.value = 0;
}

onMounted(() => {
  if (route.query.autofire === '1') fireRequests(50, 'light');
});
</script>

<style scoped>
.subtitle { color: var(--muted); margin-top: -.5rem; margin-bottom: 1.5rem; font-size: .9rem; }

.stats-row {
  display: grid;
  grid-template-columns: repeat(auto-fill, minmax(160px, 1fr));
  gap: 1rem;
  margin-bottom: 1.5rem;
}
.stat-card {
  background: var(--surface);
  border: 1px solid var(--border);
  border-radius: 10px;
  padding: 1rem 1.25rem;
  text-align: center;
}
.stat-value { font-size: 2rem; font-weight: 700; color: var(--primary); }
.stat-label { font-size: .75rem; color: var(--muted); margin-top: .25rem; }

.controls { display: flex; gap: .75rem; flex-wrap: wrap; margin-bottom: 2rem; }

.section { margin-bottom: 2rem; }
.section-title { font-size: 1rem; font-weight: 700; margin-bottom: 1rem; }
.hint { font-size: .75rem; color: var(--muted); font-weight: 400; }
.firing-hint { font-size: .8rem; color: var(--muted); margin-top: -.5rem; margin-bottom: 1.5rem; }
.firing-hint code { background: var(--bg); padding: .1rem .4rem; border-radius: 4px; font-family: monospace; }

.empty { color: var(--muted); font-size: .875rem; padding: 2rem; text-align: center; border: 1px dashed var(--border); border-radius: 8px; }

.pod-list { display: flex; flex-direction: column; gap: .6rem; }
.pod-row  { display: flex; align-items: center; gap: .75rem; }
.pod-name { font-family: monospace; font-size: .8rem; width: 220px; flex-shrink: 0; overflow: hidden; text-overflow: ellipsis; white-space: nowrap; }
.bar-wrap  { flex: 1; background: var(--bg); border-radius: 999px; height: 18px; overflow: hidden; }
.bar       { height: 100%; background: var(--primary); border-radius: 999px; transition: width .3s ease; min-width: 4px; }
.pod-count { font-size: .8rem; color: var(--muted); width: 110px; text-align: right; flex-shrink: 0; }

.log-table-wrap { overflow-x: auto; max-height: 320px; overflow-y: auto; border: 1px solid var(--border); border-radius: 8px; }
.log-table { width: 100%; border-collapse: collapse; font-size: .8rem; }
.log-table th { background: var(--bg); padding: .5rem .75rem; text-align: left; font-size: .75rem; color: var(--muted); position: sticky; top: 0; }
.log-table td { padding: .4rem .75rem; border-top: 1px solid var(--border); }
.pod-cell { font-family: monospace; font-size: .72rem; }
.mono { font-family: monospace; }
.row-error td { background: rgba(239,68,68,.05); }
</style>
