import { expect, test, vi } from 'vitest';

const client = vi.hoisted(() => ({ get: vi.fn(), post: vi.fn() }));
vi.mock('axios', () => ({ default: { create: () => client } }));
import { enroll, getMyEnrollments, getCourse } from '../src/api';

test('enrollment sends student and course identifiers to the API', () => {
  enroll(12, 3);
  expect(client.post).toHaveBeenCalledWith('/enrollments', { student_id: 12, course_id: 3 });
});

test('course detail and enrollment queries use the selected identifiers', () => {
  getCourse(3);
  getMyEnrollments(12);
  expect(client.get).toHaveBeenCalledWith('/courses/3');
  expect(client.get).toHaveBeenCalledWith('/enrollments/student/12');
});
