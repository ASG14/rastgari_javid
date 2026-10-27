
import 'dart:io';

import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  final migrationsDirectory = Directory('database/migrations');

  try {
    if (!migrationsDirectory.existsSync()) {
      stderr.writeln(
        'Migration directory not found: ${migrationsDirectory.path}',
      );
      exitCode = 1;
      return;
    }

    final migrationFiles = await migrationsDirectory
        .list()
        .where((entity) => entity is File && entity.path.endsWith('.sql'))
        .cast<File>()
        .toList();

    migrationFiles.sort(
      (a, b) => a.uri.pathSegments.last.compareTo(b.uri.pathSegments.last),
    );

    await database.execute('''
      CREATE TABLE IF NOT EXISTS public.schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    for (final file in migrationFiles) {
      final version = file.uri.pathSegments.last;

      final result = await database.execute(
        Sql.named('''
          SELECT version
          FROM public.schema_migrations
          WHERE version = @version
        '''),
        parameters: {'version': version},
      );

      if (result.isNotEmpty) {
        stdout.writeln('Skipping already applied migration: $version');
        continue;
      }

      final sql = await file.readAsString();

      stdout.writeln('Applying migration: $version');

      await database.runTx((session) async {
        await session.execute(
          Sql(sql),
          queryMode: QueryMode.simple,
        );

        await session.execute(
          Sql.named('''
            INSERT INTO public.schema_migrations (version)
            VALUES (@version)
          '''),
          parameters: {'version': version},
        );
      });

      stdout.writeln('Applied migration: $version');
    }

    stdout.writeln('Database migrations completed.');
  } finally {
    await database.close();
  }
}
