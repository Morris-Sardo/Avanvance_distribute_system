# Tests Directory

This directory contains all test suites for the distributed system.

## Structure

```
tests/
├── unit/           # Unit tests
├── integration/    # Integration tests
├── e2e/            # End-to-end tests
├── load/           # Load and performance tests
├── fixtures/       # Test data and fixtures
└── helpers/        # Test utilities
```

## Running Tests

```bash
# Run all tests
npm test

# Run unit tests only
npm run test:unit

# Run integration tests
npm run test:integration

# Run with coverage
npm run test:coverage

# Run specific test file
npm test tests/unit/service-registry.test.js
```

## Writing Tests

### Unit Tests
- Test individual functions and classes
- Mock external dependencies
- Fast execution
- High coverage

### Integration Tests
- Test interaction between components
- Use test databases/services
- Verify contracts between services

### End-to-End Tests
- Test complete user workflows
- Use production-like environment
- Validate system behavior

## Best Practices

1. **Arrange-Act-Assert** pattern
2. **Descriptive test names**
3. **One assertion per test** (when possible)
4. **Clean up after tests**
5. **Use test fixtures** for consistent data
6. **Mock external services**
7. **Test edge cases** and error conditions

## Test Coverage Goals

- Unit tests: >80%
- Integration tests: Critical paths
- E2E tests: Major user flows
