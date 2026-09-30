<template>
  <div>
    <nav v-if="auth.state.student" class="navbar">
      <div class="nav-inner">
        <span class="nav-brand">🎓 UNSA Matrícula</span>
        <div class="nav-links">
          <router-link to="/courses">Cursos</router-link>
          <router-link to="/my">Mis Matrículas</router-link>
          <router-link to="/cluster">Cluster</router-link>
        </div>
        <div class="nav-right">
          <span v-if="auth.state.served_by" class="pod-info">
            pod: {{ auth.state.served_by }}
          </span>
          <span class="nav-student">{{ auth.state.student.name }}</span>
          <button class="btn-ghost" style="padding:.3rem .8rem" @click="logout">Salir</button>
        </div>
      </div>
    </nav>
    <router-view />
  </div>
</template>

<script setup>
import { useRouter } from 'vue-router';
import { useAuth }   from './composables/useAuth.js';

const auth   = useAuth();
const router = useRouter();

function logout() {
  auth.logout();
  router.push('/');
}
</script>

<style scoped>
.navbar {
  background: var(--primary);
  color: #fff;
  position: sticky;
  top: 0;
  z-index: 100;
  box-shadow: 0 2px 8px rgba(0,0,0,.2);
}
.nav-inner {
  max-width: 1100px;
  margin: 0 auto;
  padding: .75rem 1rem;
  display: flex;
  align-items: center;
  gap: 1.5rem;
}
.nav-brand { font-weight: 700; font-size: 1rem; white-space: nowrap; }
.nav-links  { display: flex; gap: 1rem; }
.nav-links a { color: rgba(255,255,255,.85); font-size: .875rem; font-weight: 500; }
.nav-links a.router-link-active { color: #fff; text-decoration: underline; }
.nav-right  { margin-left: auto; display: flex; align-items: center; gap: .75rem; }
.nav-student{ font-size: .8rem; opacity: .85; }
.pod-info   { font-size: .7rem; opacity: .7; font-family: monospace; }
</style>
