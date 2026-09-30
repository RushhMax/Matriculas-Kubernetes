import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Rate, Trend } from 'k6/metrics';

const errors        = new Counter('errors');
const enrollSuccess = new Rate('enroll_success_rate');
const apiLatency    = new Trend('api_latency_ms');

// Ajusta BASE_URL segun el entorno:
//   docker-compose:  http://localhost:3000
//   kubernetes:      http://unsa.local  (requiere nginx-ingress + /etc/hosts)
const BASE = __ENV.BASE_URL || 'http://localhost:3000';

// Escenario en 3 fases: baja → media → alta carga
export const options = {
  scenarios: {
    load_test: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '30s', target: 50  },   // calentamiento
        { duration: '60s', target: 200 },   // carga media
        { duration: '60s', target: 500 },   // carga alta (HPA debe escalar)
        { duration: '30s', target: 0   },   // enfriamiento
      ],
    },
  },
  thresholds: {
    http_req_duration:    ['p(95)<2000'],   // 95% bajo 2 s
    http_req_failed:      ['rate<0.05'],    // menos de 5% errores
    enroll_success_rate:  ['rate>0.85'],
  },
};

// Estudiantes y cursos disponibles en el seed
const STUDENT_IDS = Array.from({ length: 100 }, (_, i) => i + 1);
const COURSE_IDS  = Array.from({ length: 30  }, (_, i) => i + 1);

function rand(arr) {
  return arr[Math.floor(Math.random() * arr.length)];
}

export default function () {
  const studentId = rand(STUDENT_IDS);
  const courseId  = rand(COURSE_IDS);

  // 1. Listar cursos (hit frecuente, puede venir del cache Redis)
  const r1 = http.get(`${BASE}/courses`, { tags: { name: 'GET_courses' } });
  apiLatency.add(r1.timings.duration);
  check(r1, { 'GET /courses 200': (r) => r.status === 200 });
  if (r1.status !== 200) errors.add(1);

  sleep(0.2);

  // 2. Ver detalle de un curso
  const r2 = http.get(`${BASE}/courses/${courseId}`, { tags: { name: 'GET_course_id' } });
  apiLatency.add(r2.timings.duration);
  check(r2, { 'GET /courses/:id 200|404': (r) => [200, 404].includes(r.status) });

  sleep(0.1);

  // 3. Intentar matricula
  const payload = JSON.stringify({ student_id: studentId, course_id: courseId });
  const params  = {
    headers: { 'Content-Type': 'application/json' },
    tags:    { name: 'POST_enrollment' },
  };
  const r3 = http.post(`${BASE}/enrollments`, payload, params);
  apiLatency.add(r3.timings.duration);

  const ok = r3.status === 201 || r3.status === 409; // 409 = ya inscrito o sin vacante
  check(r3, { 'POST /enrollments ok': () => ok });
  enrollSuccess.add(r3.status === 201 ? 1 : 0);
  if (!ok) errors.add(1);

  sleep(0.3);

  // 4. Consultar matrículas del estudiante
  const r4 = http.get(`${BASE}/enrollments/student/${studentId}`, { tags: { name: 'GET_my_enrollments' } });
  apiLatency.add(r4.timings.duration);
  check(r4, { 'GET /enrollments/student 200': (r) => r.status === 200 });

  sleep(Math.random() * 0.5);
}
