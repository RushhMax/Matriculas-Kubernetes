import axios from 'axios';

const http = axios.create({ baseURL: '/api' });

export const getStudents  = ()         => http.get('/students');
export const getCourses   = ()         => http.get('/courses');
export const getCourse    = (id)       => http.get(`/courses/${id}`);
export const generateCpuLoad = (ms = 30) => http.get(`/load?ms=${ms}`);
export const getMyEnrollments = (sid)  => http.get(`/enrollments/student/${sid}`);
export const enroll = (student_id, course_id) =>
  http.post('/enrollments', { student_id, course_id });
