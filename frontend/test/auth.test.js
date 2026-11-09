import { beforeEach, expect, test, vi } from 'vitest';

beforeEach(() => {
  localStorage.clear();
  vi.resetModules();
});

test('login stores the selected student and logout removes the session', async () => {
  const { useAuth } = await import('../src/composables/useAuth');
  const auth = useAuth();
  const student = { id: 1, name: 'Student One' };
  auth.login(student);
  auth.setServedBy('backend-test');
  expect(auth.state.student).toEqual(student);
  expect(JSON.parse(localStorage.getItem('student'))).toEqual(student);
  auth.logout();
  expect(auth.state.student).toBeNull();
  expect(auth.state.served_by).toBeNull();
  expect(localStorage.getItem('student')).toBeNull();
});

test('a previously selected student is restored after loading the module', async () => {
  localStorage.setItem('student', JSON.stringify({ id: 2, name: 'Student Two' }));
  const { useAuth } = await import('../src/composables/useAuth');
  expect(useAuth().state.student.id).toBe(2);
});
