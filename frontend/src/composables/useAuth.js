import { reactive } from 'vue';

const state = reactive({
  student:   JSON.parse(localStorage.getItem('student') || 'null'),
  served_by: null,
});

export function useAuth() {
  function login(student) {
    state.student = student;
    localStorage.setItem('student', JSON.stringify(student));
  }

  function logout() {
    state.student = null;
    state.served_by = null;
    localStorage.removeItem('student');
  }

  function setServedBy(pod) {
    state.served_by = pod;
  }

  return { state, login, logout, setServedBy };
}
