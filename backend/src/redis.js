const Redis = require('ioredis');

const redis = new Redis({
  host:     process.env.REDIS_HOST || 'localhost',
  port:     parseInt(process.env.REDIS_PORT || '6379'),
  lazyConnect: true,
  retryStrategy: (times) => Math.min(times * 50, 2000),
});

redis.on('error', (err) => {
  console.warn('Redis warning:', err.message);
});

module.exports = redis;
