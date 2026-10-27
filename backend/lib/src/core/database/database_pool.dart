import 'dart:io';

import 'package:postgres/postgres.dart';

/// Manages the shared PostgreSQL connection pool for the backend.
final Pool<dynamic> database = Pool.withEndpoints(
  [
    Endpoint(
      host: _requiredEnv('RJ_DB_HOST'),
      port: int.parse(_requiredEnv('RJ_DB_PORT')),
      database: _requiredEnv('RJ_DB_NAME'),
      username: _requiredEnv('RJ_DB_USER'),
      password: _requiredEnv('RJ_DB_PASSWORD'),
    ),
  ],
  settings: const PoolSettings(
    maxConnectionCount: 5,
    sslMode: SslMode.disable,
  ),
);

String _requiredEnv(String name) {
  final value = Platform.environment[name];

  if (value == null || value.isEmpty) {
    throw StateError(
      'Missing required environment variable: $name',
    );
  }

  return value;
}
