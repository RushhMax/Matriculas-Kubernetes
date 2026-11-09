module.exports = {
  ...require('./jest.config.cjs'),
  testMatch: ['<rootDir>/test/integration/**/*.test.js'],
  testTimeout: 15000,
  reporters: ['default', ['jest-junit', { outputDirectory: 'reports', outputName: 'integration.xml' }]],
};
