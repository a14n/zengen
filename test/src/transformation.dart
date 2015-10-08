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
import 'package:analyzer/src/string_source.dart';
import 'package:dart_style/dart_style.dart';
import 'package:source_gen/src/utils.dart';
import 'package:test/test.dart';
import 'package:zengen/generator.dart';

testTransformation(String spec, String source, String expectedContent, {skip}) {
  test(spec, () async {
    final dir = await Directory.current;
    final context = await getAnalysisContextForProjectPath(dir.path, []);
    final testSource = new StringSource(source, 'source.dart');
    context.applyChanges(new ChangeSet()..addedSource(testSource));
    final lib = context.computeLibraryElement(testSource);
    final content = await new ZengenGenerator().generate(lib);
    final formater = new DartFormatter();
    expect(formater.format(content), equals(formater.format(expectedContent)));
  }, skip: skip);
}
