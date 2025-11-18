# Common Utilities

This directory contains shared code and utilities used across multiple services.

## Contents

### Modules

- `logger.js/py` - Centralized logging utility
- `config.js/py` - Configuration management
- `errors.js/py` - Custom error classes
- `validators.js/py` - Input validation utilities
- `http-client.js/py` - HTTP client wrapper
- `cache.js/py` - Caching utilities

### Utilities

- Authentication helpers
- Data transformation functions
- Common middleware
- Shared constants
- Helper functions

## Usage

Import common utilities in your service:

```javascript
const logger = require('../common/logger');
const config = require('../common/config');

logger.info('Service started', { port: config.get('port') });
```

## Guidelines

- Keep utilities generic and reusable
- Add unit tests for all utilities
- Document function parameters and return values
- Avoid service-specific logic
- Use consistent error handling
