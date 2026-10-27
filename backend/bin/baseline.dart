
import 'dart:io';

import 'package:backend/src/core/database/database_pool.dart';
import 'package:postgres/postgres.dart';

Future<void> main() async {
  const initialMigration = '001_initial_schema.sql';

  const requiredTables = [
    'users',
    'posts',
    'media_assets',
    'post_media',
    'post_likes',
    'comments',
    'post_stats',
  ];

  try {
    // Verify that the existing database contains the expected tables.
    for (final table in requiredTables) {
      final result = await database.execute(
        Sql.named('''
          SELECT EXISTS (
            SELECT 1
            FROM information_schema.tables
            WHERE table_schema = 'public'
              AND table_name = @table
          )
        '''),
        parameters: {'table': table},
      );

      if (result.isEmpty || result.first[0] != true) {
        throw StateError(
          'Baseline aborted: required table "$table" '
          'does not exist in the public schema.',
        );
      }
    }

    // Create the migration tracking table only after validation succeeds.
    await database.execute('''
      CREATE TABLE IF NOT EXISTS public.schema_migrations (
        version VARCHAR(255) PRIMARY KEY,
        applied_at TIMESTAMPTZ NOT NULL DEFAULT CURRENT_TIMESTAMP
      )
    ''');

    await database.runTx((session) async {
      final existing = await session.execute(
        Sql.named('''
          SELECT version
          FROM public.schema_migrations
          WHERE version = @version
        '''),
        parameters: {'version': initialMigration},
      );

      if (existing.isNotEmpty) {
        stdout.writeln(
          'Initial migration is already recorded. Nothing to do.',
        );
        return;
      }

      await session.execute(
        Sql.named('''
          INSERT INTO public.schema_migrations (version)
          VALUES (@version)
        '''),
        parameters: {'version': initialMigration},
      );
    });

    stdout
      ..writeln('Baseline completed successfully.')
      ..writeln('Recorded migration: $initialMigration');
  } finally {
    await database.close();
  }
}
