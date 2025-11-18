# Services Directory

This directory contains all microservices that make up the distributed system.

## Structure

Each service should follow this structure:

```
service-name/
├── src/
│   ├── handlers/       # Request handlers
│   ├── models/         # Data models
│   ├── services/       # Business logic
│   └── utils/          # Utility functions
├── tests/              # Service-specific tests
├── Dockerfile          # Container definition
├── package.json        # Dependencies
└── README.md           # Service documentation
```

## Creating a New Service

1. Create a new directory with the service name
2. Initialize the project (npm init, mvn init, etc.)
3. Implement the service following the structure above
4. Register the service with the service registry
5. Add health check endpoints
6. Write tests
7. Document the service API

## Service Guidelines

- Each service should have a single responsibility
- Services should be independently deployable
- Use asynchronous communication where possible
- Implement proper error handling
- Add comprehensive logging
- Include health and readiness checks
