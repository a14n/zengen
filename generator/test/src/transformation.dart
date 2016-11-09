// Copyright (c) 2014, Alexandre Ardhuin
//
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
// http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:analyzer/src/generated/engine.dart';
import 'package:analyzer/src/generated/java_io.dart';
import 'package:analyzer/src/generated/source_io.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/src/utils.dart';
import 'package:test/test.dart';
import 'package:zengen_generator/zengen_generator.dart';

testTransformation(String spec, String source, String expectedContent, {skip}) {
  test(spec, () async {
    final dir = await Directory.current;
    final context = await getAnalysisContextForProjectPath(dir.path, []);
    final libSource =
        new FileBasedSource(new JavaFile('${dir.path}/source.dart'));
    final genSource =
        new FileBasedSource(new JavaFile('${dir.path}/source.g.dart'));
    context.applyChanges(
        new ChangeSet()..addedSource(libSource)..addedSource(genSource));
    context.applyChanges(new ChangeSet()
      ..changedContent(
          libSource,
          '''
library source;
import 'package:zengen/zengen.dart';
part 'source.g.dart';
''' +
              source)
      ..changedContent(genSource, ''));
    final lib = context.computeLibraryElement(libSource);
    final content = await new ZengenGenerator().generate(lib, null);
    final formatter = new DartFormatter();
    expect(
        formatter.format(content), equals(formatter.format(expectedContent)));
  }, skip: skip);
}
