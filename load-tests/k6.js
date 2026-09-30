import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const errors = new Counter('errors');
const requestSuccess = new Rate('request_success_rate');
const apiLatency = new Trend('api_latency_ms', true);

// Docker Compose: http://localhost:3000
// Kubernetes:     http://localhost/api (o http://unsa.local/api con hosts configurado)
const BASE = (__ENV.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
const MAX_VUS = Number.parseInt(__ENV.MAX_VUS || '200', 10);
const CPU_MS = Number.parseInt(__ENV.CPU_MS || '30', 10);

export const options = {
  scenarios: {
    hpa_demo: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '20s', target: Math.max(10, Math.floor(MAX_VUS / 4)) },
        { duration: '40s', target: Math.max(20, Math.floor(MAX_VUS / 2)) },
        { duration: '60s', target: MAX_VUS },
        { duration: '20s', target: 0 },
      ],
      gracefulRampDown: '5s',
    },
  },
  thresholds: {
    http_req_failed: ['rate<0.05'],
    request_success_rate: ['rate>0.95'],
    http_req_duration: ['p(95)<3000'],
  },
};

export default function () {
  // La carga CPU controlada hace visible el escalamiento incluso en un equipo rapido.
  const load = http.get(`${BASE}/load?ms=${CPU_MS}`, { tags: { name: 'GET_load' } });
  apiLatency.add(load.timings.duration);
  const loadOk = check(load, { 'load responde 200': (r) => r.status === 200 });
  requestSuccess.add(loadOk);
  if (!loadOk) errors.add(1);

  // Trafico real de negocio durante el escalamiento.
  const courses = http.get(`${BASE}/courses`, { tags: { name: 'GET_courses' } });
  apiLatency.add(courses.timings.duration);
  const coursesOk = check(courses, { 'courses responde 200': (r) => r.status === 200 });
  requestSuccess.add(coursesOk);
  if (!coursesOk) errors.add(1);

  sleep(0.1);
}
