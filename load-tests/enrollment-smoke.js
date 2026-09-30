import http, { expectedStatuses } from 'k6/http';
import { check } from 'k6';

const BASE = (__ENV.BASE_URL || 'http://localhost:3000').replace(/\/$/, '');
http.setResponseCallback(expectedStatuses(201, 409));

export const options = {
  vus: 1,
  iterations: 1,
  thresholds: { checks: ['rate==1'] },
};

export default function () {
  const payload = JSON.stringify({ student_id: 1, course_id: 1 });
  const response = http.post(`${BASE}/enrollments`, payload, {
    headers: { 'Content-Type': 'application/json' },
  });
  check(response, {
    'matricula creada o ya existente': (r) => r.status === 201 || r.status === 409,
    'backend identifica el pod': (r) => Boolean(r.json('served_by')),
  });
}
