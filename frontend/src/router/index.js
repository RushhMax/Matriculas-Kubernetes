import { createRouter, createWebHistory } from 'vue-router';
import LoginView        from '../views/LoginView.vue';
import CoursesView      from '../views/CoursesView.vue';
import CourseDetailView from '../views/CourseDetailView.vue';
import MyEnrollView     from '../views/MyEnrollmentsView.vue';
import ClusterView      from '../views/ClusterView.vue';

const routes = [
  { path: '/',            component: LoginView },
  { path: '/courses',     component: CoursesView,      meta: { requiresAuth: true } },
  { path: '/courses/:id', component: CourseDetailView, meta: { requiresAuth: true } },
  { path: '/my',          component: MyEnrollView,      meta: { requiresAuth: true } },
  { path: '/cluster',     component: ClusterView,       meta: { requiresAuth: true } },
];

const router = createRouter({
  history: createWebHistory(),
  routes,
});

router.beforeEach((to, _from, next) => {
  const student = JSON.parse(localStorage.getItem('student') || 'null');
  if (to.meta.requiresAuth && !student) return next('/');
  if (to.path === '/' && student) return next('/courses');
  next();
});

export default router;
