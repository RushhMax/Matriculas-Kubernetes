module.exports = {
  testEnvironment: 'node',
  testMatch: ['<rootDir>/test/unit/**/*.test.js'],
  clearMocks: true,
  collectCoverageFrom: ['src/**/*.js', '!src/index.js'],
  coverageReporters: ['text', 'lcov', 'json-summary'],
  reporters: ['default', ['jest-junit', { outputDirectory: 'reports', outputName: 'unit.xml' }]],
};
