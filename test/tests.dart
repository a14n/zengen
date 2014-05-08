import 'dart:io';

import 'package:analyzer/src/services/formatter_impl.dart';
import 'package:zengen/transformer.dart';
import 'package:path/path.dart' as p;
import 'package:unittest/unittest.dart';

main() {
  new Directory('origin').listSync()
      ..sort((f1, f2) => f1.path.compareTo(f2.path))
      ..where((e) => FileSystemEntity.isFileSync(e.path)).forEach((f) {
        test(f.path, () {
          final name = p.basename(f.path);
          final origin = f.readAsStringSync();
          final transformed = traverseModifiers(origin);
          final expected = new File(p.join('expected', name)).readAsStringSync(
              );
          expect(format(transformed), equals(format(expected)));
        });
      });
}

format(String code) => new CodeFormatter().format(CodeKind.COMPILATION_UNIT,
    code).source;
